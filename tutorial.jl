# Tutoriel rapide afin de charger des instances 
# appliquer les différentes méthodes
# et afficher les résulats
include("src/IntegratedSolver.jl")
using .Solver


#Pour charger une instance on précise le path 
data = load_instance("data/22_ulysses_6.tsp")
#On peut ensuite appliquer les différentes méthodes 
res = heuristic_relaxed_repair_robust(data)
#On peut plot les résultats sur un graphe
plot_result(data, res, "22_ulysses_6")
#Vérifier qu'une solution est valide (pour le statique ou le robuste)
is_feasible_static(data, res)
is_feasible_robust(data, res)
#Calculer la valeur statique ou robuste de la solution
calculate_objective_static(data, res)
calculate_objective_robust(data, res)