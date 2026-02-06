function combinatorial_lower_bound(data::ProblemData)
    time_start = time()
    n = data.n
    K = data.K
    dist_matrix = data.distances

    # 1. Determine min number of edges (assuming equipartition)
    base_size = div(n, K)
    remainder = n % K
    # We have 'remainder' clusters of size base_size+1
    # We have 'K - remainder' clusters of size base_size
    
    edges_large = remainder * binomial(base_size + 1, 2)
    edges_small = (K - remainder) * binomial(base_size, 2)
    total_min_edges = edges_large + edges_small

    # 2. Sum the cheapest edges from the graph
    all_edges = filter(!iszero, vec(UpperTriangular(dist_matrix)))
    sort!(all_edges)
    elapsed = time() - time_start
    return sum(all_edges[1:total_min_edges]), elapsed
end


"""
    calculer_minorant_b_matching(data::ProblemData)

Calcule un minorant amélioré en résolvant un problème joint :
choix de la taille des cliques ET choix des arêtes pour satisfaire les degrés.

Cela correspond à une relaxation "b-matching" où les degrés cibles b_v
dépendent de la taille de la clique à laquelle le sommet v est assigné.
"""
function calculer_minorant_b_matching(data::ProblemData; time_limit = 300., env = Gurobi.Env())
    time_start = time()
    n = data.n
    K = data.K
    l_max = n # Taille max théorique d'une clique

    model = direct_model(Gurobi.Optimizer(env))
    set_attribute(model, "TimeLimit", time_limit)

    # --- Variables ---

    # 1. Variables d'arêtes x[i,j] (binaires)
    # x[i,j] = 1 si l'arête entre i et j est sélectionnée
    # On n'indexe que pour i < j pour éviter les doublons
    @variable(model, x[1:n, 1:n], Bin)

    # 2. Variables d'assignation z[i,t] (binaires)
    # z[i,t] = 1 si le sommet i est affecté à une clique de taille t
    @variable(model, z[1:n, 1:l_max], Bin)

    # 3. Variables de comptage N[t] (entières)
    # N[t] = nombre de cliques de taille t dans la partition finale
    @variable(model, N[1:l_max] >= 0, Int)

    # --- Objectif ---
    # Minimiser la somme des poids des arêtes sélectionnées
    # On parcourt i < j
    @objective(model, Min, sum(data.distances[i,j] * x[i,j] for i in 1:n, j in (i+1):n))

    # --- Contraintes Structurelles (Partition) ---

    # C1. Chaque sommet doit appartenir à une et une seule taille de clique
    for i in 1:n
        @constraint(model, sum(z[i, t] for t in 1:l_max) == 1)
    end

    # C2. Cohérence entre les sommets et le nombre de cliques N[t]
    # Si on a N[t] cliques de taille t, alors exactement t * N[t] sommets doivent être assignés à la taille t.
    for t in 1:l_max
        @constraint(model, sum(z[i, t] for i in 1:n) == t * N[t])
    end
    #Cohérence des poids les sommets pour chaque taille de clique ne peuvent pas avoir une somme de plus de B*N[t]
    for t in 1:l_max
        @constraint(model, sum(z[i,t] for i in 1:n) <= data.B * N[t])
    end
    # C3. Nombre total de partitions
    @constraint(model, sum(N[t] for t in 1:l_max) == K)

    # --- Contraintes de Degré (Le cœur de l'amélioration) ---

    # C4. Si le sommet i est dans une clique de taille t (z[i,t]=1),
    # alors son degré dans le graphe induit par x doit être t-1.
    # Degré(i) = Somme des x incidents
    for i in 1:n
        # Expression du degré courant dans la solution
        degree_expr = sum(x[min(i,j), max(i,j)] for j in 1:n if i != j)
        
        # Expression du degré cible : Somme ( (t-1) * z[i,t] )
        target_expr = sum((t - 1) * z[i, t] for t in 1:l_max)
        
        @constraint(model, degree_expr == target_expr)
    end
    
    # --- Contraintes Symétrie / Nettoyage ---
    # Fixer la diagonale et triangle inf à 0 pour propreté (déjà géré par les boucles, mais sécurité)
    for i in 1:n
        fix(x[i,i], 0; force=true)
        for j in 1:(i-1)
            fix(x[i,j], 0; force=true)
        end
    end

    # --- Résolution ---
    optimize!(model)

    status = termination_status(model)
    elapsed = time() - time_start
    if status == MOI.OPTIMAL
        return objective_value(model), elapsed
    else
        return objective_bound(model),elapsed
    end
end



"""
    calculer_minorant_b_matching_robuste(data::ProblemData)

Calcule une borne inférieure pour le problème de partitionnement robuste
en utilisant une relaxation par b-matching (cliques de taille t) et la dualisation.
"""
function calculer_minorant_b_matching_robuste(data::ProblemData; time_limit = 300., env = Gurobi.Env())
    time_start = time()
    n = data.n
    K = data.K
    l_max = n # Taille max théorique d'une partie (dans le pire cas n)

    # Création du modèle
    model = direct_model(Gurobi.Optimizer(env))
    set_attribute(model, "TimeLimit", time_limit)

    # ==================================================================================
    # 1. VARIABLES
    # ==================================================================================

    # --- Variables Structurelles (Graphe et Partition) ---
    # x[i,j] = 1 si l'arête {i,j} est intra-partition
    @variable(model, x[1:n, 1:n], Bin)
    
    # z[i,t] = 1 si le sommet i est dans une partie de taille t
    @variable(model, z[1:n, 1:l_max], Bin)
    
    # N[t] = nombre de parties de taille t
    @variable(model, N[1:l_max] >= 0, Int)

    # --- Variables de Dualisation Robustesse Distances (U1) ---
    @variable(model, sigma1 >= 0)
    @variable(model, mu1[1:n, 1:n] >= 0)

    # --- Variables de Dualisation Robustesse Poids (U2) ---
    @variable(model, S2[1:l_max] >= 0)
    @variable(model, Lambda2[1:n, 1:l_max] >= 0)

    # ==================================================================================
    # 2. OBJECTIF ROBUSTE
    # ==================================================================================
    
    @objective(model, Min, 
        sum(data.distances[i,j] * x[i,j] for i in 1:n, j in (i+1):n) + 
        data.L * sigma1 + 
        sum(3.0 * mu1[i,j] for i in 1:n, j in (i+1):n)
    )

    # ==================================================================================
    # 3. CONTRAINTES
    # ==================================================================================

    # --- A. Contraintes Robustes Distances (Lien Primal-Dual U1) ---
    for i in 1:n, j in (i+1):n
        l_hat_sum = data.l_params[i] + data.l_params[j]
        @constraint(model, sigma1 + mu1[i,j] >= l_hat_sum * x[i,j])
    end

    # --- B. Contraintes Structurelles (Partitionnement Statique) ---
    
    # Chaque sommet doit avoir une taille de partie assignée
    for i in 1:n
        @constraint(model, sum(z[i, t] for t in 1:l_max) == 1)
    end

    # Cohérence : Somme des sommets assignés à la taille t = t * nombre de parties de taille t
    for t in 1:l_max
        @constraint(model, sum(z[i, t] for i in 1:n) == t * N[t])
    end

    # Nombre total de parties
    @constraint(model, sum(N[t] for t in 1:l_max) == K)

    # --- C. Contraintes de Capacité ROBUSTE (Modifié avec U2) ---
    # La contrainte est : Poids Nominal + Coût Robuste <= Capacité
    # Pour le b-matching, on somme cette contrainte sur toutes les N[t] parties de taille t.
    # Formulation duale agrégée [cite: 292] adaptée :
    # Somme(w_i * z_it) + W * S2[t] + Somme(W_i * Lambda2_it) <= B * N[t]
    
    for t in 1:l_max
        # Terme nominal : somme des poids des sommets assignés à la taille t
        nominal_weight = sum(data.w_nominal[i] * z[i, t] for i in 1:n)
        
        # Terme robuste : budget W * S2 (somme des sigmas) + somme pondérée des Lambdas
        # Note: data.w_deviation[i] correspond à W_i dans le PDF
        robust_cost = data.W * S2[t] + sum(data.w_deviation[i] * Lambda2[i, t] for i in 1:n)
        
        @constraint(model, nominal_weight + robust_cost <= data.B * N[t])
    end

    # Lien Dualité Poids : sigma_k + lambda_ik >= w_i * x_ik 
    # En sommant sur les parties de taille t, cela devient : S2[t] + Lambda2[i,t] >= w_i * z[i,t]
    # Cette relaxation est valide pour une borne inférieure.
    for i in 1:n, t in 1:l_max
        @constraint(model, S2[t] + Lambda2[i,t] >= data.w_nominal[i] * z[i,t])
    end

    # --- D. Contraintes de Degré (Relaxation b-matching) ---
    # Si le sommet i est dans une clique de taille t, son degré dans G(x) est t-1.
    for i in 1:n
        degree_expr = sum(x[min(i,j), max(i,j)] for j in 1:n if i != j)
        target_expr = sum((t - 1) * z[i, t] for t in 1:l_max)
        @constraint(model, degree_expr == target_expr)
    end
    
    # --- E. Nettoyage Symétrie ---
    for i in 1:n
        fix(x[i,i], 0; force=true)
        fix(mu1[i,i], 0; force=true) # Fixer le dual diagonal aussi
        for j in 1:(i-1)
            fix(x[i,j], 0; force=true)
            fix(mu1[i,j], 0; force=true)
        end
    end

    # ==================================================================================
    # 4. RÉSOLUTION
    # ==================================================================================
    optimize!(model)
    elapsed = time() - time_start
    status = termination_status(model)
    if status == MOI.OPTIMAL
        return objective_value(model),elapsed
    else
        
        return objective_bound(model),elapsed
    end
end