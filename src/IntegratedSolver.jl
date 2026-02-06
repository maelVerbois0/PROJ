module Solver

using JuMP
using Gurobi
using LinearAlgebra
using Statistics
using Random
using LinearAlgebra
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

export ProblemData, load_instance
export column_generation_heuristic
export heuristic_relaxed_repair_robust, heuristic_relaxed_repair_static
export solve_static_problem_mip
export plot_result
export solve_robust_dualisation
export combinatorial_lower_bound, calculer_minorant_b_matching, calculer_minorant_b_matching_robuste
export solve_robust_cutting_plane_naive, solve_robust_lazy_callback
end 