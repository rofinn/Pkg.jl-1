import UUIDs
import LibGit2
import Pkg3: TOML, Types.SHA1, Operations
using Pkg3.Types

function write_toml(f::Function, names::String...)
    path = joinpath(names...) * ".toml"
    mkpath(dirname(path))
    open(path, "w") do io
        f(io)
    end
end

function create_registry(path; repo = nothing, uuid = UUIDs.uuid1(), description = "")
    isdir(path) && error("$(abspath(path)) already exists")
    mkpath(path)
    write_mainfile(path, uuid, repo, description)
    LibGit2.init(path)
end

function write_mainfile(path, uuid, repo, description)
    open(joinpath(path, "Registry.toml"), "w") do io
        println(io, "name = ", repr(basename(path)))
        println(io, "uuid = ", repr(string(uuid)))
        if repo !== nothing
            println(io, "repo = ", repr(repo))
        end
        println(io)

        if !isempty(description)
            println(io, """
            description = \"\"\"
            $description
            \"\"\"

            """
            )
        end

        println(io, "[packages]")
    end
end

Base.@kwdef struct Package
    path::String = ""
    git_tree_sha::Union{Nothing, String} = ""
    repo::String = ""
end

register_package(registry::String, pkg_path::Package) = register_package(registry, [pkg_path])
function register_package(registry::String, pkgs::Vector{Package})
    # read the registry
    !isdir(registry) && error(abspath(registry), " does not exist")
    registry_main_file = joinpath(registry, "Registry.toml")
    !isfile(registry_main_file) && error(abspath(registry_main_file), " does not exist")
    registry_data = TOML.parsefile(joinpath(registry, "Registry.toml"))

    registry_packages = registry_data["packages"]
    # if find uuid, already registred, bail...
    for pkg in pkgs
        pkg_path = pkg.path
        !isdir(pkg_path) && error("$(abspath(pkg_path)) does not exist")
        projectfile = joinpath(pkg_path, "Project.toml")
        !isfile(projectfile) && error("package at $(abspath(pkg_path)) did not contain a Project.toml file")
        project_data = TOML.parsefile(projectfile)

        name = project_data["name"]
        uuid = project_data["uuid"]
        vers = project_data["version"]
        deps = get(project_data, "deps", Dict())
        repo = get(project_data, "repo", nothing)

        bin = string(first(name))
        if haskey(registry_packages, uuid)
            reldir = register_package[uuid]["path"]
        else
            binpath = joinpath(registry, bin)
            mkpath(binpath)
            # store the package in $name__$i where i is the no. of pkgs with the same name
            # unless i == 0, then store in $name
            candidates = filter(x -> startswith(x, name), readdir(binpath))
            r = Regex("$name(__)?[0-9]*?\$")
            offset = count(x -> contains(x, r), candidates)
            if offset == 0
                reldir = joinpath(string(first(name)), name)
            else
                reldir = joinpath(string(first(name)), "$(name)__$(offset+1)")
            end
        end

        registry_packages[uuid] = Dict("name" => name, "path" => reldir)

        pkg_registry_path = joinpath(registry, reldir)
        mkpath(pkg_registry_path)
        for f in ("Versions.toml", "Deps.toml", "Compat.toml")
            isfile(joinpath(pkg_registry_path, f)) || touch(joinpath(pkg_registry_path, f))
        end

        version_info = Operations.load_versions(pkg_registry_path)
        versions = sort!(collect(keys(version_info)))
        deps_data = Operations.load_package_data_raw(UUID, joinpath(pkg_registry_path, "Deps.toml"))
        compat_data = Operations.load_package_data_raw(VersionSpec, joinpath(pkg_registry_path, "Compat.toml"))

        # Package.toml
        write_toml(joinpath(pkg_registry_path, "Package")) do io
            println(io, "name = ", repr(name))
            println(io, "uuid = ", repr(uuid))
            if pkg.repo !== nothing
                println(io, "repo = ", repr(pkg.repo))
            end
        end

        # Versions.toml
        versionfile = joinpath(pkg_registry_path, "Versions.toml")
        isfile(versionfile) || touch(versionfile)
        versiondata = TOML.parsefile(versionfile)

        write_toml(joinpath(pkg_registry_path, "Versions")) do io
            println(io, "[\"$vers\"]")
            println(io, "git-tree-sha1 = ", repr(pkg.git_tree_sha))
        end
    end

    write_mainfile(registry, registry_data["uuid"], registry_data["name"],  get(registry_data, "description", ""))

    # Write back the stuff to the registry...
    open(joinpath(registry, "Registry.toml"), "a") do io
        for (uuid, data) in registry_packages
            println(io, uuid, " = { name = ", repr(data["name"]), ", path = ", repr(data["path"]), " }")
        end
    end
end




