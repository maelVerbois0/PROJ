using CSV
using DataFrames
using Printf

# --- 1. Configuration ---
# On utilise le fichier statique pour avoir la liste des instances
input_file = "results/logs/resultats_experimentation_static.csv"
output_file = "docs/figures/annexe_visualisations.tex"

# Chemins relatifs vers les images (tels qu'ils seront vus par le fichier .tex principal)
path_stat = "../results/figs/heuristique_statique/"
path_rob  = "../results/figs/heuristique_robuste/"

# --- 2. Lecture et Tri ---
df = CSV.read(input_file, DataFrame; normalizenames=true)

# Fonction de tri naturel
function natural_sort_key(s)
    s_str = string(s)
    m = match(r"^(\d+)_", s_str)
    return m !== nothing ? (parse(Int, m.captures[1]), s_str) : (typemax(Int), s_str)
end

# On ne garde que les noms d'instances uniques et on trie
unique_instances = unique(df.Instance)
sort!(unique_instances, by = natural_sort_key)

# --- 3. Génération du code LaTeX ---
open(output_file, "w") do io
    println(io, "\\section{Visualisation des Solutions : Statique vs Robuste}")
    println(io, "Les figures suivantes comparent la solution de l'heuristique statique (gauche) et celle de l'heuristique robuste (droite) pour chaque instance.")
    println(io, "")

    count = 0
    
    for instance_file in unique_instances
        if ismissing(instance_file) continue end
        
        # Nom de fichier image : on retire l'extension .tsp si elle existe
        # Ex: "10_ulysses_3.tsp" -> "10_ulysses_3"
        image_name = replace(string(instance_file), ".tsp" => "")
        
        # Nom pour l'affichage (échappement des underscores)
        display_name = replace(image_name, "_" => "\\_")

        # Construction de la figure
        println(io, "\\begin{figure}[H]")
        println(io, "    \\centering")
        
        # --- Image Statique ---
        println(io, "    \\begin{subfigure}[b]{0.48\\textwidth}")
        println(io, "        \\centering")
        # On utilise \includegraphics avec le chemin construit
        println(io, "        \\includegraphics[width=\\linewidth]{$(path_stat)$(image_name).png}")
        println(io, "        \\caption{Statique}")
        println(io, "    \\end{subfigure}")
        println(io, "    \\hfill") # Espace entre les deux
        
        # --- Image Robuste ---
        println(io, "    \\begin{subfigure}[b]{0.48\\textwidth}")
        println(io, "        \\centering")
        println(io, "        \\includegraphics[width=\\linewidth]{$(path_rob)$(image_name).png}")
        println(io, "        \\caption{Robuste}")
        println(io, "    \\end{subfigure}")
        
        println(io, "    \\caption{Instance : $(display_name)}")
        println(io, "\\end{figure}")
        
        println(io, "") # Ligne vide

        # --- Gestion des sauts de page ---
        # Toutes les 3 figures, on force une nouvelle page pour éviter de saturer LaTeX
        count += 1
        if count % 3 == 0
            println(io, "\\clearpage")
        end
    end
end

println("Fichier généré : $output_file")