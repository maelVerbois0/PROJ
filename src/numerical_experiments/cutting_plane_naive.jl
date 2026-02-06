include("../IntegratedSolver.jl")
include("get_all_files.jl")
using Gurobi, Printf
using .Solver
using .GetFile


data = load_instance("data/10_ulysses_3.tsp")
solve_robust_cutting_plane_naive(data, time_limit = 1.)
filenames = get_file()
fichier_resultats = "results/logs/resultats_experimentation_cutting_plane_naive.csv"
const_env=Gurobi.Env()
open(fichier_resultats, "w") do io
    println(io, "Instance,Status,BestObj,BestBound,Gap,Time,SolutionSize")
    for file in filenames
        println("Traitement de : $file ...") # Juste pour suivre dans la console
        data = load_instance("data/$(file)")
        res = solve_robust_cutting_plane_naive(data, time_limit = 1.,env = const_env)
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
            plot_result(data, res, String(split(file, ".")[1]), save_path = "results/figs/cutting_plane_naive/$(String(split(file, ".")[1]))")
        end 
    end
end

println("Terminé ! Les résultats sont dans $fichier_resultats")

