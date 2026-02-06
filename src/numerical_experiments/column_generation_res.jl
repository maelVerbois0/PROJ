include("../IntegratedSolver.jl")
include("get_all_files.jl")
using Gurobi, Printf
using .Solver
using .GetFile

data = load_instance("data/10_ulysses_3.tsp")
column_generation_heuristic(data)
filenames = get_file()
fichier_resultats = "results/logs/resultats_experimentation_generation_colonne.csv"
const_env=Gurobi.Env()
open(fichier_resultats, "w") do io
    println(io, "Instance,Status,BestObj,BestBound,Gap,Time,SolutionSize")
    for file in filenames
        println("Traitement de : $file ...") # Juste pour suivre dans la console
        data = load_instance("data/$(file)")
        res = column_generation_heuristic(data, time_limit = 300.,env = const_env)
        print(io, "$file,$(res.termination_status),")
        @printf(io, "%.4f,%.4f,%.4f,%.4f,%d\n", 
                res.best_obj, 
                res.best_lwbd, 
                res.gap, 
                res.total_time,
                length(res.incumbent_solution))
        flush(io)
        println("   -> Résultat : $res")
        if res.termination_status != "NOTFOUND"
            plot_result(data, res, String(split(file, ".")[1]), save_path = "results/figs/generation_colonnes/$(String(split(file, ".")[1]))")
        end
    end
end

println("Terminé ! Les résultats sont dans $fichier_resultats")

