include("../IntegratedSolver.jl")
include("get_all_files.jl")
using Gurobi, Printf
using .Solver
using .GetFile

filenames = get_file()
const_env = Gurobi.Env()

data =load_instance("data/10_ulysses_3.tsp")
solve_static_problem_mip(data, env = const_env)

fichier_resultats = "results/resultats_experimentation_static.csv"
open(fichier_resultats, "w") do io
    println(io, "Instance,Status,BestObj,BestBound,Gap,Time,SolutionSize")
    for file in filenames
        println("Traitement de : $file ...") # Juste pour suivre dans la console
        data = load_instance("data/$(file)")
        res = solve_static_problem_mip(data, time_limit = 300., env=const_env)
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
            plot_result(data, res, String(split(file, ".")[1]), save_path = "results/figs/static/$(String(split(file, ".")[1]))")
        end
    end
end

println("Terminé ! Les résultats sont dans $fichier_resultats")

