using Plots
using GraphRecipes

"""
    plot_partition_result(data, partition_map, objective_value)

Visualizes the graph partition solution.
- Nodes are colored by their partition.
- Node labels show "Index (Weight)".
- Title shows the total objective value.
"""
function plot_partition_result(data::ProblemData, partition_map::Dict{Int, Int}, objective_value::Float64)
    # 1. Prepare Plotting Data
    # Sort partitions into a vector for 1..n
    node_groups = [partition_map[i] for i in 1:data.n]
    
    # Create labels: "Index \n (Weight)"
    # We use the nominal weights w_v, rounded to 1 decimal place
    node_labels = [string(i, "\n(", round(data.w_nominal[i], digits=1), ")") for i in 1:data.n]

    # Extract X and Y coordinates
    xs = data.coordinates[:, 1]
    ys = data.coordinates[:, 2]

    # 2. Setup colors
    # We can rely on Plots default palette or define specific colors
    theme(:default)

    # 3. Create the Plot
    # We use a matrix of ones for adjacency to simulate a complete graph, 
    # but strictly relies on x,y for positioning.
    # To reduce visual clutter, we can set linealpha low.
    adj_matrix = ones(data.n, data.n) - I # Complete graph without self-loops

    p = graphplot(adj_matrix,
        x = xs,
        y = ys,
        names = node_labels,
        nodecolor = node_groups,      # Color nodes by partition group
        nodeshape = :circle,
        nodesize = 0.25,              # Adjust node size
        fontsize = 10,
        linecolor = :gray,
        linealpha = 0.3,              # Faint edges to emphasize nodes
        linewidth = 1.0,
        markerstrokewidth = 1,        # Border around nodes
        color_palette = :Set1         # Distinct colors for partitions
    )

    # Add title with the cost
    title!("Total Partition Cost: $(round(objective_value, digits=2))")

    display(p)
end