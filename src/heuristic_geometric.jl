
function heuristic_relaxed_repair_static(data::ProblemData; max_iter=100, max_local_search_iter=500, lambda_factor=10.0)
    # --- Phase 1: K-Means Clustering ---
    time_start = time()
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
        
        for k in 1:data.K
            idxs = findall(x->x==k, assignment)
            if !isempty(idxs)
                centroids[k,:] = mean(data.coordinates[idxs,:], dims=1)
            end
        end
    end

    # --- Phase 2: Local Search avec Pénalité & Tracking ---

    # Paramètres de pénalité
    total_distance_sum = sum(data.distances) / 2
    lambda = total_distance_sum * lambda_factor

    # Structures de données
    partition_weights = zeros(Float64, data.K)
    for i in 1:data.n
        partition_weights[assignment[i]] += data.w_nominal[i]
    end

    node_cluster_costs = zeros(Float64, data.n, data.K)
    for i in 1:data.n
        for j in 1:data.n
            if i != j
                node_cluster_costs[i, assignment[j]] += data.distances[i, j]
            end
        end
    end

    # Tracking du coût géométrique courant 

    current_geo_cost = 0.0
    for i in 1:data.n
        current_geo_cost += node_cluster_costs[i, assignment[i]]
    end
    current_geo_cost /= 2.0

    best_feasible_assignment = copy(assignment) 

    # Vérification initiale de faisabilité
    init_violation = sum(max(0.0, partition_weights[k] - data.B) for k in 1:data.K)
    best_feasible_cost = (init_violation <= 1e-5) ? current_geo_cost : Inf

    # Si la solution initiale n'est pas faisable, best_feasible_cost reste Inf 
    # jusqu'à ce qu'on trouve une première solution valide.

    get_violation(w) = max(0.0, w - data.B)

    # Boucle de Recherche Locale
    for iter in 1:max_local_search_iter
        best_delta_composite = -1e-5 
        best_delta_geo = 0.0 # Pour mettre à jour current_geo_cost
        best_type = :none 
        move_params = (-1, -1)
        swap_params = (-1, -1)

        # --- A. MOVES ---
        for i in 1:data.n
            src = assignment[i]
            w_i = data.w_nominal[i]
            current_viol_src = get_violation(partition_weights[src])
            
            for tgt in 1:data.K
                if src == tgt continue end
                
                delta_dist = node_cluster_costs[i, tgt] - node_cluster_costs[i, src]
                
                current_viol_tgt = get_violation(partition_weights[tgt])
                new_viol_src = get_violation(partition_weights[src] - w_i)
                new_viol_tgt = get_violation(partition_weights[tgt] + w_i)
                
                delta_viol = (new_viol_src + new_viol_tgt) - (current_viol_src + current_viol_tgt)
                total_delta = delta_dist + (lambda * delta_viol)
                
                if total_delta < best_delta_composite
                    best_delta_composite = total_delta
                    best_delta_geo = delta_dist
                    best_type = :move
                    move_params = (i, tgt)
                end
            end
        end

        # --- B. SWAPS ---
        for i in 1:(data.n - 1)
            for j in (i+1):data.n
                k_i = assignment[i]
                k_j = assignment[j]
                if k_i == k_j continue end
                
                w_i = data.w_nominal[i]
                w_j = data.w_nominal[j]
                d_ij = data.distances[i, j]
                
                loss_old = node_cluster_costs[i, k_i] + node_cluster_costs[j, k_j]
                gain_new = (node_cluster_costs[i, k_j] - d_ij) + (node_cluster_costs[j, k_i] - d_ij)
                delta_dist = gain_new - loss_old
                
                viol_old = get_violation(partition_weights[k_i]) + get_violation(partition_weights[k_j])
                viol_new = get_violation(partition_weights[k_i] - w_i + w_j) + get_violation(partition_weights[k_j] - w_j + w_i)
                delta_viol = viol_new - viol_old
                
                total_delta = delta_dist + (lambda * delta_viol)
                
                if total_delta < best_delta_composite
                    best_delta_composite = total_delta
                    best_delta_geo = delta_dist
                    best_type = :swap
                    swap_params = (i, j)
                end
            end
        end

        # --- C. Application & Tracking ---
        if best_type == :none
            break
        
        elseif best_type == :move
            u, tgt = move_params
            src = assignment[u]
            
            assignment[u] = tgt
            partition_weights[src] -= data.w_nominal[u]
            partition_weights[tgt] += data.w_nominal[u]
            current_geo_cost += best_delta_geo # Update coût géométrique
            
            for x in 1:data.n
                if x != u
                    d_xu = data.distances[x, u]
                    node_cluster_costs[x, src] -= d_xu
                    node_cluster_costs[x, tgt] += d_xu
                end
            end
            
        elseif best_type == :swap
            u, v = swap_params
            k_u = assignment[u]
            k_v = assignment[v]
            
            assignment[u] = k_v
            assignment[v] = k_u
            
            partition_weights[k_u] = partition_weights[k_u] - data.w_nominal[u] + data.w_nominal[v]
            partition_weights[k_v] = partition_weights[k_v] - data.w_nominal[v] + data.w_nominal[u]
            current_geo_cost += best_delta_geo 
            
            for x in 1:data.n
                if x != u && x != v
                    d_xu = data.distances[x, u]
                    d_xv = data.distances[x, v]
                    node_cluster_costs[x, k_u] -= d_xu
                    node_cluster_costs[x, k_v] += d_xu
                    node_cluster_costs[x, k_v] -= d_xv
                    node_cluster_costs[x, k_u] += d_xv
                end
                d_uv = data.distances[u, v]
                node_cluster_costs[u, k_u] += d_uv 
                node_cluster_costs[v, k_u] -= d_uv
                node_cluster_costs[u, k_v] -= d_uv
                node_cluster_costs[v, k_v] += d_uv
            end
        end

        # --- D. Check Feasibility & Save Best ---
        # On vérifie si la nouvelle config est faisable
        is_feasible = true
        for k in 1:data.K
            if partition_weights[k] > data.B + 1e-5
                is_feasible = false
                break
            end
        end

        if is_feasible
            if current_geo_cost < best_feasible_cost
                best_feasible_cost = current_geo_cost
                best_feasible_assignment .= assignment # Copie in-place des valeurs
            end
        end
    end

    # Si on a trouvé au moins une solution faisable, on la renvoie.
    # Sinon (cas très contraint ou lambda trop faible), on renvoie la dernière solution explorée.
    # --- F. Retour ---
    elapsed = time() - time_start
    if best_feasible_cost < Inf
        elapsed = time() - time_start
        return ResultatAlgorithme(
                "FEASIBLE", 
                best_feasible_cost,
                -Inf,
                Inf,
                elapsed,
                best_feasible_assignment
                )
    else
        _, final_obj, _ = evaluate_state(data, assignment, lambda)
        elapsed = time() - time_start
        return ResultatAlgorithme(
                "NOTFOUNDFEASIBLE", 
                final_obj,
                -Inf,
                NaN64,
                elapsed,
                assignment
                )
    end
end

function calculate_objective_partition_static(data::ProblemData, node_indices::Vector{Int})
    clusters = [findall(x->x==k, node_indices) for k in 1:data.K] 
    obj = 0
    for k in 1:data.K
        obj += sum(data.distances[i,j]  for i in clusters[k], j in clusters[k])
    end
    return 1/2 * obj
end

function calculate_total_violation_static(data::ProblemData, node_indices::Vector{Int})
    clusters = [findall(x->x==k, node_indices) for k in 1:data.K]
    total_violation = 0
    for k in 1:data.K 
        total_violation += max(sum(data.w_nominal[i] for i in clusters[k]) - data.B, 0.)
    end
    return total_violation
end


# ==================================================================================
# 2- Heuristique Robuste
# ==================================================================================

function get_partition_robust_weight(data::ProblemData, node_indices::Vector{Int})
    if isempty(node_indices) return 0.0 end
    
    # 1. Somme nominale
    nominal_sum = sum(data.w_nominal[i] for i in node_indices)
    
    # 2. Préparation des données pour le Knapsack continu
    # On crée des tuples (poids_nominal, borne_deviation)
    # Gain = w_nominal (car terme = w_i * delta_i)
    # Capacité individuelle = w_deviation (car 0 <= delta_i <= W_i)
    candidates = [
        (weight=data.w_nominal[i], bound=data.w_deviation[i]) 
        for i in node_indices
    ]
    
    # 3. Tri glouton : on privilégie les noeuds avec le plus gros poids nominal
    sort!(candidates, by = x -> x.weight, rev=true)
    
    current_budget = data.W
    total_deviation_added = 0.0
    
    for cand in candidates
        # Combien de delta peut-on donner à ce noeud ?
        # Limité par sa borne individuelle ET le budget global restant
        delta_val = min(cand.bound, current_budget)
        
        # L'ajout au poids total est w_i * delta_i
        total_deviation_added += cand.weight * delta_val
        
        current_budget -= delta_val
        
        if current_budget <= 1e-9
            break
        end
    end
    
    return nominal_sum + total_deviation_added
end

"""
Calcule la fonction objectif globale robuste (Pire cas U1).
(Pas de changement de logique ici, mais inclus pour complétude)
"""
function calculate_robust_objective(data::ProblemData, assignment::Vector{Int})
    intra_edges = []
    nominal_cost = 0.0
    
    # Identification des arêtes intra-classes
    for i in 1:data.n
        for j in (i+1):data.n
            if assignment[i] == assignment[j]
                nominal_cost += data.distances[i,j]
                
                # Le coefficient de sensibilité est (l_hat_i + l_hat_j) [Source: 31]
                # Le terme robuste est delta_ij * (l_hat_i + l_hat_j)
                # On trie donc par ce coefficient.
                sensitivity = data.l_params[i] + data.l_params[j]
                push!(intra_edges, sensitivity)
            end
        end
    end
    
    # Tri glouton sur U1 : on alloue delta sur les arêtes les plus sensibles
    sort!(intra_edges, rev=true)
    
    budget_L = data.L
    robust_adder = 0.0
    
    for sensitivity in intra_edges
        # Variable delta_ij dans [0, 3]
        amount = min(3.0, budget_L)
        
        robust_adder += amount * sensitivity
        budget_L -= amount
        
        if budget_L <= 1e-9 break end
    end
    
    return nominal_cost + robust_adder
end

"""
Calcule la violation totale de capacité robuste sur toutes les partitions.
Violation = Somme(max(0, PoidsRobuste(k) - B))
"""
function calculate_total_violation(data::ProblemData, assignment::Vector{Int})
    total_violation = 0.0
    for k in 1:data.K
        # On récupère les indices des nœuds de la partition k
        nodes = findall(x -> x == k, assignment)
        
        # Calcul du poids robuste (méthode corrigée précédemment)
        rw = get_partition_robust_weight(data, nodes)
        
        # On ajoute l'excédent par rapport à B
        if rw > data.B
            total_violation += (rw - data.B)
        end
    end
    return total_violation
end

"""
Fonction d'évaluation globale.
Retourne : (ScoreComposite, CoûtObjectif, ViolationTotale)
Score = CoûtObjectif + (PenaltyFactor * ViolationTotale)
"""
function evaluate_state(data::ProblemData, assignment::Vector{Int}, penalty_factor::Float64)
        # 1. Calcul du coût objectif robuste (U1 - Arêtes)
        obj_robust = calculate_robust_objective(data, assignment)
        
        # 2. Calcul de la violation de capacité robuste (U2 - Poids)
        violation = calculate_total_violation(data, assignment)
        
        # 3. Score composite
        # Le facteur de pénalité doit être assez grand pour prioriser la faisabilité
        score = obj_robust + (penalty_factor * violation)
        
        return score, obj_robust, violation
    end

    # ==================================================================================
    # 2. HEURISTIQUE DE RÉPARATION RELAXÉE (MOVE + SWAP)
    # ==================================================================================

function heuristic_relaxed_repair_robust(data::ProblemData; 
                                max_iter_k_means = 100, 
                                lambda_factor = 1.0, 
                                max_iter_descente = 200, 
                                target_time_per_iter = 1.,
                                verbose = false) 
    t_start_tot = time()

    # --- A. Initialisation K-Means ---
    centroids = data.coordinates[randperm(data.n)[1:data.K], :]
    assignment = zeros(Int, data.n)
    for _ in 1:max_iter_k_means
        for i in 1:data.n
            assignment[i] = argmin([norm(data.coordinates[i,:] - centroids[k,:]) for k in 1:data.K])
        end
        for k in 1:data.K
            idxs = findall(x->x==k, assignment)
            if !isempty(idxs)
                centroids[k,:] = mean(data.coordinates[idxs,:], dims=1)
            end
        end
    end

    # --- B. Paramètres de la Relaxation Dynamique ---
    total_dist_sum = sum(data.distances)
    lambda = total_dist_sum * lambda_factor
    rho = 1.1 

    # --- C. Calibrage du Budget Temporel ---

    t_start = time()
    current_score, current_obj, current_viol = evaluate_state(data, assignment, lambda)
    t_one_eval = time() - t_start

    if t_one_eval < 1e-5
        t_one_eval = 1e-5
    end


    total_calls_budget = min(Int(floor(target_time_per_iter / t_one_eval)), 10000)
    total_calls_budget = max(20, total_calls_budget)

    num_move_trials = min(div(total_calls_budget, 2), data.n*data.K)
    num_swap_trials = total_calls_budget - num_move_trials

    if verbose
    println("Calibrage auto : 1 eval ≈ $(round(t_one_eval, sigdigits=3))s.")
    println("Budget : $(total_calls_budget) evals/iter (Moves: $num_move_trials, Swaps: $num_swap_trials)")
    end

    best_feasible_assignment = copy(assignment)
    best_feasible_obj = Inf

    if current_viol <= 1e-6
        best_feasible_obj = current_obj
    else
        best_feasible_obj = Inf
    end

    # --- E. Boucle de Descente  ---

    for iter in 1:max_iter_descente
        if verbose println("Current iteration : $(iter)/$(max_iter_descente), Best current feasible solution : $(best_feasible_obj)") end
        best_delta = Inf
        best_action = :none
        best_params = (-1, -1)
        current_delta = 0
        # 1. Échantillonnage des MOVES (Budget fix)
        for _ in 1:num_move_trials
            node = rand(1:data.n)
            source_k = assignment[node]
            target_k = rand(1:data.K)
            
            if target_k == source_k continue end
            
            # Simulation
            assignment[node] = target_k
            
            # Éval
            cand_score, _, _ = evaluate_state(data, assignment, lambda)
            current_delta = cand_score - current_score
            if current_delta < best_delta - 1e-5
                best_delta= current_delta
                best_action = :move
                best_params = (node, target_k)
            end
            
            # Backtrack
            assignment[node] = source_k
        end
        
        # 2. Échantillonnage des SWAPS (Budget fix)
        for _ in 1:num_swap_trials
            node_a = rand(1:data.n)
            node_b = rand(1:data.n)
            k_a = assignment[node_a]
            k_b = assignment[node_b]
            
            if k_a == k_b continue end
            
            # Simulation
            assignment[node_a] = k_b
            assignment[node_b] = k_a
            
            # Éval
            cand_score, _, _ = evaluate_state(data, assignment, lambda)
            current_delta = cand_score - current_score
            if current_delta < best_delta - 1e-5
                best_delta = current_delta
                best_action = :swap
                best_params = (node_a, node_b)
            end
            
            # Backtrack
            assignment[node_a] = k_a
            assignment[node_b] = k_b
        end
        
        # --- 3. Application du Mouvement & Mise à jour Lambda ---
        
        if best_action != :none
            if best_action == :move
                node, target = best_params
                assignment[node] = target
            elseif best_action == :swap
                node_a, node_b = best_params
                tmp_k = assignment[node_a]
                assignment[node_a] = assignment[node_b]
                assignment[node_b] = tmp_k
            end
            
            _, current_obj, current_viol = evaluate_state(data, assignment, lambda)
            
            if current_viol <= 1e-6
                if current_obj < best_feasible_obj
                    best_feasible_obj = current_obj
                    best_feasible_assignment .= assignment
                end
            end
            
            # Update Lambda 
            if current_viol > 1e-6
                lambda *= rho 
            else
                lambda /= rho 
            end
            
            # Recalcul du score de référence avec le nouveau lambda
            current_score, _, _ = evaluate_state(data, assignment, lambda)
        end
    end

    # --- F. Retour ---
    if best_feasible_obj < Inf
        elapsed = time() - t_start_tot
        return ResultatAlgorithme(
                "FEASIBLE", 
                best_feasible_obj,
                0.,
                1,
                elapsed,
                best_feasible_assignment
                )
    else
        _, final_obj, _ = evaluate_state(data, assignment, lambda)
        elapsed = time() - t_start_tot
        return ResultatAlgorithme(
                "NOTFOUND", 
                final_obj,
                -Inf,
                NaN64,
                elapsed,
                assignment
                )
    end
end


