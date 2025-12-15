# Projet de Partitionnement Robuste - MPRO 2025-2026

**Cours :** MPRO  
**Encadrants :** Zacharie ALES, Daniel PORUMBEL  

## Auteur

* **Maël VERBOIS**


## Description du Projet
Ce projet a pour but l'étude et la résolution d'un problème de partitionnement robuste. L'objectif est de partitionner les sommets d'un graphe $G=(V,E)$ en au plus $K$ parties de poids inférieur à $B$, tout en minimisant le poids des arêtes à l'intérieur des parties. 

Nous considérons une version robuste du problème prenant en compte des incertitudes sur les distances (paramètre $L$) et sur les poids des sommets (paramètres $W_D$ et $W$).

## Méthodes de Résolution
Le projet implémente plusieurs approches pour résoudre ce problème :

1.  **Algorithme de plans coupants** (Cutting Planes).
2.  **Branch-and-Cut** (via LazyCallback).
3.  **Dualisation** du problème robuste-.
4.  **Heuristique** avec garantie de performance (ou formulation non compacte).

## Structure du Dépôt
* `/src` : Code source des algorithmes (Julia).
* `/data` : Instances de test.
* `/docs` : Rapports et modélisations (LaTeX/PDF).
* `/results` : Tableaux et graphiques de performance.

## Échéances
Les dates clés du projet sont les suivantes :

* **Création du dépôt Git :** Avant le 15 décembre.
* **Rendu de la modélisation papier :** 21 décembre.
* **Rendu du rapport final :** 6 février.
* **Soutenances :** 10 février.

---