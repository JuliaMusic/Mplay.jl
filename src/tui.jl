module TUI

using Printf

include("console.jl")
include("dialog.jl")

using .console
using .dialog

export run, select_file

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

function prepare_runtime()
    if Sys.KERNEL == :NT
        lib = joinpath(@__DIR__, "lib")
        console = joinpath(lib, "libconsole.dll")
        isfile(console) && chmod(console, 0o755)
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

function update(player, api)
    smf = player.midi
    outtextxy(1, 1, api.fileinfo(smf))
    outtextxy(1, 2, api.songinfo(smf))
    outtextxy(1, 4, "Midi Channel    Name/Family  Instrument   Ch Ins Var Vol Pan Rev Cho Del Sen +/-")
    if player.selection > 0
        outtextxy([30, 54, 58, 62, 66, 70, 74, 78][player.parameter], 4,
                  ["Instrument", "Vol", "Pan", "Rev", "Cho", "Del", "Sen", "+/-"][player.parameter], 10)
    end

    for part in 1:16
        info = api.partinfo(smf, part)
        if info.used
            program, variation = api.getprogram(info.instrument)
            pan = string(info.pan < 64 ? "L" : info.pan > 64 ? "R" : " ", abs(info.pan - 64))
            state = info.muted ? "x" : " "
            s = @sprintf("%-2d%s%-8s %15s: %-12s %2d %3d %3d %3d %3s %3d %3d %3d %3d %3d",
                part, state, intensities[div(info.intensity, 15) + 1], info.family, info.name, info.channel,
                program + 1, variation, info.level, pan, info.reverb, info.chorus, info.delay, info.sense,
                info.shift - 64)
            outtextxy(1, part + 4, s, player.selection == part ? 2 : 0)
        end
    end

    beat = api.beatinfo(smf) % 4
    outtextxy(1, 21, rpad(string(repeat(" ", beat * 20), repeat("█", 20)), 80))
    showlyrics(smf)
    chord, _ = api.chordinfo(smf)
    outtextxy(1, 24, chord)
end

function run(player, device, api)
    prepare_runtime()
    debug = haskey(ENV, "DEBUG")
    smf = player.midi
    raw_mode = false
    try
        while true
            delta = api.play(smf, device)
            if !raw_mode
                settty()
                cls()
                raw_mode = true
            end
            !debug && update(player, api)
            delta > 0 && sleep(delta)
            if kbhit()
                key = readchar()
                if key == Int('\e')
                    api.allsoundoff(smf)
                    cls()
                    break
                else
                    api.dispatch(player, Char(key))
                end
            end
            smf.at >= smf.atend && break
        end
    finally
        raw_mode && resettty()
    end
    return nothing
end

function select_file(path)
    return openfiledialog(path)
end

end # module TUI
