include("../IntegratedSolver.jl")
include("get_all_files.jl")
using Gurobi, Printf
using .Solver
using .GetFile

filenames = get_file()
const_env = Gurobi.Env()


data = load_instance("data/10_ulysses_3.tsp")
combinatorial_lower_bound(data)
calculer_minorant_b_matching(data)
calculer_minorant_b_matching_robuste(data)

filenames = get_file()
fichier_resultats = "results/logs/resultats_bornes_inf.csv"
const_env=Gurobi.Env()
open(fichier_resultats, "w") do io
    println(io, "Instance,combinatorial_lower_bound_value, combinatorial_time, pseudo_clique_statique_value,pseudo_clique_statique_time,pseudo_clique_robuste_value,pseudo_clique_robuste_time")
    for file in filenames
        instance = String(split(file, ".")[1])
        data = load_instance("data/$(file)")
        combinatorial_lower_bound_value, combinatorial_time = combinatorial_lower_bound(data)
        pseudo_clique_statique_value,pseudo_clique_statique_time = calculer_minorant_b_matching(data)
        pseudo_clique_robuste_value,pseudo_clique_robuste_time = calculer_minorant_b_matching_robuste(data)
        print(io, "$file,")
        @printf(io, "%.4f,%.4f,%.4f,%.4f,%.4f,%.4f\n", 
                combinatorial_lower_bound_value, 
                combinatorial_time, 
                pseudo_clique_statique_value, 
                pseudo_clique_statique_time,
                pseudo_clique_robuste_value,
                pseudo_clique_robuste_time
                )
        flush(io)

    end
end