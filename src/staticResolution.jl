using JuMP
using SCIP


"""
    solve_static_problem_direct(data::ProblemData)

Solves the static partitioning problem
"""
function solve_static_problem_direct(data::ProblemData)
    println("Version 1")
    model = Model(SCIP.Optimizer)
    
    n = data.n
    K = data.K

    # --- Variables ---
    # x[i, k] = 1 if vertex i is in partition k
    @variable(model, x[1:n, 1:K], Bin)
    
    # y[i, j] = 1 if edge {i,j} is strictly inside a partition
    # We only create variables where j > i to avoid duplicates (undirected graph)
    @variable(model, y[i=1:n, j=i+1:n], Bin)

    # --- Objective ---
    # [cite_start]Minimiser sum l_{ij} * y_{ij} [cite: 124]
    # We iterate i from 1 to n, and j from i+1 to n
    @objective(model, Min, sum(data.distances[i, j] * y[i, j] for i in 1:n for j in i+1:n))

    # --- Constraints ---

    # 1. Assignment (Eq 2): Each vertex i assigned to exactly one partition k
    # [cite_start]"sum_{k=1}^K x_{ik} = 1" [cite: 125]
    for i in 1:n
        @constraint(model, sum(x[i, k] for k in 1:K) == 1)
    end

    # 2. Capacity (Eq 3): Sum of weights in partition k <= B
    # [cite_start]"sum_{i in V} w_i x_{ik} <= B" [cite: 125]
    for k in 1:K
        @constraint(model, sum(data.w_nominal[i] * x[i, k] for i in 1:n) <= data.B)
    end

    # 3. Edge Linking (Eq 4): y_{ij} >= x_{ik} + x_{jk} - 1
    # [cite_start]"y_{ij} >= x_{ik} + x_{jk} - 1" [cite: 125]
    for i in 1:n
        for j in i+1:n
            for k in 1:K
                # We can access y[i,j] directly now
                @constraint(model, y[i, j] >= x[i, k] + x[j, k] - 1)
            end
        end
    end

    #Basic symmetry breaking
    for i in 1:data.n
        for k in (i+1):data.K
             fix(x[i, k], 0; force=true)
        end
    end

    #Force Vertex 1 to Partition 1
    fix(x[1, 1], 1; force=true)

    # --- Solve ---
    optimize!(model)

    # --- Result Extraction ---
    status = termination_status(model)
    
    if status == MOI.OPTIMAL
        obj_val = objective_value(model)
        
        # Build a simple dictionary for the partition map
        # partition_map[i] = k
        partition_map = Dict{Int, Int}()
        for i in 1:n
            for k in 1:K
                if value(x[i, k]) > 0.5
                    partition_map[i] = k
                end
            end
        end

        return status, obj_val, partition_map
    else
        return status, Inf, Dict()
    end
end

using JuMP, SCIP

"""
    solve_static_warm_started(data::ProblemData)

1. Runs the geometric heuristic to find a good initial partition.
2. Initializes the SCIP exact model.
3. 'Warm Starts' SCIP by feeding the heuristic solution.
4. Solves the exact model to prove optimality.
"""
function solve_static_warm_started(data::ProblemData)
    # --- Step 1: Run Heuristic ---
    println("Running Heuristic...")
    h_status, h_cost, h_partition = solve_geometric_heuristic(data)
    
    if h_status != "FEASIBLE"
        println("Heuristic failed to find a feasible solution. Starting cold.")
        h_partition = Dict{Int, Int}() # Empty dict
    else
        println("Heuristic found solution with cost: $h_cost")
    end

    # --- Step 2: Build Exact Model ---
    # (Copying the model setup from previous steps)
    model = Model(SCIP.Optimizer)
    # Optional: Enable output to see SCIP processing the primal solution
    # set_attribute(model, "display/verblevel", 4) 

    n = data.n
    K = data.K

    @variable(model, x[1:n, 1:K], Bin)
    @variable(model, y[i=1:n, j=i+1:n], Bin)

    @objective(model, Min, sum(data.distances[i, j] * y[i, j] for i in 1:n for j in i+1:n))

    # Standard Constraints (Assignment, Capacity, Linking)
    for i in 1:n
        @constraint(model, sum(x[i, k] for k in 1:K) == 1)
    end
    for k in 1:K
        @constraint(model, sum(data.w_nominal[i] * x[i, k] for i in 1:n) <= data.B)
    end
    for i in 1:n, j in i+1:n, k in 1:K
        @constraint(model, y[i, j] >= x[i, k] + x[j, k] - 1)
    end
    
    # --- Step 3: INJECT WARM START ---
    if !isempty(h_partition)
        println("Injecting heuristic solution into SCIP...")
        
        # 3a. Set starting values for X (Node Assignments)
        for i in 1:n
            assigned_k = h_partition[i]
            for k in 1:K
                # If heuristic put node i in k, set to 1.0, else 0.0
                set_start_value(x[i, k], (k == assigned_k) ? 1.0 : 0.0)
            end
        end

        # 3b. Set starting values for Y (Edge connections)
        # SCIP checks feasibility strictly, so we must help it by setting Y too.
        for i in 1:n
            for j in (i+1):n
                # Are they in the same group in the heuristic?
                is_connected = (h_partition[i] == h_partition[j])
                set_start_value(y[i, j], is_connected ? 1.0 : 0.0)
            end
        end
    end

    # --- Step 4: Solve ---
    println("Starting Exact Solver...")
    optimize!(model)

    # Return results
    status = termination_status(model)
    obj_val = has_values(model) ? objective_value(model) : Inf
    
    final_partition = Dict{Int, Int}()
    if has_values(model)
        for i in 1:n, k in 1:K
            if value(x[i, k]) > 0.5
                final_partition[i] = k
            end
        end
    end

    return status, obj_val, final_partition
end