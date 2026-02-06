
struct Column
    nodes::Vector{Int}            # Indices des sommets
    edges::Vector{Tuple{Int,Int}} # Arêtes internes (i,j)
    nominal_cost::Float64         # Coût nominal (somme l_ij)
end

# ==============================================================================
# 2. HEURISTIQUE D'INITIALISATION (K-MEANS + REPAIR RELAXÉ)
# ==============================================================================
# (Reprise de l'heuristique précédente pour générer la solution initiale)

function get_partition_robust_weight(data::ProblemData, node_indices::Vector{Int})
    if isempty(node_indices) return 0.0 end
    nominal_sum = sum(data.w_nominal[i] for i in node_indices)
    candidates = [(w=data.w_nominal[i], b=data.w_deviation[i]) for i in node_indices]
    sort!(candidates, by = x -> x.w, rev=true) # Tri décroissant par poids nominal
    
    budget = data.W
    dev_added = 0.0
    for c in candidates
        take = min(c.b, budget)
        dev_added += c.w * take
        budget -= take
        if budget <= 1e-9 break end
    end
    return nominal_sum + dev_added
end

function calculate_robust_objective_exact(data::ProblemData, assignment::Vector{Int})
    intra_edges = Float64[]
    nominal = 0.0
    for i in 1:data.n, j in (i+1):data.n
        if assignment[i] == assignment[j]
            nominal += data.distances[i,j]
            push!(intra_edges, data.l_params[i] + data.l_params[j]) # Sensibilité
        end
    end
    sort!(intra_edges, rev=true)
    
    budget = data.L
    robust_add = 0.0
    for sens in intra_edges
        take = min(3.0, budget)
        robust_add += take * sens
        budget -= take
        if budget <= 1e-9 break end
    end
    return nominal + robust_add
end


function generate_initial_heuristic_solution(data::ProblemData)
    # 1. K-Means Rapide
    centroids = data.coordinates[randperm(data.n)[1:data.K], :]
    assignment = zeros(Int, data.n)
    for _ in 1:20
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
    
    # 2. Réparation Relaxée (Score Composite)
    total_dist = sum(data.distances)
    lambda = total_dist * 10.0 # Pénalité forte
    
    # Calcul initial de la violation
    function get_viol(assign)
        v = 0.0
        for k in 1:data.K
            rw = get_partition_robust_weight(data, findall(x->x==k, assign))
            v += max(0.0, rw - data.B)
        end
        return v
    end
    
    current_viol = get_viol(assignment)
    current_obj = calculate_robust_objective_exact(data, assignment)
    current_score = current_obj + lambda * current_viol
    
    # Descente locale simple (Move only pour rapidité init)
    max_iter = data.n * 50
    for iter in 1:max_iter
        if current_viol <= 1e-6 break end # Faisable !
        
        node = rand(1:data.n)
        source_k = assignment[node]
        best_target = -1
        best_new_score = current_score
        
        for target_k in 1:data.K
            if target_k == source_k continue end
            assignment[node] = target_k
            
            new_viol = get_viol(assignment)
            new_obj = calculate_robust_objective_exact(data, assignment)
            new_score = new_obj + lambda * new_viol
            
            if new_score < best_new_score - 1e-5
                best_new_score = new_score
                best_target = target_k
            end
            assignment[node] = source_k # Backtrack
        end
        
        if best_target != -1
            assignment[node] = best_target
            current_score = best_new_score
            current_viol = get_viol(assignment)
        end
    end
    
    return [findall(x->x==k, assignment) for k in 1:data.K], (current_viol <= 1e-6)
end




function collect_initial_columns(data::ProblemData; nb_runs=20, verbose = false)
    if verbose
        println("Génération de la population initiale ($nb_runs runs)...")
    end
    unique_columns = Dict{Vector{Int}, Column}()
    
    # On lance l'heuristique nb_runs fois
    for i in 1:nb_runs
        # On utilise votre heuristique (génère 1 solution complète)
        assignment, is_feasible = generate_initial_heuristic_solution(data)
        
        if is_feasible
            for cluster_nodes in assignment
                # On trie les nœuds pour garantir l'unicité de la clé (signature)
                signature = sort(cluster_nodes)
                
                # Si on ne connait pas encore ce cluster, on le crée
                if !haskey(unique_columns, signature)
                    # Création de la colonne (Arêtes i < j)
                    edges = Tuple{Int,Int}[]
                    nominal_cost = 0.0
                    
                    # Double boucle stricte i < j
                    for idx1 in 1:length(signature)
                        for idx2 in (idx1+1):length(signature)
                            u, v = signature[idx1], signature[idx2]
                            # signature est trié, donc u < v est garanti, mais soyons sûrs
                            push!(edges, (u, v))
                            nominal_cost += data.distances[u, v]
                        end
                    end
                    
                    col = Column(cluster_nodes, edges, nominal_cost)
                    unique_columns[signature] = col
                end
            end
        end
    end
    
    final_cols = collect(values(unique_columns))
    if verbose
        println(" -> $(length(final_cols)) colonnes uniques générées.")
    end
    if length(final_cols) < data.K
        while(true)
            assignment, is_feasible = generate_initial_heuristic_solution(data)
            if is_feasible
                for cluster_nodes in assignment
                    # On trie les nœuds pour garantir l'unicité de la clé (signature)
                    signature = sort(cluster_nodes)
                    
                    # Si on ne connait pas encore ce cluster, on le crée
                    if !haskey(unique_columns, signature)
                        # Création de la colonne (Arêtes i < j)
                        edges = Tuple{Int,Int}[]
                        nominal_cost = 0.0
                        
                        # Double boucle stricte i < j
                        for idx1 in 1:length(signature)
                            for idx2 in (idx1+1):length(signature)
                                u, v = signature[idx1], signature[idx2]
                                # signature est trié, donc u < v est garanti, mais soyons sûrs
                                push!(edges, (u, v))
                                nominal_cost += data.distances[u, v]
                            end
                        end
                        
                        col = Column(cluster_nodes, edges, nominal_cost)
                        unique_columns[signature] = col
                    end
                end
                final_cols = collect(values(unique_columns))
                break
            end
        end
    end   
    return final_cols
end




function solve_pricing_exact(data::ProblemData, pi::Vector{Float64}, nu::Float64, alpha::Matrix{Float64}; time_limit_activated = true,
                            time_limit=30.0, stop_at_first=false, env = Gurobi.Env())
    n = data.n
    model = Model(() -> Gurobi.Optimizer(env))
    set_silent(model)
    # --- Paramètres de Performance Gurobi ---
    if time_limit_activated
            set_attribute(model, "TimeLimit", time_limit)
    end
    
    
    if stop_at_first
        # S'arrête dès qu'une solution entière réalisable est trouvée
        # Attention : Gurobi cherche à minimiser. S'il trouve une solution < 0, c'est bon.
        set_attribute(model, "BestObjStop", -1e-6)
        set_attribute(model, "MIPFocus", 1) # Focus sur la recherche de solutions réalisables
    end
    
    # ... (Le reste du modèle : Variables z, y, sigma2... contraintes... objectif) ...
    # ... (Copier le corps de solve_pricing_final ici) ...
    # REPRISE DU CODE PRÉCÉDENT POUR LE MODÈLE :
    
    @variable(model, z[1:n], Bin)
    @variable(model, y[1:n, 1:n], Bin)
    @variable(model, sigma2 >= 0)
    @variable(model, theta2[1:n] >= 0)

    for i in 1:n, j in (i+1):n
        @constraint(model, y[i,j] <= z[i])
        @constraint(model, y[i,j] <= z[j])
        @constraint(model, y[i,j] >= z[i] + z[j] - 1)
    end
    
    for i in 1:n
        @constraint(model, sigma2 + theta2[i] >= data.w_nominal[i] * z[i])
    end
    @constraint(model, sum(data.w_nominal[i]*z[i] for i in 1:n) + data.W*sigma2 + sum(data.w_deviation[i]*theta2[i] for i in 1:n) <= data.B)

    obj_expr = AffExpr(0.0)
    for i in 1:n, j in (i+1):n
        sens = data.l_params[i] + data.l_params[j]
        mod_cost = data.distances[i,j] + alpha[i,j] * sens
        add_to_expression!(obj_expr, mod_cost * y[i,j])
    end
    for i in 1:n add_to_expression!(obj_expr, -pi[i] * z[i]) end
    add_to_expression!(obj_expr, -nu)

    @objective(model, Min, obj_expr)
    
    optimize!(model)

    # --- Récupération ---
    # On vérifie si on a trouvé quelque chose (Optimal OU TimeLimit avec solution)
    status = termination_status(model)
    has_sol = result_count(model) > 0
    
    if has_sol
        rc = objective_value(model)
        z_val = value.(z)
        y_val = value.(y)
        nodes = findall(v -> v > 0.5, z_val)
        edges = Tuple{Int,Int}[]
        nom = 0.0
        for i in 1:n, j in (i+1):n
            if y_val[i,j] > 0.5
                push!(edges, (i,j))
                nom += data.distances[i,j]
            end
        end
        if status == MOI.OPTIMAL
            return Column(nodes, edges, nom), rc, "Optimal"
        end
        return Column(nodes, edges, nom), rc,"NotOptimal"
    end
    
    return nothing, 0.0, "NoSolutionFound"
end

function solve_pricing_wrapper(data::ProblemData, pi::Vector{Float64}, nu::Float64, alpha::Matrix{Float64}, time_limit::Float64; env = Gurobi.Env())
    start_time = time()
    # 1. TENTATIVE HEURISTIQUE (Rapide)
    col, rc = heuristic_pricing(data, pi, nu, alpha)
    if col !== nothing && rc <= -1e-2
        return col, rc, "Heuristic"
    end
    # 2. TENTATIVE MIP RESTREINT (Moyen)
    # On lance le solveur mais on lui dit de s'arrêter après un temps très court.
    col, rc,_ = solve_pricing_exact(data, pi, nu, alpha, time_limit=2, time_limit_activated = true, stop_at_first=false, env = env)
    if col !== nothing && rc <= -1e-2
        return col, rc, "resticted_MIP"
    end
    # 3. TENTATIVE EXACTE (Lente - Fallback obligatoire pour prouver convergence)
    remaining = time_limit - (time() - start_time)
    if remaining <= 0
        return nothing, -Inf, "NoSolutionFound"
    end

    col, rc, status = solve_pricing_exact(data, pi, nu, alpha, time_limit_activated =true, time_limit = remaining, stop_at_first=false, env = env)
    if status == "Optimal"
        return col, rc, "exact_MIP"
    end
    if status == "NotOptimal" && rc <= -1e-2
        return col, rc, "resticted_MIP"
    end
    
    return nothing, -Inf, "NoSolutionFound"
    
end


"""
Fonction mettant en place une stratégie heuristique price and branch pour résoudre le problème de partition de graphe robuste.
Comme le problème de pricing est atroce à résoudre on essaie de le démarrer avec une heuristique gloutonne 
"""
function column_generation_heuristic(data::ProblemData; time_limit = 300., heuristic_runs=30, verbose = false, env = Gurobi.Env())
    if(verbose)
        println("\n--- Démarrage Génération de Colonne ---")
    end
    time_start = time()
    n = data.n
    # 1. INITIALISATION : On récupère une population de colonnes
    columns = collect_initial_columns(data, nb_runs=heuristic_runs)
    # 2. RMP
    rmp = direct_model(Gurobi.Optimizer(env))
    set_silent(rmp)
    
    @variable(rmp, sigma1 >= 0)
    @variable(rmp, mu1[1:n, 1:n] >= 0)
    @variable(rmp, lambda[1:length(columns)] >= 0)

    @objective(rmp, Min, 
        sum(col.nominal_cost * lambda[p] for (p, col) in enumerate(columns)) +
        data.L * sigma1 +
        sum(3.0 * mu1[i,j] for i in 1:n, j in (i+1):n) 
    )

    @constraint(rmp, c_part[i=1:n], 
        sum(lambda[p] for (p, col) in enumerate(columns) if i in col.nodes) == 1
    )
    @constraint(rmp, c_card, sum(lambda) == data.K)
    
    c_link = Matrix{ConstraintRef}(undef, n, n)
    for i in 1:n, j in (i+1):n
        c_link[i,j] = @constraint(rmp, sigma1 + mu1[i,j] >= 0)
        sensitivity = data.l_params[i] + data.l_params[j]
        for (p, col) in enumerate(columns)
            if (i,j) in col.edges
                set_normalized_coefficient(c_link[i,j], lambda[p], -sensitivity)
            end
        end
    end

    # 3. BOUCLE DE GÉNÉRATION
    
    # Variable pour stocker la MEILLEURE borne inférieure valide trouvée
    valid_lower_bound = -Inf
    iter = 0
    while(true)
        iter+=1
        elapsed = time() - time_start
        remaining = time_limit - elapsed
        if(remaining <= 0)
            break
        end
        set_time_limit_sec(rmp, remaining)
        optimize!(rmp)
        
        if termination_status(rmp) == MOI.TIME_LIMIT
            if verbose
                println("Limite de temps atteinte")
            end
            break
        end
        
        # Z_RMP : C'est une Upper Bound de la relaxation !
        obj_rmp = objective_value(rmp)
        
        pi_val = dual.(c_part)
        nu_val = dual(c_card)
        alpha_val = zeros(Float64, n, n)
        for i in 1:n, j in (i+1):n
            alpha_val[i,j] = dual(c_link[i,j])
        end

        #On lance des résolutions exactes à la fin pour affiner la borne inférieure
        elapsed = time() - time_start
        remaining = time_limit - elapsed
        if elapsed/time_limit >= 0.8
            new_col, rc, status = solve_pricing_exact(data, pi_val, nu_val, alpha_val, time_limit_activated = true, 
                                            time_limit = remaining, env = env)
            if status == "Optimal"
                if rc >= -1e-5
                    valid_lower_bound = obj_rmp
                    break
                end
                lb = obj_rmp + data.K * rc
                if lb > valid_lower_bound
                    valid_lower_bound = lb
                end  
            end
        else
        
            new_col, rc, solve_method = solve_pricing_wrapper(data, pi_val, nu_val, alpha_val, remaining, env = env)
            if(solve_method == "exact_MIP")
                if rc >= -1e-5
                    valid_lower_bound = obj_rmp
                    break
                end
                lb = obj_rmp + data.K * rc
                if lb > valid_lower_bound
                    valid_lower_bound = lb
                end
            end
        end

        #Au cas ou on est pas réussi a solve à l'optimalité et qu'on a un cout réduit positif
        if(rc >= -1e-5)
            continue
        end
        # Ajout Colonne
        push!(columns, new_col)
        new_idx = length(columns)
        new_var = @variable(rmp, lower_bound=0, base_name="lambda_$new_idx")
        set_objective_coefficient(rmp, new_var, new_col.nominal_cost)
        set_normalized_coefficient(c_card, new_var, 1.0)
        for node in new_col.nodes
            set_normalized_coefficient(c_part[node], new_var, 1.0)
        end
        for (u, v) in new_col.edges
            i, j = minmax(u, v) 
            sensitivity = data.l_params[i] + data.l_params[j]
            set_normalized_coefficient(c_link[i,j], new_var, -sensitivity)
        end
        
    
        if verbose
            println("Iter $iter | Obj_RMP : $(round(obj_rmp, digits=2))  | LB : $(round(valid_lower_bound, digits = 4)) | RC: $(round(rc, digits=4))")
        end
    end
    
    # 4. RESOLUTION ENTIERE
    if verbose
        println("\n--- Résolution Entière ---")
    end
    mip = direct_model(Gurobi.Optimizer(env))
    set_silent(mip)
    @variable(mip, sigma1 >= 0)
    @variable(mip, mu1[1:n, 1:n] >= 0)
    @variable(mip, lambda_bin[1:length(columns)], Bin)
    
    @objective(mip, Min, 
        sum(columns[p].nominal_cost * lambda_bin[p] for p in 1:length(columns)) +
        data.L * sigma1 +
        sum(3.0 * mu1[i,j] for i in 1:n, j in (i+1):n)
    )
    
    @constraint(mip, [i=1:n], 
        sum(lambda_bin[p] for p in 1:length(columns) if i in columns[p].nodes) == 1
    )
    @constraint(mip, sum(lambda_bin) == data.K)
    
    for i in 1:n, j in (i+1):n
        sens = data.l_params[i] + data.l_params[j]
        rel_cols = [p for p in 1:length(columns) if (i,j) in columns[p].edges]
        if !isempty(rel_cols)
            @constraint(mip, sigma1 + mu1[i,j] >= sens * sum(lambda_bin[p] for p in rel_cols))
        else
            @constraint(mip, sigma1 + mu1[i,j] >= 0)
        end
    end
    
    optimize!(mip)
    best_obj = (termination_status(mip) == MOI.OPTIMAL) ? objective_value(mip) : Inf
    elapsed = time() - time_start
    gap = (best_obj - valid_lower_bound)/best_obj
    if verbose
        println("\n=== RÉSULTATS VALIDÉS ===")
        println("Meilleur borne inférieure (LB) : $(round(valid_lower_bound, digits = 4))")
        println("Gap prouvée : $(round(gap, digits = 4))")
        println("Meilleure Solution (UB)   : $(round(best_obj, digits=4))")
    end
    incum_solution_cluster =  [columns[i].nodes for i in 1:length(columns) if value(lambda_bin[i]) >= 1-1e-2]
    incumbent_solution = zeros(Int, data.n)
    for k in 1:data.K
        for i in incum_solution_cluster[k]
            incumbent_solution[i]=k
        end
    end

    return ResultatAlgorithme(
                "FEASIBLE", 
                best_obj,
                valid_lower_bound,
                gap,
                elapsed,
                incumbent_solution
                )
end



#----------------------------------------------------------ENCORE UNE HEURISTIQUE GLOUTONNE DE PRICING--------------------------
# Fonction pour calculer le coût réduit d'un cluster donné
# Cost = Sum(modified_l_ij) - Sum(pi_i) - nu
function compute_reduced_cost(cluster::Vector{Int}, mod_costs::Matrix{Float64}, pi::Vector{Float64}, nu::Float64)
    cost = -nu
    # Terme linéaire (nœuds)
    for i in cluster
        cost -= pi[i]
    end
    # Terme quadratique (arêtes) - On parcourt i < j pour éviter les doublons
    m = length(cluster)
    if m > 1
        for i_idx in 1:m
            u = cluster[i_idx]
            for j_idx in (i_idx+1):m
                v = cluster[j_idx]
                cost += mod_costs[u, v]
            end
        end
    end
    return cost
end

function heuristic_pricing(
    data::ProblemData, 
    pi::Vector{Float64}, 
    nu::Float64, 
    alpha::Matrix{Float64};
    max_samples::Int=20,     # Taille de l'échantillon pour la recherche locale
    max_iter_ls::Int=100     # Nb max d'itérations sans amélioration
)
    n = data.n
    
    # 1. Pré-calcul de la matrice des coûts modifiés tilde_l_ij
    # tilde_l_ij = l_ij + alpha_ij * (l_hat_i + l_hat_j)
    # On la calcule une fois pour toutes pour accélérer les lookups
    mod_costs = zeros(n, n)
    for i in 1:n, j in (i+1):n
        val = data.distances[i, j] + alpha[i, j] * (data.l_params[i] + data.l_params[j])
        mod_costs[i, j] = val
        mod_costs[j, i] = val
    end

    # Variables pour stocker la meilleure solution globale trouvée
    best_global_cluster = Int[]
    best_global_rc = 0.0 # On cherche < 0, on peut init à 0 ou Inf
    found_negative = false

    # --- STRATÉGIE MULTI-START ---
    # On lance le glouton depuis quelques points prometteurs (ex: top 3 pi_i) et un random
    seeds = sortperm(pi, rev=true)[1:min(n, 5)] # 5 meilleurs pi
    push!(seeds, rand(1:n)) # + 1 aléatoire
    
    unique!(seeds)

    for seed_node in seeds
        # --- A. CONSTRUCTION GLOUTONNE ---
        current_cluster = [seed_node]
        in_cluster = fill(false, n)
        in_cluster[seed_node] = true
        
        # Tant qu'on peut ajouter, on ajoute le meilleur candidat
        while true
            best_candidate = -1
            best_gain = 0.0 # On ne prend que si gain < 0 (réduction du coût)
            
            # Évaluation rapide des candidats (ajout simple)
            for i in 1:n
                if !in_cluster[i]
                    # Gain approximatif: coût des arêtes ajoutées - pi_i
                    # (On ignore la robustesse ici pour la vitesse de sélection, on vérifie après)
                    edge_cost = sum(mod_costs[i, u] for u in current_cluster; init = 0.0)
                    delta_rc = edge_cost - pi[i]
                    
                    if delta_rc < best_gain # On cherche à minimiser
                        # Vérification Robustesse (coûteuse, on la fait si le score est bon)
                        temp_cluster = [current_cluster; i]
                        if get_partition_robust_weight(data, temp_cluster) <= data.B
                            best_gain = delta_rc
                            best_candidate = i
                        end
                    end
                end
            end
            
            if best_candidate != -1
                push!(current_cluster, best_candidate)
                in_cluster[best_candidate] = true
            else
                break # Plus d'amélioration possible ou capacité atteinte
            end
        end

        # --- B. RECHERCHE LOCALE (SAMPLED) ---
        # On applique Add / Drop / Swap sur un échantillon aléatoire
        
        iter_no_improv = 0
        current_rc = compute_reduced_cost(current_cluster, mod_costs, pi, nu)
        
        while iter_no_improv < max_iter_ls
            improved = false
            
            # On sépare les nœuds In et Out
            nodes_in = current_cluster
            nodes_out = [i for i in 1:n if !in_cluster[i]]
            
            # Échantillonnage
            sample_in = length(nodes_in) > max_samples ? shuffle(nodes_in)[1:max_samples] : nodes_in
            sample_out = length(nodes_out) > max_samples ? shuffle(nodes_out)[1:max_samples] : nodes_out
            
            # 1. TENTATIVE DROP (Toujours réalisable en capacité)
            # Retirer un nœud qui coûte cher (ex: faible pi, arêtes coûteuses)
            for u in sample_in
                # Delta = - (Sum arêtes internes liées à u) - (-pi_u)
                edge_rem = sum(mod_costs[u, v] for v in nodes_in if v != u; init = 0.0)
                delta = - (edge_rem - pi[u]) 
                
                if delta < -1e-6 # Amélioration stricte
                    # Apply Drop
                    filter!(x -> x != u, current_cluster)
                    in_cluster[u] = false
                    current_rc += delta
                    improved = true
                    break # First improvement
                end
            end
            if improved 
                iter_no_improv = 0; continue 
            end

            # 2. TENTATIVE ADD
            for v in sample_out
                # Delta = Sum arêtes vers cluster - pi_v
                edge_add = sum(mod_costs[v, u] for u in nodes_in; init = 0.0)
                delta = edge_add - pi[v]
                
                if delta < -1e-6
                    # Check Robustesse
                    push!(nodes_in, v) # Temporaire
                    if get_partition_robust_weight(data, nodes_in) <= data.B
                        # Apply Add
                        in_cluster[v] = true
                        current_rc += delta
                        improved = true
                        # Note: nodes_in est une ref à current_cluster, donc c'est déjà updaté
                        break 
                    else
                        pop!(nodes_in) # Backtrack
                    end
                end
            end
            if improved 
                iter_no_improv = 0; continue 
            end

            # 3. TENTATIVE SWAP (u in, v out)
            # Uniquement si on n'a pas réussi à Add ou Drop
            # On sample des paires
            if !isempty(sample_in) && !isempty(sample_out)
                # On limite le nombre de paires testées pour éviter n*m
                nb_pairs = min(length(sample_in)*length(sample_out), max_samples)
                pairs = []
                for _ in 1:nb_pairs
                    push!(pairs, (rand(sample_in), rand(sample_out)))
                end
                
                for (u, v) in pairs
                    # Delta = (Arêtes(v) - Arêtes(u) - coût(u,v)) - pi_v + pi_u
                    # Attention: coût(u,v) est compté dans Arêtes(v) via u, mais u part...
                    # Calcul propre :
                    edges_u = sum(mod_costs[u, k] for k in nodes_in if k != u; init = 0.0)
                    edges_v = sum(mod_costs[v, k] for k in nodes_in if k != u; init = 0.0) # k != u car u sort
                    
                    delta = (edges_v - edges_u) - pi[v] + pi[u]
                    
                    if delta < -1e-6
                        # Simulation du Swap pour robustesse
                        temp_cluster = filter(x -> x != u, nodes_in)
                        push!(temp_cluster, v)
                        
                        if get_partition_robust_weight(data, temp_cluster) <= data.B
                            # Apply Swap
                            filter!(x -> x != u, current_cluster)
                            push!(current_cluster, v)
                            in_cluster[u] = false
                            in_cluster[v] = true
                            current_rc += delta
                            improved = true
                            break
                        end
                    end
                end
            end

            if improved
                iter_no_improv = 0
            else
                iter_no_improv += 1
            end
        end
        
        # --- MISE A JOUR GLOBALE ---
        if current_rc < best_global_rc - 1e-9
            best_global_rc = current_rc
            best_global_cluster = copy(current_cluster)
            found_negative = true
        end
        
    end

    return build_column(best_global_cluster, data), best_global_rc
end

function build_column(nodes::Vector{Int}, data::ProblemData)
    # 1. On trie les nœuds pour avoir une représentation canonique
    sorted_nodes = sort(nodes)
    
    internal_edges = Vector{Tuple{Int,Int}}()
    nom_cost = 0.0
    
    # 2. On itère sur toutes les paires pour identifier les arêtes et sommer les coûts
    m = length(sorted_nodes)
    if m > 1
        for i in 1:m
            u = sorted_nodes[i]
            for j in (i+1):m
                v = sorted_nodes[j]
                
                # Ajout de l'arête (u, v) avec u < v
                push!(internal_edges, (u, v))
                
                # Somme des distances nominales (l_ij) issues de ProblemData
                # Attention : on suppose que data.distances est symétrique ou remplie pour u < v
                nom_cost += data.distances[u, v]
            end
        end
    end
    
    return Column(sorted_nodes, internal_edges, nom_cost)
end


