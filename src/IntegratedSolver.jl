module IntegratedSolver

using JuMP
using SCIP
using LinearAlgebra
using Statistics
using Random

# Ensure we can use the data structure from your previous step
# (Assumes RobustGraphData is loaded in the main environment)
import ..RobustGraphData: ProblemData 

export solve_integrated_robust

# ==================================================================================
# 1. HELPER: GEOMETRIC HEURISTIC (Cluster-then-Repair)
# ==================================================================================
function solve_geometric_heuristic(data::ProblemData; max_iter=100)
    # --- Phase 1: K-Means Clustering ---
    Random.seed!(42)
    centroids = data.coordinates[randperm(data.n)[1:data.K], :]
    assignment = zeros(Int, data.n)
    
    for iter in 1:max_iter
        changes = 0
        for i in 1:data.n
            val, idx = findmin([norm(data.coordinates[i,:] - centroids[k,:]) for k in 1:data.K])
            if assignment[i] != idx
                assignment[i] = idx
                changes += 1
            end
        end
        if changes == 0 break end
        
        # Update centroids
        for k in 1:data.K
            idxs = findall(x->x==k, assignment)
            if !isempty(idxs)
                centroids[k,:] = mean(data.coordinates[idxs,:], dims=1)
            end
        end
    end

    # --- Phase 2: Capacity Repair (Greedy) ---
    partition_weights = [sum(data.w_nominal[i] for i in 1:data.n if assignment[i]==k) for k in 1:data.K]
    
    for iter in 1:(max_iter*5)
        overloaded = findall(w -> w > data.B + 1e-5, partition_weights)
        if isempty(overloaded) break end
        
        src_k = overloaded[argmax(partition_weights[overloaded])] # Pick worst violation
        
        best_node, best_target, best_delta = -1, -1, Inf
        
        # Find best move: minimize cost increase (or maximize decrease)
        for i in findall(x->x==src_k, assignment)
            w_i = data.w_nominal[i]
            for tgt_k in 1:data.K
                if tgt_k != src_k && partition_weights[tgt_k] + w_i <= data.B
                    # Delta = (Dist to New Neighbors) - (Dist to Old Neighbors)
                    delta = 0.0
                    for j in 1:data.n
                        if i == j continue end
                        if assignment[j] == tgt_k; delta += data.distances[i,j]; end
                        if assignment[j] == src_k; delta -= data.distances[i,j]; end
                    end
                    
                    if delta < best_delta
                        best_delta, best_node, best_target = delta, i, tgt_k
                    end
                end
            end
        end
        
        if best_node != -1
            assignment[best_node] = best_target
            partition_weights[src_k] -= data.w_nominal[best_node]
            partition_weights[best_target] += data.w_nominal[best_node]
        else
            break # Stuck
        end
    end

    # Return as Dictionary
    return Dict(i => assignment[i] for i in 1:data.n)
end

# ==================================================================================
# 2. HELPER: CANONICALIZATION (Aligns heuristic with Symmetry Breaking)
# ==================================================================================
function canonicalize_partition(raw_map::Dict{Int,Int}, n::Int)
    old_to_new = Dict{Int, Int}()
    next_label = 1
    
    # "First-Fit" relabeling: The first partition encountered when scanning 1..n gets label 1
    for i in 1:n
        old_label = raw_map[i]
        if !haskey(old_to_new, old_label)
            old_to_new[old_label] = next_label
            next_label += 1
        end
    end
    
    return Dict(i => get(old_to_new, raw_map[i], 1) for i in 1:n)
end

# ==================================================================================
# 3. MAIN SOLVER: INTEGRATED BRANCH-AND-CUT
# ==================================================================================
function solve_integrated_robust(data::ProblemData)
    println("\n=== Starting Integrated Solve (Heuristic + Symmetry + Cuts) ===")
    
    # --- Step A: Run Heuristic & Canonicalize ---
    raw_heuristic = solve_geometric_heuristic(data)
    heuristic_sol = canonicalize_partition(raw_heuristic, data.n)
    
    # Calculate heuristic cost for reporting
    h_cost = 0.0
    for i in 1:data.n, j in (i+1):data.n
        if heuristic_sol[i] == heuristic_sol[j]
            h_cost += data.distances[i, j]
        end
    end
    println("  > Heuristic found initial solution. Cost: $(round(h_cost, digits=2))")

    # --- Step B: Initialize Model ---
    model = Model(SCIP.Optimizer)
    set_attribute(model, "display/verblevel", 3) # Show SCIP logs
    
    # Use direct indexing for edges (i < j)
    @variable(model, x[1:data.n, 1:data.K], Bin)
    @variable(model, y[i=1:data.n, j=i+1:data.n], Bin)

    @objective(model, Min, sum(data.distances[i, j] * y[i, j] for i in 1:data.n for j in i+1:data.n))

    # --- Step C: Base Constraints ---
    # 1. Assignment
    for i in 1:data.n
        @constraint(model, sum(x[i, k] for k in 1:data.K) == 1)
    end
    
    # 2. Capacity
    for k in 1:data.K
        @constraint(model, sum(data.w_nominal[i] * x[i, k] for i in 1:data.n) <= data.B)
    end
    
    # 3. Linking
    for i in 1:data.n, j in (i+1):data.n
        for k in 1:data.K
            @constraint(model, y[i, j] >= x[i, k] + x[j, k] - 1)
        end
    end

    # --- Step D: Symmetry Breaking ---
    # Force Node 1 -> Partition 1
    fix(x[1, 1], 1; force=true)
    
    # Simple Symmetry: Node i cannot go to partition k > i
    # (Matches our "First-Fit" canonicalization)
    for i in 1:min(data.n, data.K)
        for k in (i+1):data.K
            fix(x[i, k], 0; force=true)
        end
    end

    # --- Step E: Warm Start (Inject Heuristic) ---
    for i in 1:data.n
        assigned_k = heuristic_sol[i]
        # Set x start values
        for k in 1:data.K
            set_start_value(x[i, k], (k == assigned_k) ? 1.0 : 0.0)
        end
        # Set y start values (Essential for SCIP feasibility check!)
        for j in (i+1):data.n
            is_same = (heuristic_sol[i] == heuristic_sol[j])
            set_start_value(y[i, j], is_same ? 1.0 : 0.0)
        end
    end

    # --- Step F: User Cut Callback (Triangle Inequalities) ---
    function triangle_callback(cb_data)
        # 1. Retrieve current relaxation values
        # We assume full symmetric matrix for easier indexing
        y_val = zeros(data.n, data.n)
        for i in 1:data.n, j in (i+1):data.n
            val = callback_value(cb_data, y[i, j])
            y_val[i, j] = val
            y_val[j, i] = val
        end
        
        cuts_added = 0
        limit = 50 # Performance safeguard
        
        # 2. Search for violations
        # We iterate over triples (i, j, k)
        for i in 1:data.n
            for j in (i+1):data.n
                for k in (j+1):data.n
                    # Check 3 triangle variations
                    # Tolerance 1e-5 handles floating point noise
                    
                    # Cut 1: y_ij + y_jk - y_ik <= 1
                    if y_val[i, j] + y_val[j, k] - y_val[i, k] > 1.0 + 1e-5
                        con = @build_constraint(y[i, j] + y[j, k] - y[i, k] <= 1)
                        MOI.submit(model, MOI.UserCut(cb_data), con)
                        cuts_added += 1
                    # Cut 2: y_ij + y_ik - y_jk <= 1
                    elseif y_val[i, j] + y_val[i, k] - y_val[j, k] > 1.0 + 1e-5
                        con = @build_constraint(y[i, j] + y[i, k] - y[j, k] <= 1)
                        MOI.submit(model, MOI.UserCut(cb_data), con)
                        cuts_added += 1
                    # Cut 3: y_jk + y_ik - y_ij <= 1
                    elseif y_val[j, k] + y_val[i, k] - y_val[i, j] > 1.0 + 1e-5
                        con = @build_constraint(y[j, k] + y[i, k] - y[i, j] <= 1)
                        MOI.submit(model, MOI.UserCut(cb_data), con)
                        cuts_added += 1
                    end
                    
                    if cuts_added >= limit return end
                end
            end
        end
    end
    
    # Register callback
    MOI.set(model, MOI.UserCutCallback(), triangle_callback)

    # --- Step G: Solve ---
    optimize!(model)

    # --- Step H: Return Results ---
    status = termination_status(model)
    final_cost = has_values(model) ? objective_value(model) : Inf
    
    final_partition = Dict{Int, Int}()
    if has_values(model)
        for i in 1:data.n
            # Find the k where x[i,k] == 1
            for k in 1:data.K
                if value(x[i, k]) > 0.5
                    final_partition[i] = k
                    break
                end
            end
        end
    end

    return status, final_cost, final_partition
end

end 