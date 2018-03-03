module RegistryTest

using Test
import Pkg3
import LibGit2

const DEBUG_MODE = false

DEBUG_MODE && rm("test_depot"; force = true, recursive = true)
DEBUG_MODE && rm("test_package_dir"; force = true, recursive = true)
tmp_depot  = DEBUG_MODE ? "test_depot"       : mktempdir()
tmp_pkgdir = DEBUG_MODE ? "test_package_dir" : mktempdir()
pkg_name = "Foo"
mkpath(tmp_pkgdir)

# Set up a depot containing a registry
mkpath(joinpath(tmp_depot, "registries"))
test_registry = joinpath(tmp_depot, "registries", "TestRegistry")
Pkg3.Registry.create_registry(test_registry)

cd(tmp_pkgdir) do
    Pkg3.create(pkg_name)
end
pkg_dir = joinpath(tmp_pkgdir, pkg_name)

# Move into register_package?
repo = LibGit2.GitRepo(pkg_dir)
git_commit = LibGit2.GitObject(repo, "HEAD")
git_tree = LibGit2.peel(LibGit2.GitTree, git_commit)
@assert git_tree isa LibGit2.GitTree
git_tree_hash = string(LibGit2.GitHash(git_tree))

pkg = Pkg3.Registry.Package(path = pkg_dir, git_tree_sha = git_tree_hash, repo = abspath(pkg_dir))
Pkg3.Registry.register_package(test_registry, pkg)

pkg_registry_dir = joinpath(test_registry, string(first(pkg_name)),  pkg_name)
@test isdir(pkg_registry_dir)
for f in ("Compat.toml", "Deps.toml", "Versions.toml", "Package.toml")
    @test isfile(joinpath(pkg_registry_dir, f))
end

old_depot = copy(DEPOT_PATH)
empty!(DEPOT_PATH)
push!(DEPOT_PATH, abspath(tmp_depot))
mktempdir() do tmp
    cd(tmp) do
        Pkg3.init()
        Pkg3.add(pkg_name)
        @eval using $(Symbol(pkg_name))
    end
end
empty!(DEPOT_PATH)
append!(DEPOT_PATH, old_depot)

rm(tmp_depot; recursive = true)
rm(tmp_pkgdir; recursive = true)

end