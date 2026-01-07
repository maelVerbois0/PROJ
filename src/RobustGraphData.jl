module RobustGraphData

using LinearAlgebra

export ProblemData, load_instance

"""
    ProblemData

A struct to hold all necessary parameters for the robust partitioning models.
"""
struct ProblemData
    # Scalars
    n::Int              # Number of vertices
    K::Int              # Number of partitions
    B::Float64          # Capacity limit per partition
    L::Float64          # Total budget for distance uncertainty (U1)
    W::Float64          # Total budget for weight uncertainty (U2)

    # Vectors
    w_nominal::Vector{Float64}   # Nominal weights (w_v)
    w_deviation::Vector{Float64} # Max weight deviation (W_v)
    l_params::Vector{Float64}    # Distance uncertainty parameters (lh / l_hat)

    # Computed Data
    distances::Matrix{Float64}   # Nominal distance matrix l_ij (calculated from coordinates)
end

"""
    parse_custom_file(filename)

Parses the custom data format into a raw Dictionary.
"""
function parse_custom_file(filename)
    data = Dict{String, Any}()
    
    open(filename, "r") do io
        lines = readlines(io)
        current_array_name = ""
        array_buffer = String[]
        is_multiline_matrix = false

        for line in lines
            line = strip(line)
            if isempty(line) continue end

            # 1. Handle Scalars (e.g., n = 10)
            if occursin(r"^\w+\s*=\s*[\d\.]+$", line)
                parts = split(line, "=")
                key = strip(parts[1])
                val = parse(Float64, strip(parts[2]))
                data[key] = isinteger(val) ? Int(val) : val

            # 2. Handle Single-line Vectors (e.g., w_v = [4, 14, ...])
            elseif occursin(r"^\w+\s*=\s*\[.*\]$", line)
                parts = split(line, "=")
                key = strip(parts[1])
                content = match(r"\[(.*)\]", parts[2]).captures[1]
                vals = parse.(Float64, split(content, ","))
                data[key] = all(isinteger.(vals)) ? Int.(vals) : vals

            # 3. Handle Start of Multi-line Matrix (e.g., coordinates = [ )
            elseif occursin(r"^\w+\s*=\s*\[\s*$", line)
                current_array_name = strip(split(line, "=")[1])
                is_multiline_matrix = true
                array_buffer = []

            # 4. Handle Matrix Rows and Closing Bracket
            elseif is_multiline_matrix
                if contains(line, "]")
                    clean_line = replace(line, "]" => "")
                    if !isempty(strip(clean_line))
                        push!(array_buffer, clean_line)
                    end
                    
                    rows = [parse.(Float64, split(row, ";")[1] |> split) for row in array_buffer if !isempty(strip(row))]
                    data[current_array_name] = hcat(rows...)' |> Matrix
                    
                    is_multiline_matrix = false
                else
                    push!(array_buffer, line)
                end
            end
        end
    end
    return data
end

"""
    load_instance(filename::String)

Reads the file and returns a structured ProblemData object ready for optimization.
"""
function load_instance(filename::String)
    raw = parse_custom_file(filename)

    # 1. Extract Scalars
    n = raw["n"]
    K = raw["K"]
    B = Float64(raw["B"])
    L = Float64(raw["L"])
    W = Float64(raw["W"])

    # 2. Extract Vectors
    # Ensure they are Float64 for safety in math operations
    w_v = Float64.(raw["w_v"])
    W_v = Float64.(raw["W_v"])
    lh  = Float64.(raw["lh"])

    # 3. Compute Distance Matrix from Coordinates
    coords = raw["coordinates"]
    dist_matrix = zeros(Float64, n, n)
    
    for i in 1:n
        for j in 1:n
            if i != j
                # Euclidean distance between row i and row j of coordinates
                dist_matrix[i, j] = norm(coords[i, :] - coords[j, :])
            end
        end
    end

    return ProblemData(n, K, B, L, W, w_v, W_v, lh, dist_matrix)
end

end 