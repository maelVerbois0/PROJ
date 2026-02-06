
"""
plot_result(data, result, instance_name; save_path="")

Visualizes the solution stored in ResultatAlgorithme.
- Uses `scatter` for high performance (removing edges/labels).
- Title formatted with Printf to show Instance, Objective, and Gap.
- Automatically groups colors based on `result.incumbent_solution`.
"""
function plot_result(data::ProblemData, res::ResultatAlgorithme, instance_name::String; save_path::String="")

    # 1. Format the title using @sprintf for clean precision
    # Assumes gap is a relative float (e.g., 0.05 for 5%). 
    # If gap is a percentage (e.g., 5.0), remove the `* 100`.
    title_str = @sprintf(
        "%s\nObj: %.2f  |  Gap: %.2f%%", 
        instance_name, 
        res.best_obj, 
        res.gap * 100
    )

    # 2. Extract coordinates
    xs = data.coordinates[:, 1]
    ys = data.coordinates[:, 2]

    # 3. Create the Scatter Plot
    # We access the partition map via `res.incumbent_solution`
    p = scatter(
        xs, ys,
        group = res.incumbent_solution, # Groups nodes by color based on solution
        title = title_str,
        
        # Visual Styling
        markersize = 5,
        markerstrokewidth = 0.5,
        markerstrokecolor = :black,
        palette = :Set1,
        
        # Clean layout (removing axis, legends, grids)
        legend = false,
        grid = false,
        axis = nothing,
        border = :none,
        aspect_ratio = :equal
    )

    # 4. Save if path is provided
    if !isempty(save_path)
        savefig(p, save_path)
        println("Plot saved to: $save_path")
        return
    end

    # 5. Display
    display(p)
    return
end