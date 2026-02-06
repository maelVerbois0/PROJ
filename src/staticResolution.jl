
"""
    solve_static_problem_direct(data::ProblemData)

Solves the static partitioning problem
"""
function solve_static_problem_mip(data::ProblemData; time_limit = 300., env = Gurobi.Env())
    params = Dict(
        # 1. Symmetry Breaking
        "Symmetry"    => 2,
        "PreSparsify" => 1,

        # 4. Cuts
        "CliqueCuts"  => 2,
        "Presolve"    => 2,

        # 5. Tolerance & Time
        "MIPGap"      => 0.01,
        "TimeLimit"   => time_limit
    )

    model = direct_model(Gurobi.Optimizer(env))
    set_silent(model)

    for (k, v) in params
        set_optimizer_attribute(model, k, v)
    end
   
    n = data.n
    K = data.K


    # --- Variables ---
    # x[i, k] = 1 if vertex i is in partition k
    @variable(model, x[1:data.n, 1:data.K], Bin)
    

    # --- Constraints ---

    # 1. Assignment (Eq 2): Each vertex i assigned to exactly one partition k
    # [cite_start]"sum_{k=1}^K x_{ik} = 1" [cite: 125]
    for i in 1:data.n
        @constraint(model, sum(x[i, k] for k in 1:data.K) == 1)
    end

    # 2. Capacity (Eq 3): Sum of weights in partition k <= B
    # [cite_start]"sum_{i in V} w_i x_{ik} <= B" [cite: 125]
    for k in 1:data.K
        @constraint(model, sum(data.w_nominal[i] * x[i, k] for i in 1:data.n) <= data.B)
    end


    @objective(model, Min, 1/2 * 
        sum(data.distances[i, j] * x[i, k] * x[j, k] 
            for i in 1:data.n, j in 1:data.n, k in 1:data.K)
    )

    # --- Solve ---
    optimize!(model)

    # --- Result Extraction ---
    status = termination_status(model)
    
    if status == MOI.OPTIMAL
        obj_val = objective_value(model)
        
        # Build a simple dictionary for the partition map
        # partition_map[i] = k
        partition_map = zeros(Int,n)
        for i in 1:n
            for k in 1:K
                if value(x[i, k]) > 0.5
                    partition_map[i] = k
                end
            end
        end

        return ResultatAlgorithme(
                "OPTIMAL", 
                objective_value(model),
                objective_bound(model),
                0.,
                solve_time(model),
                partition_map
                )
    else
        if result_count(model) >=1
            obj_val = objective_value(model)
        
            # Build a simple dictionary for the partition map
            # partition_map[i] = k
            partition_map = zeros(Int,n)
            for i in 1:n
                for k in 1:K
                    if value(x[i, k]) > 1 - 1e-2
                        partition_map[i] = k
                    end
                end
            end
            return ResultatAlgorithme(
                "FEASIBLE", 
                objective_value(model),
                objective_bound(model),
                (objective_value(model) - objective_bound(model))/ objective_value(model),
                solve_time(model),
                partition_map
                )
        end


        return ResultatAlgorithme(
                "NOTFOUND", 
                Inf,
                -Inf,
                NaN64,
                time_limit,
                []
                )
    end
end



