module Solver

using JuMP
using Gurobi
using LinearAlgebra
using Statistics
using Random
using Plots
using Printf 
import Base: show

struct ResultatAlgorithme
    termination_status::String;
    best_obj::Float64;
    best_lwbd::Float64;
    gap::Float64;
    total_time::Float64;
    incumbent_solution::Vector{Int}
end


function show(io::IO, r::ResultatAlgorithme)
    print(io, "AlgoRes[$(r.termination_status) | Obj: ")
    @printf(io, "%.2f", r.best_obj)
    print(io, " | Gap: ")
    @printf(io, "%.2f%%]", r.gap * 100)
end


function show(io::IO, ::MIME"text/plain", r::ResultatAlgorithme)
    println(io, "Résultat de l'Algorithme")
    
    println(io, "   ├─ Statut     : ", r.termination_status)
    
    print(io,   "   ├─ Best Obj   : ")
    @printf(io, "%.4f\n", r.best_obj)
    
    print(io,   "   ├─ Best Bound : ")
    @printf(io, "%.4f\n", r.best_lwbd)
    
    print(io,   "   ├─ Gap        : ")
    @printf(io, "%.4f %%\n", r.gap * 100) 
    
    print(io,   "   ├─ Temps      : ")
    @printf(io, "%.4f s\n", r.total_time)
    sol_str = length(r.incumbent_solution) > 15 ? 
              "$(r.incumbent_solution[1:10])..." : 
              string(r.incumbent_solution)
              
    print(io,   "   └─ Solution   : ", sol_str)
end

include("RobustGraphData.jl")
include("column_generation.jl")
include("heuristic_geometric.jl")
include("staticResolution.jl")
include("plotPartition.jl")
include("robustDualResolution.jl")
include("lowerBounds.jl")
include("cuttingPlaneMethod.jl")

function is_feasible_static(data::ProblemData, res::ResultatAlgorithme)
    if res.termination_status == "NOTFOUND"
        return false
    end
    
    assignment = res.incumbent_solution
    partition_weights = zeros(Float64, data.K)
    
    for i in 1:data.n
        k = assignment[i]
        # Sécurité : si l'assignation est 0 ou hors bornes (ex: noeud non assigné)
        if k < 1 || k > data.K
            return false 
        end
        partition_weights[k] += data.w_nominal[i]
    end
    
    # Vérification
    for k in 1:data.K
        if partition_weights[k] > data.B + 1e-6 # Tolérance flottante
            return false
        end
    end
    
    return true
end

function is_feasible_robust(data::ProblemData, res::ResultatAlgorithme)
    if res.termination_status == "NOTFOUND"
        return false
    end
    # On vérifie partition par partition
    assignment = res.incumbent_solution
    for k in 1:data.K

        nodes_in_k = findall(x -> x == k, assignment)
        
        if isempty(nodes_in_k)
            continue
        end
        
        nominal_sum = sum(data.w_nominal[i] for i in nodes_in_k)
        
        deviations = [data.w_deviation[i] for i in nodes_in_k]
        sort!(deviations, rev=true)
        
        current_budget = data.W
        total_deviation = 0.0
        
        for dev_bound in deviations
            # On prend le max possible : soit la borne du sommet, soit le reste du budget
            take = min(dev_bound, current_budget)
            total_deviation += take
            current_budget -= take
            
            if current_budget <= 1e-9
                break
            end
        end
        
        # Vérification
        if nominal_sum + total_deviation > data.B + 1e-6
            return false
        end
    end
    
    return true
end

function calculate_objective_static(data::ProblemData, res::ResultatAlgorithme)
    if res.termination_status == "NOTFOUND"
        return Inf
    end
    assignment = res.incumbent_solution
    total_cost = 0.0
    for i in 1:data.n
        for j in (i+1):data.n
            if assignment[i] == assignment[j]
                total_cost += data.distances[i, j]
            end
        end
    end
    
    return total_cost
end

function calculate_objective_robust(data::ProblemData, res::ResultatAlgorithme)
    if res.termination_status == "NOTFOUND"
        return Inf
    end
    assignment = res.incumbent_solution
    nominal_cost = 0.0
    intra_edges_sensitivity = Float64[]
    
    for i in 1:data.n
        for j in (i+1):data.n
            if assignment[i] == assignment[j]
                nominal_cost += data.distances[i, j]
                sensitivity = data.l_params[i] + data.l_params[j]
                push!(intra_edges_sensitivity, sensitivity)
            end
        end
    end
    sort!(intra_edges_sensitivity, rev=true)
    
    current_budget = data.L
    robust_adder = 0.0
    
    for sens in intra_edges_sensitivity
        amount = min(3.0, current_budget)
        
        robust_adder += amount * sens
        current_budget -= amount
        
        if current_budget <= 1e-9
            break
        end
    end
    
    return nominal_cost + robust_adder
end

export ProblemData, load_instance
export column_generation_heuristic
export heuristic_relaxed_repair_robust, heuristic_relaxed_repair_static
export solve_static_problem_mip
export plot_result
export solve_robust_dualisation
export combinatorial_lower_bound, calculer_minorant_b_matching, calculer_minorant_b_matching_robuste
export solve_robust_cutting_plane_naive, solve_robust_lazy_callback
export is_feasible_static, is_feasible_robust,calculate_objective_robust, calculate_objective_static
end 