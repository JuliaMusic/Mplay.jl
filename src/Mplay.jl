module Mplay

include("midi.jl")
include("smf.jl")
include("keys.jl")

using .midi
using .smf
using .keys

include("player.jl")
include("gui.jl")
include("tui.jl")

function __init__()
    if Sys.KERNEL == :NT
        lib = joinpath(@__DIR__, "lib")
        midi = joinpath(lib, "libmidi.dll")
        isfile(midi) && chmod(midi, 0o755)
    end
end

function frontend_api()
    return (
        play=play,
        partinfo=partinfo,
        getprogram=getprogram,
        fileinfo=fileinfo,
        songinfo=songinfo,
        chordinfo=chordinfo,
        beatinfo=beatinfo,
        cpuload=cpuload,
        dispatch=dispatch,
        setsong=setsong,
        setpart=setpart,
        change_mute_state=change_mute_state,
        change_solo_state=change_solo_state,
        allsoundoff=allsoundoff,
        setkorgmode=setkorgmode,
    )
end

"""
    mplay(path, device=""; frontend=:tui, opts=String[])

Play a MIDI file using the requested frontend. `:tui` is the default;
use `frontend=:gui` for the GLFW/OpenGL interface.
"""
function apply_options!(player, opts, api=frontend_api())
    transpose = false
    for opt in opts
        if transpose
            player.midi.key_shift = parse(Int, opt)
            transpose = false
        elseif opt == "--korg"
            api.setkorgmode()
        elseif opt == "-t"
            transpose = true
        elseif match(r"[-][bdg\d]", opt) !== nothing
            for key in opt[2:end]
                api.dispatch(player, key)
            end
        else
            println("unknown option: $opt")
        end
    end
    transpose && throw(ArgumentError("-t requires a transpose value"))
    return player
end

function run_player(player, device, frontend, api; opts=String[])
    apply_options!(player, opts, api)
    if frontend == :tui
        TUI.run(player, device, api)
    elseif frontend == :gui
        GUI.run(player, device, api)
    else
        throw(ArgumentError("unknown frontend: $frontend (expected :tui or :gui)"))
    end
end

function run_path(path, device, frontend, api; opts=String[])
    if isdir(path)
        frontend == :tui ||
            throw(ArgumentError("the GUI frontend requires a MIDI file, not a directory"))
        while true
            file, dialog_opts = TUI.select_file(path)
            file === nothing && break
            isempty(file) && continue
            run_player(MidiPlayer(file), device, frontend, api; opts=dialog_opts)
        end
    else
        run_player(MidiPlayer(path), device, frontend, api; opts=opts)
    end
    return nothing
end

function mplay(path, device=""; frontend=:tui, opts=String[])
    api = frontend_api()
    run_path(path, device, frontend, api; opts=opts)
end

export mplay

function print_help(io=stdout)
    println(io, "Usage: julia Mplay.jl [--tui|--gui] [--device=DEVICE] [options] MIDI_FILE")
    println(io)
    println(io, "Frontends:")
    println(io, "  --tui              terminal interface (default)")
    println(io, "  --gui              GLFW/OpenGL graphical interface")
    println(io)
    println(io, "Other options:")
    println(io, "  --device=DEVICE    MIDI output device (or set MIDI_DEVICE)")
    println(io, "  -h, --help         show this help")
    println(io)
    println(io, "Examples:")
    println(io, "  julia Mplay.jl song.mid")
    println(io, "  julia Mplay.jl --tui song.mid")
    println(io, "  julia Mplay.jl --gui song.mid")
    println(io, "  julia Mplay.jl --gui --device=\"My MIDI Device\" song.mid")
end

function parse_args(args)
    frontend = :tui
    device = get(ENV, "MIDI_DEVICE", "")
    path = nothing
    opts = String[]

    i = 1
    while i <= length(args)
        arg = args[i]
        if arg == "--tui"
            frontend = :tui
        elseif arg == "--gui"
            frontend = :gui
        elseif arg in ("-h", "--help")
            return (; help=true, frontend, device, path, opts)
        elseif startswith(arg, "--device=")
            device = split(arg, "=", limit=2)[2]
        elseif arg == "--device"
            i == length(args) && throw(ArgumentError("--device requires a value"))
            i += 1
            device = args[i]
        elseif arg == "-t" && path === nothing
            i == length(args) && throw(ArgumentError("-t requires a transpose value"))
            push!(opts, arg)
            i += 1
            push!(opts, args[i])
        elseif startswith(arg, "-") && path === nothing
            push!(opts, arg)
        elseif path === nothing
            path = arg
        else
            push!(opts, arg)
        end
        i += 1
    end

    return (; help=false, frontend, device, path, opts)
end

function main(args=ARGS)
    parsed = try
        parse_args(args)
    catch err
        println(stderr, "mplay: ", err)
        print_help(stderr)
        return 2
    end

    if parsed.help
        print_help()
        return 0
    end

    path = parsed.path === nothing ? "." : parsed.path
    try
        mplay(path, parsed.device; frontend=parsed.frontend, opts=parsed.opts)
        return 0
    catch err
        println(stderr, "mplay: ", err)
        return 1
    end
end

function julia_main()::Cint
    return Cint(main())
end

if abspath(PROGRAM_FILE) == @__FILE__
    exit(main())
end

end # module Mplay
