using Statistics
using Random
using LinearAlgebra

"""
    solve_geometric_heuristic(data::ProblemData; max_iter=100)

Solves the partition problem using a "Cluster-then-Repair" heuristic.
1. K-Means clustering on coordinates (ignores weights).
2. Greedy repair to satisfy capacity constraints B.
"""
function solve_geometric_heuristic(data::ProblemData; max_iter=100)
    # --- Phase 1: Geometric Clustering (K-Means) ---
    # Randomly initialize K centroids from the data points
    Random.seed!(42) # For reproducibility
    centroids = data.coordinates[randperm(data.n)[1:data.K], :]
    assignment = zeros(Int, data.n)
    
    # Simple K-Means Loop
    for iter in 1:max_iter
        # 1. Assign to nearest centroid
        changes = 0
        for i in 1:data.n
            min_dist = Inf
            best_k = 1
            for k in 1:data.K
                # Euclidean distance to centroid k
                d = norm(data.coordinates[i, :] - centroids[k, :])
                if d < min_dist
                    min_dist = d
                    best_k = k
                end
            end
            if assignment[i] != best_k
                assignment[i] = best_k
                changes += 1
            end
        end
        
        # Stop if no changes
        if changes == 0 break end
        
        # 2. Update centroids
        for k in 1:data.K
            # Get points in cluster k
            points_idx = findall(x -> x == k, assignment)
            if !isempty(points_idx)
                # Mean of coordinates
                centroids[k, :] = mean(data.coordinates[points_idx, :], dims=1)
            end
        end
    end

    # --- Phase 2: Capacity Reparation ---
    # Check weights and move nodes if partitions are too heavy
    
    # Calculate current partition weights
    partition_weights = zeros(Float64, data.K)
    for i in 1:data.n
        partition_weights[assignment[i]] += data.w_nominal[i]
    end

    # Reparation Loop
    reparation_iter = 0
    while true
        reparation_iter += 1
        if reparation_iter > max_iter * 10
            println("Warning: Could not fully repair capacities within iteration limit.")
            break
        end

        # Find overloaded partitions
        overloaded = findall(w -> w > data.B + 1e-6, partition_weights) # 1e-6 tolerance
        if isempty(overloaded)
            break # All good!
        end

        # Pick the most overloaded partition to fix
        source_k = overloaded[argmax(partition_weights[overloaded])]

        # Try to move a node from source_k to a valid target_k
        best_node = -1
        best_target = -1
        best_delta = Inf

        # Iterate over all nodes in the overloaded partition
        source_nodes = findall(x -> x == source_k, assignment)
        
        for i in source_nodes
            w_i = data.w_nominal[i]
            
            # Try all other partitions as targets
            for target_k in 1:data.K
                if target_k == source_k continue end
                
                # Check if target has space
                if partition_weights[target_k] + w_i <= data.B
                    # Calculate Cost Delta (Change in objective)
                    # Delta = (Distances to NEW neighbors) - (Distances to OLD neighbors)
                    
                    cost_add = 0.0
                    cost_remove = 0.0
                    
                    # We compute this efficiently by scanning all nodes
                    for other_node in 1:data.n
                        if other_node == i continue end
                        if assignment[other_node] == target_k
                            cost_add += data.distances[i, other_node]
                        elseif assignment[other_node] == source_k
                            cost_remove += data.distances[i, other_node]
                        end
                    end
                    
                    delta = cost_add - cost_remove
                    
                    # We want the move that increases cost the least (or decreases it)
                    if delta < best_delta
                        best_delta = delta
                        best_node = i
                        best_target = target_k
                    end
                end
            end
        end

        # Apply the best move found
        if best_node != -1
            assignment[best_node] = best_target
            partition_weights[source_k] -= data.w_nominal[best_node]
            partition_weights[best_target] += data.w_nominal[best_node]
        else
            # Corner case: No valid move found (Bin Packing is hard).
            # We might be stuck. For a heuristic, we just stop or try randomizing.
            println("Heuristic stuck: No valid move to relieve partition $source_k")
            break
        end
    end

    # --- Final Calculation ---
    total_cost = 0.0
    partition_map = Dict{Int, Int}()
    for i in 1:data.n
        partition_map[i] = assignment[i]
        for j in (i+1):data.n
            if assignment[i] == assignment[j]
                total_cost += data.distances[i, j]
            end
        end
    end

    # Check validity
    is_valid = all(partition_weights .<= data.B + 1e-5)
    status = is_valid ? "FEASIBLE" : "INFEASIBLE_CAPACITY"

    return status, total_cost, partition_map
end