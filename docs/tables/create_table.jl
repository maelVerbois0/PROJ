using CSV
using DataFrames
using Printf
using Statistics
#-------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------

input_file = "results/logs/resultats_experimentation_static.csv"
file_resume = "docs/tables/tableauStatiqueResume.tex"
file_complet = "docs/tables/tableauStatiqueComplet.tex"

targets = [
    "22_ulysses_3.tsp", "22_ulysses_6.tsp", "22_ulysses_9.tsp",
    "52_berlin_3.tsp", "52_berlin_6.tsp", "52_berlin_9.tsp",
    "318_lin_3.tsp", "318_lin_6.tsp", "318_lin_9.tsp"
]

# --- 2. Chargement des données ---
df = CSV.read(input_file, DataFrame; normalizenames=true)

# --- 3. Préparation des DataFrames ---
# Résumé : Jointure à gauche pour garder l'ordre et les lignes manquantes des cibles
df_targets = DataFrame(Instance = targets)
df_resume = leftjoin(df_targets, df, on = :Instance)

# Complet : Tri naturel (numérique puis alphabétique)
function natural_sort_key(s)
    s_str = string(s)
    m = match(r"^(\d+)_", s_str)
    return m !== nothing ? (parse(Int, m.captures[1]), s_str) : (typemax(Int), s_str)
end
df_complet = sort(df, :Instance, by = natural_sort_key)

# --- 4. Fonction générique d'écriture LaTeX ---
function write_latex_table(filename, dataframe, caption_text)
    open(filename, "w") do io
        println(io, "\\begin{table}[ht]")
        println(io, "\\centering")
        println(io, "\\caption{$caption_text}")
        println(io, "\\small")
        
        # Colonnes : Instance | Objectif | Gap | Temps
        println(io, "\\begin{tabular}{|l|r|r|r|}")
        println(io, "\\hline")
        println(io, "\\textbf{Instance} & \\textbf{Objectif} & \\textbf{Gap (\\%)} & \\textbf{Temps (s)} \\\\")
        println(io, "\\hline")

        for row in eachrow(dataframe)
            # Nom de l'instance
            raw_name = ismissing(row.Instance) ? "Inconnu" : string(row.Instance)
            instance_name = replace(raw_name, "_" => "\\_")

            # Fonction de formatage
            function fmt(val, is_gap=false)
                if ismissing(val) || isnan(val)
                    return "-"
                elseif val == Inf
                    return "\$\\infty\$"
                elseif val == -Inf
                    return "\$-\\infty\$"
                else
                    if is_gap
                        # Gap : x100 et arrondi à l'entier (%.0f)
                        return @sprintf("%.0f", val * 100)
                    else
                        # Autres : 2 décimales
                        return @sprintf("%.2f", val)
                    end
                end
            end

            # Récupération des valeurs
            val_obj  = fmt(row.BestObj)
            val_gap  = fmt(row.Gap, true)
            val_time = fmt(row.Time)

            println(io, "$(instance_name) & $(val_obj) & $(val_gap) & $(val_time) \\\\")
        end

        println(io, "\\hline")
        println(io, "\\end{tabular}")
        println(io, "\\end{table}")
    end
    println("Fichier généré : $filename")
end

# --- 5. Exécution ---
write_latex_table(file_resume, df_resume, "Résultats Statiques (Sélection)")
write_latex_table(file_complet, df_complet, "Résultats Statiques")

#-------------------------------------------------------------------------------------------------
input_file = "results/logs/resultats_experimentation_cutting_plane_naive.csv"
file_resume = "docs/tables/tableauCuttingPlaneResume.tex"
file_complet = "docs/tables/tableauCuttingPlaneComplet.tex"
# --- 2. Chargement des données ---
df = CSV.read(input_file, DataFrame; normalizenames=true)

# --- 3. Préparation des DataFrames ---
# Résumé : Jointure à gauche pour garder l'ordre et les lignes manquantes des cibles
df_targets = DataFrame(Instance = targets)
df_resume = leftjoin(df_targets, df, on = :Instance)
df_complet = sort(df, :Instance, by = natural_sort_key)

write_latex_table(file_complet, df_complet, "Résultats Statiques")
#-----------------------------------------------------------------------------------------------------
input_file = "results/logs/resultats_experimentation_robust_dualisation.csv"
file_resume = "docs/tables/tableauRobustDualisationResume.tex"
file_complet = "docs/tables/tableauRobustDualisationComplet.tex"
# --- 2. Chargement des données ---
df = CSV.read(input_file, DataFrame; normalizenames=true)

# --- 3. Préparation des DataFrames ---
# Résumé : Jointure à gauche pour garder l'ordre et les lignes manquantes des cibles
df_targets = DataFrame(Instance = targets)
df_resume = leftjoin(df_targets, df, on = :Instance)
df_complet = sort(df, :Instance, by = natural_sort_key)

write_latex_table(file_resume, df_resume, "Résultats Dualisation Robuste")
write_latex_table(file_complet, df_complet, "Résultats Dualisation Robuste")
#-------------------------------------------------------------------------------------------
input_file = "results/logs/resultats_experimentation_generation_colonne.csv"
file_resume = "docs/tables/tableauGenerationColonnesResume.tex"
file_complet = "docs/tables/tableauGenerationColonnesComplet.tex"
# --- 2. Chargement des données ---
df = CSV.read(input_file, DataFrame; normalizenames=true)

# --- 3. Préparation des DataFrames ---
# Résumé : Jointure à gauche pour garder l'ordre et les lignes manquantes des cibles
df_targets = DataFrame(Instance = targets)
df_resume = leftjoin(df_targets, df, on = :Instance)
df_complet = sort(df, :Instance, by = natural_sort_key)

write_latex_table(file_resume, df_resume, "Résultats Génération Colonne")
write_latex_table(file_complet, df_complet, "Résultats Génération Colonne")
#----------------------------------------------------------------------------------------------
input_file = "results/logs/resultats_experimentation_branch_n_cut.csv"
file_resume = "docs/tables/tableauBranchnCutResume.tex"
file_complet = "docs/tables/tableauBranchnCutComplet.tex"
# --- 2. Chargement des données ---
df = CSV.read(input_file, DataFrame; normalizenames=true)

# --- 3. Préparation des DataFrames ---
# Résumé : Jointure à gauche pour garder l'ordre et les lignes manquantes des cibles
df_targets = DataFrame(Instance = targets)
df_resume = leftjoin(df_targets, df, on = :Instance)
df_complet = sort(df, :Instance, by = natural_sort_key)

write_latex_table(file_resume, df_resume, "Résultats Branch and Cut (LazyCallBack)")
write_latex_table(file_complet, df_complet, "Résultats Branch and Cut (LazyCallBack)")

#---------------------------------------------------------------------------------------------------------------------------
# --- 1. Configuration ---
input_file = "results/logs/resultats_bornes_inf.csv"
file_resume = "docs/tables/tableau_bornes_resume.tex"
file_complet = "docs/tables/tableau_bornes_complet.tex"

# Liste des instances pour le tableau résumé
targets = [
    "22_ulysses_3.tsp", "22_ulysses_6.tsp", "22_ulysses_9.tsp",
    "52_berlin_3.tsp", "52_berlin_6.tsp", "52_berlin_9.tsp",
    "318_lin_3.tsp", "318_lin_6.tsp", "318_lin_9.tsp"
]

# --- 2. Chargement des données ---
# normalizenames=true gère les espaces dans les noms de colonnes du CSV
df = CSV.read(input_file, DataFrame; normalizenames=true)

# --- 3. Préparation des DataFrames ---
# Résumé : Jointure pour filtrer et ordonner
df_targets = DataFrame(Instance = targets)
df_resume = leftjoin(df_targets, df, on = :Instance)

# Complet : Tri naturel (numérique puis alphabétique)
function natural_sort_key(s)
    s_str = string(s)
    m = match(r"^(\d+)_", s_str)
    return m !== nothing ? (parse(Int, m.captures[1]), s_str) : (typemax(Int), s_str)
end
df_complet = sort(df, :Instance, by = natural_sort_key)

# --- 4. Fonction d'écriture du tableau consolidé ---
function write_consolidated_table(filename, dataframe, caption_text)
    open(filename, "w") do io
        println(io, "\\begin{table}[ht]")
        println(io, "\\centering")
        println(io, "\\caption{$caption_text}")
        println(io, "\\small")
        
        # Structure : Instance | Comb (2) | Stat (2) | Rob (2)
        # On utilise des doubles barres || pour séparer visuellement les méthodes
        println(io, "\\begin{tabular}{|l||r|r||r|r||r|r|}")
        println(io, "\\hline")
        
        # Ligne d'en-tête groupée (Multicolumns)
        println(io, " & \\multicolumn{2}{c||}{\\textbf{Plans Coupants}} & \\multicolumn{2}{c||}{\\textbf{B\\&C Statique}} & \\multicolumn{2}{c|}{\\textbf{Dualisation}} \\\\")
        println(io, "\\cline{2-7}") # Ligne horizontale sous les titres de méthodes uniquement
        
        # Ligne d'en-tête des métriques
        println(io, "\\textbf{Instance} & LB & T(s) & LB & T(s) & LB & T(s) \\\\")
        println(io, "\\hline")

        for row in eachrow(dataframe)
            # Nom de l'instance
            raw_name = ismissing(row.Instance) ? "Inconnu" : string(row.Instance)
            instance_name = replace(raw_name, "_" => "\\_")

            # Fonction de formatage
            function fmt(val)
                if ismissing(val) || isnan(val)
                    return "-"
                elseif val == Inf
                    return "\$\\infty\$"
                elseif val == -Inf
                    return "\$-\\infty\$"
                else
                    return @sprintf("%.2f", val)
                end
            end

            # --- Récupération des données ---
            # Méthode 1 : Combinatoire (Plans Coupants)
            # Noms colonnes selon CSV (normalisés par CSV.jl : espaces retirés, lowercase souvent)
            # Vérifiez les noms exacts avec names(df) si erreur, mais normalizenames aide.
            # Supposons: combinatorial_lower_bound_value, combinatorial_time
            c_lb   = fmt(row.combinatorial_lower_bound_value)
            c_time = fmt(row.combinatorial_time)

            # Méthode 2 : Clique Statique
            s_lb   = fmt(row.pseudo_clique_statique_value)
            s_time = fmt(row.pseudo_clique_statique_time)

            # Méthode 3 : Clique Robuste (Dualisation)
            r_lb   = fmt(row.pseudo_clique_robuste_value)
            r_time = fmt(row.pseudo_clique_robuste_time)

            # Écriture de la ligne
            println(io, "$(instance_name) & $(c_lb) & $(c_time) & $(s_lb) & $(s_time) & $(r_lb) & $(r_time) \\\\")
        end

        println(io, "\\hline")
        println(io, "\\end{tabular}")
        println(io, "\\end{table}")
    end
    println("Fichier généré : $filename")
end

# --- 5. Exécution ---
write_consolidated_table(file_resume, df_resume, "Comparaison des Bornes Inférieures (Sélection)")
write_consolidated_table(file_complet, df_complet, "Comparaison des Bornes Inférieures (Complet)")
#---------------------------------------------------------------------------------------------------------------------
# --- 1. Configuration ---
file_heur = "results/logs/resultats_experimentation_heuristique_robuste.csv"
file_lb   = "results/logs/resultats_bornes_inf.csv"
file_resume = "docs/tables/tableauHeurvsLbResume.tex"
file_complet = "docs/tables/tableauHeurvsLbComplet.tex"

targets = [
    "22_ulysses_3.tsp", "22_ulysses_6.tsp", "22_ulysses_9.tsp",
    "52_berlin_3.tsp", "52_berlin_6.tsp", "52_berlin_9.tsp",
    "318_lin_3.tsp", "318_lin_6.tsp", "318_lin_9.tsp"
]

# --- 2. Lecture et Préparation des données ---
df_heur = CSV.read(file_heur, DataFrame; normalizenames=true)
df_lb   = CSV.read(file_lb, DataFrame; normalizenames=true)

# Sélection et renommage pour clarté avant la fusion
# Heuristique : On a besoin de BestObj et Time
select!(df_heur, :Instance, :BestObj => :Obj_Heur, :Time => :Time_Heur)

# Borne Inf : On a besoin de pseudo_clique_robuste_value et pseudo_clique_robuste_time
# Note : Vérifiez bien les noms si le CSV change, ici je me base sur vos précédents fichiers
select!(df_lb, :Instance, 
        :pseudo_clique_robuste_value => :LB_Rob, 
        :pseudo_clique_robuste_time => :Time_LB)

# Fusion (Jointure externe pour ne rien perdre, mais on filtrera après)
# On utilise outerjoin pour que si une instance manque dans l'un, on l'ait quand même (avec missing)
df_merged = outerjoin(df_heur, df_lb, on = :Instance)

# --- 3. Création des datasets spécifiques ---

# A. Tableau Résumé (Liste imposée)
df_targets = DataFrame(Instance = targets)
df_resume = leftjoin(df_targets, df_merged, on = :Instance)

# B. Tableau Complet (Tri Naturel)
function natural_sort_key(s)
    s_str = string(s)
    m = match(r"^(\d+)_", s_str)
    return m !== nothing ? (parse(Int, m.captures[1]), s_str) : (typemax(Int), s_str)
end
# On enlève les lignes où l'instance est missing (cas rares de jointure)
filter!(row -> !ismissing(row.Instance), df_merged)
df_complet = sort(df_merged, :Instance, by = natural_sort_key)

# --- 4. Fonction d'écriture LaTeX ---
function write_comparison_table(filename, dataframe, caption_text)
    open(filename, "w") do io
        println(io, "\\begin{table}[ht]")
        println(io, "\\centering")
        println(io, "\\caption{$caption_text}")
        println(io, "\\small")
        
        # Colonnes : Instance | Obj (Heur) | Gap (%) | Temps Total
        println(io, "\\begin{tabular}{|l|r|r|r|}")
        println(io, "\\hline")
        println(io, "\\textbf{Instance} & \\textbf{Objectif} & \\textbf{Gap (\\%)} & \\textbf{Temps Total (s)} \\\\")
        println(io, "\\hline")

        for row in eachrow(dataframe)
            # Nom de l'instance
            raw_name = ismissing(row.Instance) ? "Inconnu" : string(row.Instance)
            instance_name = replace(raw_name, "_" => "\\_")

            # Initialisation des variables d'affichage
            str_obj  = "-"
            str_gap  = "-"
            str_time = "-"

            # Vérification de la présence des données
            has_heur = !ismissing(row.Obj_Heur) && !ismissing(row.Time_Heur)
            has_lb   = !ismissing(row.LB_Rob) && !ismissing(row.Time_LB)

            # 1. Objectif (Heuristique)
            if has_heur
                val = row.Obj_Heur
                if val == Inf; str_obj = "\$\\infty\$"
                elseif val == -Inf; str_obj = "\$-\\infty\$"
                else; str_obj = @sprintf("%.2f", val)
                end
            end

            # 2. Temps Total (Heur + LB)
            # Si on a les deux temps, on somme. Sinon, on affiche "-" car le total est inconnu
            if has_heur && has_lb
                total_time = row.Time_Heur + row.Time_LB
                str_time = @sprintf("%.2f", total_time)
            elseif has_heur 
                # Optionnel : Si on veut afficher au moins le temps heuristique quand LB manque
                # str_time = @sprintf("%.2f*", row.Time_Heur) 
                str_time = "-" 
            end

            # 3. Gap Réel (%) = (Heur - LB) / Heur * 100
            # On considère que le Gap n'est calculable que si on a les deux valeurs finies
            if has_heur && has_lb && row.Obj_Heur != Inf && row.LB_Rob != -Inf && row.Obj_Heur != 0
                gap_val = (row.Obj_Heur - row.LB_Rob) / row.Obj_Heur * 100
                # On force gap >= 0 (parfois LB > UB à cause d'erreurs numériques minimes ou heuristic fail)
                # Mais ici on affiche la valeur brute arrondie
                str_gap = @sprintf("%.0f", gap_val)
            end

            println(io, "$(instance_name) & $(str_obj) & $(str_gap) & $(str_time) \\\\")
        end

        println(io, "\\hline")
        println(io, "\\end{tabular}")
        println(io, "\\end{table}")
    end
    println("Fichier généré : $filename")
end

# --- 5. Exécution ---
write_comparison_table(file_resume, df_resume, "Performance Heuristique Robuste vs Borne Pseudo-Clique (Sélection)")
write_comparison_table(file_complet, df_complet, "Performance Heuristique Robuste vs Borne Pseudo-Clique (Complet)")
#--------------------------------------------------------------------------------------------------
using CSV
using DataFrames
using Printf
using Statistics

# --- 1. Configuration des fichiers ---
file_cp   = "results/logs/resultats_experimentation_cutting_plane_naive.csv"
file_bc   = "results/logs/resultats_experimentation_branch_n_cut.csv"
file_dual = "results/logs/resultats_experimentation_robust_dualisation.csv"
file_cg   = "results/logs/resultats_experimentation_generation_colonne.csv"
file_heur = "results/logs/resultats_experimentation_heuristique_robuste.csv"
file_lb   = "results/logs/resultats_bornes_inf.csv"
file_stat = "results/logs/resultats_experimentation_heuristique_statique.csv"

output_resume = "docs/tables/tableauGeneralResume.tex"
output_complet = "docs/tables/tableauGeneralComplet.tex"

targets = [
    "22_ulysses_3.tsp", "22_ulysses_6.tsp", "22_ulysses_9.tsp",
    "52_berlin_3.tsp", "52_berlin_6.tsp", "52_berlin_9.tsp",
    "318_lin_3.tsp", "318_lin_6.tsp", "318_lin_9.tsp"
]

# --- 2. Chargement et Préparation Individuelle ---

# A. Méthodes standards (On garde Gap, Time, BestObj)
df_cp = CSV.read(file_cp, DataFrame; normalizenames=true)
select!(df_cp, :Instance, :Gap => :Gap_CP, :Time => :Time_CP, :BestObj => :Obj_CP)

df_bc = CSV.read(file_bc, DataFrame; normalizenames=true)
select!(df_bc, :Instance, :Gap => :Gap_BC, :Time => :Time_BC, :BestObj => :Obj_BC)

df_dual = CSV.read(file_dual, DataFrame; normalizenames=true)
select!(df_dual, :Instance, :Gap => :Gap_Dual, :Time => :Time_Dual, :BestObj => :Obj_Dual)

df_cg = CSV.read(file_cg, DataFrame; normalizenames=true)
select!(df_cg, :Instance, :Gap => :Gap_CG, :Time => :Time_CG, :BestObj => :Obj_CG)

# B. Heuristique Relaxed Repair (Calcul vs Borne Inf)
df_h_raw = CSV.read(file_heur, DataFrame; normalizenames=true)
df_lb    = CSV.read(file_lb, DataFrame; normalizenames=true)

# On prépare la jointure Heur + LB
rename!(df_h_raw, :BestObj => :Obj_Heur, :Time => :Time_Heur_Only)
rename!(df_lb, :pseudo_clique_robuste_value => :LB_Rob, :pseudo_clique_robuste_time => :Time_LB)

df_heur_comb = innerjoin(df_h_raw, df_lb, on=:Instance)
# On calcule les colonnes finales pour l'heuristique
transform!(df_heur_comb, 
    [:Obj_Heur, :LB_Rob] => ByRow((obj, lb) -> (obj == Inf || lb == -Inf) ? NaN : (obj - lb)/obj) => :Gap_Heur,
    [:Time_Heur_Only, :Time_LB] => ByRow(+) => :Time_Heur
)
select!(df_heur_comb, :Instance, :Gap_Heur, :Time_Heur, :Obj_Heur)

# C. Statique (Pour le prix de la robustesse)
df_stat = CSV.read(file_stat, DataFrame; normalizenames=true)
select!(df_stat, :Instance, :BestObj => :Obj_Stat)

# --- 3. Fusion Globale ---
# On commence par la liste de toutes les instances uniques
all_instances = unique(vcat(df_cp.Instance, df_stat.Instance))
df_master = DataFrame(Instance = all_instances)

# On joint tout (leftjoin pour ne rien perdre si une méthode a échoué totalement)
df_master = leftjoin(df_master, df_stat, on=:Instance)
df_master = leftjoin(df_master, df_cp, on=:Instance)
df_master = leftjoin(df_master, df_bc, on=:Instance)
df_master = leftjoin(df_master, df_dual, on=:Instance)
df_master = leftjoin(df_master, df_cg, on=:Instance)
df_master = leftjoin(df_master, df_heur_comb, on=:Instance)

# --- 4. Calcul du Prix de la Robustesse (PoR) ---
function calc_por(row)
    # 1. Trouver le meilleur objectif robuste parmi toutes les méthodes
    objs = [row.Obj_CP, row.Obj_BC, row.Obj_Dual, row.Obj_CG, row.Obj_Heur]
    # Filtrer les missing, les Inf et les NaN
    valid_objs = filter(x -> !ismissing(x) && !isnan(x) && x != Inf && x != -Inf, objs)
    
    if isempty(valid_objs) || ismissing(row.Obj_Stat) || row.Obj_Stat == 0
        return missing
    else
        best_rob = minimum(valid_objs)
        # PoR = (Robust - Static) / Static
        return (best_rob - row.Obj_Stat) / best_rob
    end
end

transform!(df_master, AsTable(:) => ByRow(calc_por) => :PoR)

# --- 5. Préparation des sorties (Tri et Filtrage) ---

# Fonction de tri
function natural_sort_key(s)
    s_str = string(s)
    m = match(r"^(\d+)_", s_str)
    return m !== nothing ? (parse(Int, m.captures[1]), s_str) : (typemax(Int), s_str)
end

# Nettoyage
filter!(row -> !ismissing(row.Instance), df_master)

# Dataset Complet
df_complet = sort(df_master, :Instance, by = natural_sort_key)

# Dataset Résumé
df_targets = DataFrame(Instance = targets)
df_resume = leftjoin(df_targets, df_master, on=:Instance)

# --- 6. Génération LaTeX ---

function write_big_table(filename, dataframe, caption_text)
    open(filename, "w") do io
        # On utilise sidewaystable si le tableau est très large, mais ici on tente table standard + scriptsize
        println(io, "\\begin{table}[ht]")
        println(io, "\\centering")
        println(io, "\\caption{$caption_text}")
        # On réduit la police car il y a beaucoup de colonnes
        println(io, "\\scriptsize") 
        println(io, "\\setlength{\\tabcolsep}{3pt}") # Réduit l'espace entre colonnes
        
        # Structure : Instance | PoR || CP(Gap,T) | BC(Gap,T) | Dual(Gap,T) | CG(Gap,T) | Heur(Gap,T)
        # 1 + 1 + 2 + 2 + 2 + 2 + 2 = 12 colonnes
        println(io, "\\begin{tabular}{|l|c||cc|cc|cc|cc|cc|}")
        println(io, "\\hline")
        
        # En-têtes Supérieurs
        println(io, " & \\textbf{PoR} & \\multicolumn{2}{c|}{\\textbf{Plans Coup.}} & \\multicolumn{2}{c|}{\\textbf{Branch \\& Cut}} & \\multicolumn{2}{c|}{\\textbf{Dualisation}} & \\multicolumn{2}{c|}{\\textbf{Gén. Col.}} & \\multicolumn{2}{c|}{\\textbf{Heuristique}} \\\\")
        
        # En-têtes Inférieurs
        println(io, "\\textbf{Instance} & (\\%) & Gap & T(s) & Gap & T(s) & Gap & T(s) & Gap & T(s) & Gap & T(s) \\\\")
        println(io, "\\hline")

        for row in eachrow(dataframe)
            # Nom
            raw_name = ismissing(row.Instance) ? "Inconnu" : string(row.Instance)
            inst = replace(raw_name, "_" => "\\_")
            
            # Formatteurs
            fmt_gap(val) = (ismissing(val) || isnan(val) || val==Inf) ? "-" : @sprintf("%.0f", val * 100)
            fmt_time(val) = (ismissing(val) || isnan(val)) ? "-" : @sprintf("%.1f", val) # 1 décimale pour gagner place
            
            # PoR
            por_val = fmt_gap(row.PoR)

            # Méthodes
            # CP
            cp_g = fmt_gap(row.Gap_CP)
            cp_t = fmt_time(row.Time_CP)
            # BC
            bc_g = fmt_gap(row.Gap_BC)
            bc_t = fmt_time(row.Time_BC)
            # Dual
            du_g = fmt_gap(row.Gap_Dual)
            du_t = fmt_time(row.Time_Dual)
            # CG
            cg_g = fmt_gap(row.Gap_CG)
            cg_t = fmt_time(row.Time_CG)
            # Heur
            he_g = fmt_gap(row.Gap_Heur)
            he_t = fmt_time(row.Time_Heur)

            println(io, "$inst & $por_val & $cp_g & $cp_t & $bc_g & $bc_t & $du_g & $du_t & $cg_g & $cg_t & $he_g & $he_t \\\\")
        end

        println(io, "\\hline")
        println(io, "\\end{tabular}")
        println(io, "\\end{table}")
    end
    println("Fichier généré : $filename")
end

write_big_table(output_resume, df_resume, "Comparaison Globale des Méthodes (Résumé)")
write_big_table(output_complet, df_complet, "Comparaison Globale des Méthodes (Complet)")