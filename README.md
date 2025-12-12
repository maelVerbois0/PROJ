# Projet de Partitionnement Robuste - MPRO 2025-2026

**Cours :** MPRO  
**Encadrants :** Zacharie ALES, Daniel PORUMBEL  

## Auteurs
*Ce fichier doit être édité par chaque membre du binôme.*

* **[Nom Prénom Étudiant 1]**
* **[Nom Prénom Étudiant 2]**

## Description du Projet
[cite_start]Ce projet a pour but l'étude et la résolution d'un problème de partitionnement robuste[cite: 4]. [cite_start]L'objectif est de partitionner les sommets d'un graphe $G=(V,E)$ en au plus $K$ parties de poids inférieur à $B$, tout en minimisant le poids des arêtes à l'intérieur des parties. 

[cite_start]Nous considérons une version robuste du problème prenant en compte des incertitudes sur les distances (paramètre $L$) et sur les poids des sommets (paramètres $W_D$ et $W$)[cite: 27, 33].

## Méthodes de Résolution
Le projet implémente plusieurs approches pour résoudre ce problème :

1.  [cite_start]**Algorithme de plans coupants** (Cutting Planes)[cite: 5].
2.  [cite_start]**Branch-and-Cut** (via LazyCallback)[cite: 6].
3.  [cite_start]**Dualisation** du problème robuste[cite: 7].
4.  [cite_start]**Heuristique** avec garantie de performance (ou formulation non compacte)[cite: 8, 86].

## Structure du Dépôt
* `/src` : Code source des algorithmes (C++/Python/Julia).
* `/data` : Instances de test.
* `/docs` : Rapports et modélisations (LaTeX/PDF).
* `/results` : Tableaux et graphiques de performance.

## Échéancier
Les dates clés du projet sont les suivantes :

* [cite_start]**Création du dépôt Git :** Avant le 15 décembre.
* [cite_start]**Rendu de la modélisation papier :** 21 décembre[cite: 104].
* [cite_start]**Rendu du rapport final :** 6 février[cite: 107].
* [cite_start]**Soutenances :** 10 février[cite: 110].

---