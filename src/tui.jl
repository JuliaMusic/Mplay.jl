module Mplay

using Printf

include("midi.jl")
include("smf.jl")
include("console.jl")
include("dialog.jl")
include("keys.jl")

using .smf
using .console
using .dialog
using .keys

const intensities = (
    "        ",
    "●       ",
    "●●      ",
    "●●●     ",
    "●●●●    ",
    "●●●●●   ",
    "●●●●●●  ",
    "●●●●●●● ",
    "●●●●●●●●"
)

include("player.jl")

function __init__()
    if Sys.KERNEL == :NT
        lib= joinpath(@__DIR__, "lib")
        chmod(joinpath(lib, "libconsole.dll"), 0o755)
        chmod(joinpath(lib, "libmidi.dll"), 0o755)
    end
end

function showlyrics(smf)
    if 1 <= smf.line <= length(smf.lyrics)
        outtextxy(1, 22, rpad(smf.lyrics[smf.line], 80))
        outtextxy(smf.column > 1 ? smf.column - length(smf.text) : smf.column, 22, smf.text, 2)
        nextline = smf.line + max(smf.skiplines, 1)
        outtextxy(1, 23, rpad(nextline <= length(smf.lyrics) ? smf.lyrics[nextline] : "", 80))
    end
end

function update(player, smf)
    outtextxy(1, 1, fileinfo(smf))
    outtextxy(1, 2, songinfo(smf))
    outtextxy(1, 4, "Midi Channel    Name/Family  Instrument   Ch Ins Var Vol Pan Rev Cho Del Sen +/-")
    if player.selection > 0
        outtextxy([30, 54, 58, 62, 66, 70, 74, 78][player.parameter], 4, ["Instrument", "Vol", "Pan", "Rev", "Cho", "Del", "Sen", "+/-"][player.parameter], 10)
    end

    for part in 1:16
        info = partinfo(smf, part)
        if info.used
            program, variation = getprogram(info.instrument)
            pan = string(info.pan < 64 ? "L" : info.pan > 64 ? "R" : " ", abs(info.pan - 64))
            state = info.muted ? "x" : " "
            s = @sprintf "%-2d%s%-8s %15s: %-12s %2d %3d %3d %3d %3s %3d %3d %3d %3d %3d" part state intensities[div(info.intensity,15)+1] info.family info.name info.channel program+1 variation info.level pan info.reverb info.chorus info.delay info.sense info.shift-64;
            outtextxy(1, part + 4, s, player.selection == part ? 2 : 0)
        end
    end

    beat = beatinfo(smf) % 4
    s = rpad(string(repeat(" ", beat*20), repeat("█", 20)), 80)
    outtextxy(1, 21, s)
    showlyrics(smf)
    chord, notes = chordinfo(smf)
    outtextxy(1, 24, chord)
end

function mplay(path, device="", opts="")
    debug = haskey(ENV, "DEBUG")

    player = MidiPlayer(path)
    smf = player.midi

    transpose = false
    for opt in opts
        if transpose
            smf.key_shift = parse(Int, opt)
            transpose = false
        elseif opt == "--korg"
            setkorgmode()
        elseif opt == "-t"
            transpose = true
        elseif match(r"[-][bdg\d]", opt) !== nothing
            for key in opt[2:end]
                dispatch(player, key)
            end
        else
            println("unknown option: $opt")
        end
    end

    raw_mode = false
    while true
        delta = play(smf, device)
        if !raw_mode
            settty()
            cls()
            raw_mode = true
        end
        if !debug
            update(player, smf)
        end
        if delta > 0
            sleep(delta)
        end
        if kbhit()
            key = readchar()
            if key == Int('\e')
                allsoundoff(smf)
                cls();
                break
            else
                dispatch(player, Char(key))
            end
        end
        if smf.at >= smf.atend
            break
        end
    end
    raw_mode && resettty()
end

export mplay

function main()
    if length(ARGS) > 0
        path = ARGS[1]
    else
        path = "."
    end
    device = haskey(ENV, "MIDI_DEVICE") ? ENV["MIDI_DEVICE"] : ""
    if isdir(path)
        while true
            (file, opts) = openfiledialog(path)
            if file == nothing
                break
            end
            if length(file) > 0
                mplay(file, device, opts)
            end
        end
    else
        mplay(path, device)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

end #module
