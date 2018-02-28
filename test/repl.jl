module TestPkg3REPL

using Pkg3
using Test
import REPL
struct MiniTerminal
    err_stream::IO
end
struct MiniREPL <: REPL.AbstractREPL
    display::TextDisplay
    t::MiniTerminal
end
function MiniREPL()
    MiniREPL(TextDisplay(stdout), MiniTerminal(stderr))
end

REPL.REPLDisplay(repl::MiniREPL) = repl.display

const minirepl = MiniREPL()

macro pkg_str(str::String)
    :(Pkg3.REPLMode.do_cmd(minirepl, $str))
end

project_path = mktempdir()

cd(project_path) do
    push!(LOAD_PATH, Base.parse_load_path("@"))
    try
        pkg"create HelloWorld"
        cd("HelloWorld")
        pkg"st"
        @eval using HelloWorld
        Base.invokelatest(HelloWorld.greet)
        @test isfile("Project.toml")
    finally
        pop!(LOAD_PATH)
    end
end

end