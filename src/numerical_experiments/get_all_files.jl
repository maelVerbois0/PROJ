module GetFile
    path = "data"
    function get_file(;path_files = path)
        filesname = readdir(path_files)
        filesname = filter(x -> endswith(x, ".tsp"), filesname)
        fichiers_tries = sort(filesname, by = nom -> begin
        parties = split(nom, "_"; limit=2)
        id = parse(Int, parties[1])
        suite = parties[2]
        return (id, suite)
        end)
        return fichiers_tries
    end
    export get_file
end