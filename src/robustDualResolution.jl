"""
Résout la relaxation linéaire du problème de partitionnement robuste par dualisation.
Basé sur le modèle compact du rapport.
"""
function solve_robust_dualisation(data::ProblemData; time_limit=300., env = Gurobi.Env())
    model = direct_model(Gurobi.Optimizer(env))
    set_silent(model)
    set_attribute(model, "TimeLimit", time_limit)
    n = data.n
    K = data.K


    # --- 2. Variables de décision---
    
    # x_ik : sommet i dans partie k. 
    @variable(model, x[1:n, 1:K], Bin)
    
    # y_ij : arête {i,j} coupée ou non (selon modélisation, ici intra-cluster)
    # Attention: Ton rapport définit y_ij = 1 si i et j sont dans la MEME partie.
    # Le modèle est défini pour chaque arête {i,j} du graphe.
    # Pour simplifier l'indexation, on utilisera un dictionnaire ou on indexera par les tuples
    @variable(model, y[i=1:n, j=i+1:n], Bin)

    # --- 3. Variables Duales (Robustesse) ---
    
    # Duales pour les distances (U1) - Eq 24
    @variable(model, sigma1 >= 0)
    @variable(model, mu1[i=1:n, j = i+1:n] >= 0) # mu_ij^1

    # Duales pour les poids (U2) - Eq 24
    @variable(model, sigma2[1:K] >= 0)       # sigma_k^2
    @variable(model, lambda2[1:n, 1:K] >= 0) # lambda_ik^2

    # --- 4. Objectif (Eq 17) ---
    # Min sum(l_ij * y_ij) + L * sigma1 + sum(3 * mu_ij^1)
    # Note: Le '3' vient de la borne sup de delta_ij^1 définie dans le sujet 
    @objective(model, Min, 
        sum(data.distances[i,j] * y[i,j] for i in 1:n, j in i+1:n) + 
        data.L * sigma1 + 
        sum(3 * mu1[i,j] for i in 1:n, j in i+1:n)
    )

    # --- 5. Contraintes ---

    # (18) Affectation unique : chaque sommet dans exactement une partie
    for i in 1:n
        @constraint(model, sum(x[i, k] for k in 1:K) == 1)
    end

    # (19) Lien linéaire : y_ij >= x_ik + x_jk - 1
    # Cette contrainte force y_ij à 1 si i et j sont tous deux dans k.
    for i in 1:n, j in i+1:n
        for k in 1:K
            @constraint(model, y[i,j] >= x[i, k] + x[j, k] - 1)
        end
    end

    # (20) Contrainte duale robuste distances : sigma1 + mu_ij >= (l_hat_i + l_hat_j) * y_ij
    for i in 1:n, j in i+1:n
        # l_params correspond à l_hat
        coeff_robust = data.l_params[i] + data.l_params[j]
        @constraint(model, sigma1 + mu1[i,j] >= coeff_robust * y[i,j])
    end

    # (21) Capacité Robuste (Dualisée) : Nominal + Coût Robustesse <= B
    # sum(w_i * x_ik) + W * sigma2_k + sum(W_i * lambda_ik) <= B
    for k in 1:K
        term_nominal = sum(data.w_nominal[i] * x[i, k] for i in 1:n)
        term_robust  = data.W * sigma2[k] + sum(data.w_deviation[i] * lambda2[i, k] for i in 1:n)
        
        @constraint(model, term_nominal + term_robust <= data.B)
    end

    # (23) Contrainte duale robuste poids : sigma2_k + lambda_ik >= w_i * x_ik
    for k in 1:K
        for i in 1:n
            @constraint(model, sigma2[k] + lambda2[i, k] >= data.w_nominal[i] * x[i, k])
        end
    end

    # --- 6. Résolution ---
    optimize!(model)

    # --- 7. Récupération des résultats ---
    status = termination_status(model)
    
 status = termination_status(model)
    
    if status == MOI.OPTIMAL
        obj_val = objective_value(model)
        
        # Build a simple dictionary for the partition map
        # partition_map[i] = k
        partition_map = zeros(Int, n)
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




