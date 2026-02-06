"""
Résout SP1 pour obtenir le scénario de déviation des distances (delta1).
Retourne une matrice sparse ou un dictionnaire des delta_ij.
"""
function get_worst_case_delta1(data::ProblemData, y_val::Matrix{Float64})
    # On identifie les arêtes candidates et on calcule leur sensibilité
    candidates = []
    for i in 1:data.n
        for j in (i+1):data.n
            # Coefficient dans la fonction objectif SP1 : y_val * (l_hat_i + l_hat_j) [cite: 97]
            sensitivity = data.l_params[i] + data.l_params[j]
            coeff = y_val[i,j] * sensitivity
            push!(candidates, (i=i, j=j, coeff=coeff, sensitivity=sensitivity))
        end
    end

    # Tri décroissant selon le coefficient (Algorithme glouton )
    sort!(candidates, by = x -> x.coeff, rev=true)

    # Matrice pour stocker le scénario delta^1_{ij}
    delta1 = zeros(Float64, data.n, data.n)
    current_budget = data.L
    
    for cand in candidates
        if current_budget <= 1e-9 break end
        
        # Saturation : min(3.0, budget_restant) [cite: 98]
        amount = min(3.0, current_budget)
        
        delta1[cand.i, cand.j] = amount
        delta1[cand.j, cand.i] = amount # Symétrie
        
        current_budget -= amount
    end
    
    return delta1
end

"""
Résout SP2 pour obtenir le scénario de déviation des poids (delta2) pour une partie k.
Retourne un vecteur des delta_i.
"""
function get_worst_case_delta2(data::ProblemData, x_val_k::Vector{Float64})
    # On prépare les candidats pour le tri
    candidates = []
    for i in 1:data.n
        # Coefficient dans SP2 : w_i * x_ik [cite: 103]
        coeff = data.w_nominal[i] * x_val_k[i]
        push!(candidates, (id=i, coeff=coeff))
    end

    # Tri décroissant (Algorithme glouton [cite: 105])
    sort!(candidates, by = x -> x.coeff, rev=true)

    delta2 = zeros(Float64, data.n)
    current_budget = data.W

    for cand in candidates
        if current_budget <= 1e-9 break end

        # Saturation : min(W_deviation_i, budget_restant) [cite: 50]
        # Note: data.w_deviation correspond à W_D dans le PDF
        limit = data.w_deviation[cand.id]
        amount = min(limit, current_budget)

        delta2[cand.id] = amount
        current_budget -= amount
    end

    return delta2
end

function solve_robust_cutting_plane_naive(data::ProblemData;  epsilon = 1e-5, time_limit = 300, env = Gurobi.Env())
    start_time = time()
    # --- Modèle Maître Initial ---
    model = direct_model(Gurobi.Optimizer(env))
    set_silent(model) # Désactiver les logs Gurobi internes pour clarté
    
    n = data.n
    K = data.K
    
    # Variables [cite: 10, 11, 70]
    @variable(model, x[1:n, 1:K], Bin)
    @variable(model, y[i=1:n, j=i+1:n], Bin)
    @variable(model, eta >= 0)

    # Contraintes structurelles (Statiques)
    # (2) Partitionnement unique [cite: 18]
    @constraint(model, [i=1:n], sum(x[i, k] for k in 1:K) == 1)

    # (4) Lien x et y [cite: 24]
    # y_ij = 1 si i et j dans la même partie.
    # On itère i < j pour éviter les doublons car le graphe est non orienté
    for i in 1:n
        for j in (i+1):n
            for k in 1:K
                @constraint(model, y[i,j] >= x[i, k] + x[j, k] - 1)
            end
        end
    end

    # --- Initialisation (Scénarios nominaux) ---
    # U1* = {0}, U2* = {0} comme suggéré en 3.b [cite: 91, 92]
    
    # Objectif initial : Coûts nominaux
    nominal_cost_expr = @expression(model, sum(data.distances[i,j] * y[i,j] for i in 1:n for j in (i+1):n))
    @constraint(model, eta >= nominal_cost_expr)

    # Capacité initiale : Poids nominaux
    for k in 1:K
        @constraint(model, sum(data.w_nominal[i] * x[i, k] for i in 1:n) <= data.B)
    end

    @objective(model, Min, eta)

    # --- Boucle Principale ---
    iter = 0
    while(true)
        iter+=1
        current_time = time()
        elapsed = current_time - start_time
        remaining = time_limit - elapsed
        if remaining <= 1e-2
            break
        end
        set_time_limit_sec(model, remaining)
        # 1. Résolution du problème maître
        optimize!(model)
        
        if termination_status(model) == MOI.TIME_LIMIT
            break
        end
        current_time = time()
        elapsed = current_time - start_time
        remaining = time_limit - elapsed
        if remaining <= 1e-2
            break
        end
        # Récupération de la solution courante (valeurs flottantes)
        x_val = value.(x)
        y_val = value.(y)
        eta_val = value(eta)
        obj_val = objective_value(model)
        y_matrix = zeros(Float64, n,n)
        for i in 1:n
            for j in i+1:n
                y_matrix[i,j] = y_val[i,j]
            end
        end

        x_matrix = zeros(Float64,n,K)
        for i in 1:n, k in 1:K
            x_matrix[i,k] = x_val[i,k]
        end
        cuts_added = 0
        
        # 2. Séparation SP1 (Objectif / Distances) [cite: 96]
        # On calcule le scénario pire cas delta1 pour la solution courante
        delta1_star = get_worst_case_delta1(data, y_matrix)
        
        # Calcul du coût réel pire cas pour ce delta
        # Coût = Somme (l_ij + delta_ij * (l_hat_i + l_hat_j)) * y_ij
        worst_case_cost = 0.0
        for i in 1:n
            for j in (i+1):n
                term_nominal = data.distances[i,j]
                term_robust = delta1_star[i,j] * (data.l_params[i] + data.l_params[j])
                worst_case_cost += (term_nominal + term_robust) * y_val[i,j]
            end
        end
        
        # Test de violation (Coupe d'optimalité) [cite: 116]
        if eta_val < worst_case_cost - epsilon
            # Ajout de la contrainte (15) au modèle
            # Note importante : La contrainte s'applique aux VARIABLES y, pas aux valeurs y_val
            @constraint(model, eta >= sum(
                (data.distances[i,j] + delta1_star[i,j] * (data.l_params[i] + data.l_params[j])) * y[i,j]
                for i in 1:n for j in (i+1):n
            ))
            cuts_added += 1
        end

        # 3. Séparation SP2 (Faisabilité / Poids) [cite: 102]
        for k in 1:K
            # On récupère le vecteur x_ik pour la partie k
            x_val_k = x_matrix[:, k]
            
            # On calcule le scénario pire cas delta2 pour cette partie
            delta2_star = get_worst_case_delta2(data, x_val_k)
            
            # Calcul du poids total pire cas
            worst_case_weight = sum(data.w_nominal[i] * (1 + delta2_star[i]) * x_matrix[i, k] for i in 1:n)
            
            # Test de violation (Coupe de faisabilité) [cite: 118]
            if worst_case_weight > data.B + epsilon
                # Ajout de la contrainte (16) au modèle
                # On applique delta2_star aux VARIABLES x
                @constraint(model, sum(data.w_nominal[i] * (1 + delta2_star[i]) * x[i, k] for i in 1:n) <= data.B)
                cuts_added += 1
            end
        end
        if cuts_added == 0
            elapsed = time() - start_time
            incumbent_solution = zeros(Int, n)
            x_val = value(x)
            for i in 1:n
                for k in 1:K
                    if x_val[i,k] >= 1 -1e-2
                        incumbent_solution[i] = k  
                        break
                    end
                end
            end
            return ResultatAlgorithme(
                "OPTIMAL", 
                objective_value(model),
                objective_value(model),
                0.,
                elapsed,
                incumbent_solution
                )
        end
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



function solve_robust_lazy_callback(data::ProblemData; time_limit = 300., env = Gurobi.Env())
    # 1. Création du modèle
    # =====================
    model = direct_model(Gurobi.Optimizer(env))
    set_silent(model)
    set_attribute(model, "TimeLimit", time_limit)
    # IMPORTANT : Activer le mode LazyConstraints dans Gurobi
    set_optimizer_attribute(model, "LazyConstraints", 1)
    # set_silent(model) # Décommenter pour moins de logs
    
    n = data.n
    K = data.K
    
    # 2. Variables
    # ============
    @variable(model, x[1:n, 1:K], Bin)
    @variable(model, y[i=1:n, j=i+1:n], Bin)
    @variable(model, eta >= 0)

    # 3. Contraintes Structurelles (Statiques)
    # ========================================
    
    # (2) [cite_start]Partitionnement : chaque sommet dans exactement une partie [cite: 18]
    @constraint(model, [i=1:n], sum(x[i, k] for k in 1:K) == 1)

    # (4) [cite_start]Lien x/y : y_ij = 1 si i et j sont ensemble [cite: 24]
    for i in 1:n
        for j in (i+1):n
            for k in 1:K
                @constraint(model, y[i,j] >= x[i, k] + x[j, k] - 1)
            end
        end
    end

    # 4. Initialisation (Scénarios nominaux U*)
    # =========================================
    # [cite_start]C'est important pour guider le solveur dès le début [cite: 90-93]
    
    # Objectif nominal
    @constraint(model, eta >= sum(data.distances[i,j] * y[i,j] for i in 1:n for j in (i+1):n))

    # Capacités nominales
    for k in 1:K
        @constraint(model, sum(data.w_nominal[i] * x[i, k] for i in 1:n) <= data.B)
    end
    
    @objective(model, Min, eta)

    # 5. Définition du Callback
    # =========================
    function robust_callback(cb_data)
        # On ne vérifie les coupes que si on est sur une solution entière (MIPSOL)
        # JuMP gère cela souvent automatiquement avec `LazyConstraintCallback` 
        # mais c'est le moment où l'on récupère les valeurs candidates.
        
        # A. Récupération des valeurs candidates (x*, y*, eta*)
        # Attention : dans un callback, on utilise callback_value, pas value()
        x_val = zeros(Float64, n, K)
        y_val = zeros(Float64, n, n)
        
        for i in 1:n, k in 1:K
            x_val[i,k] = callback_value(cb_data, x[i,k])
        end
        # Arrondi pour éviter les erreurs numériques (0.99999 -> 1.0)
        x_val = round.(x_val)
        
        for i in 1:n, j in (i+1):n
            val = callback_value(cb_data, y[i,j])
            y_val[i,j] = round(val)
        end
        
        eta_val = callback_value(cb_data, eta)

        epsilon = 1e-5

        # [cite_start]B. Séparation SP1 (Objectif / Distances) [cite: 96]
        # ----------------------------------------
        # Trouver le pire scénario delta1 pour y*
        delta1 = get_worst_case_delta1(data, y_val)
        
        # Calcul du coût pire cas
        worst_case_cost = 0.0
        for i in 1:n
            for j in (i+1):n
                if y_val[i,j] > 0.5
                    dist_nom = data.distances[i,j]
                    dist_rob = delta1[i,j] * (data.l_params[i] + data.l_params[j])
                    worst_case_cost += dist_nom + dist_rob
                end
            end
        end
        
        # [cite_start]Si violation : eta < coût réel -> Ajout Coupe Optimalité (15) [cite: 116]
        if eta_val < worst_case_cost - epsilon
            # Construction de l'expression linéaire pour la coupe
            cut_expr = sum(
                (data.distances[i,j] + delta1[i,j] * (data.l_params[i] + data.l_params[j])) * y[i,j]
                for i in 1:n for j in (i+1):n
            )
            
            # Soumission de la contrainte Lazy
            con = @build_constraint(eta >= cut_expr)
            MOI.submit(model, MOI.LazyConstraint(cb_data), con)
        end

        # [cite_start]C. Séparation SP2 (Faisabilité / Poids) [cite: 102]
        # ---------------------------------------
        for k in 1:K
            # Trouver le pire scénario delta2 pour la partition k
            x_col = x_val[:, k]
            delta2 = get_worst_case_delta2(data, x_col)
            
            # Calcul du poids total pire cas
            worst_case_weight = sum(
                data.w_nominal[i] * (1 + delta2[i]) * x_val[i,k] 
                for i in 1:n
            )
            
            # [cite_start]Si violation : Poids > B -> Ajout Coupe Faisabilité (16) [cite: 118]
            if worst_case_weight > data.B + epsilon
                # Construction de la coupe
                cut_expr_cap = sum(
                    data.w_nominal[i] * (1 + delta2[i]) * x[i, k] 
                    for i in 1:n
                )
                
                # Soumission de la contrainte Lazy
                con = @build_constraint(cut_expr_cap <= data.B)
                MOI.submit(model, MOI.LazyConstraint(cb_data), con)
            end
        end
    end

    # 6. Enregistrement du Callback et Résolution
    # ===========================================
    # On utilise l'interface générique de JuMP pour les Lazy Constraints
    set_attribute(model, MOI.LazyConstraintCallback(), robust_callback)
    optimize!(model)

    # 7. Résultats
    # ============
    status = termination_status(model)
    primal_status = JuMP.primal_status(model)

    if status == MOI.OPTIMAL
        incumbent_solution = zeros(Int64, n)
        x_val = value(x)
        for i in 1:n
            for k in 1:K
                if x_val[i,k] >= 1 -1e-2
                    incumbent_solution[i] = k  
                    break
                end
            end
        end
        return ResultatAlgorithme(
                "OPTIMAL", 
                objective_value(model),
                objective_bound(model),
                (objective_value(model) - objective_bound(model)) / objective_value(model),
                solve_time(model),
                incumbent_solution
                )
    else
        if primal_status == MOI.FEASIBLE_POINT
            incumbent_solution = zeros(Int, n)
            x_val = value(x)
            for i in 1:n
                for k in 1:K
                    if x_val[i,k] >= 1 -1e-2
                        incumbent_solution[i] = k  
                        break
                    end
                end
            end
            return ResultatAlgorithme(
                "FEASIBLE", 
                objective_value(model),
                objective_bound(model),
                (objective_value(model) - objective_bound(model)) / objective_value(model),
                solve_time(model),
                incumbent_solution
                )
        else
            return ResultatAlgorithme(
                "NOTFOUND", 
                Inf,
                -Inf,
                NaN64,
                solve_time(model),
                []
                )
        end
    end
end