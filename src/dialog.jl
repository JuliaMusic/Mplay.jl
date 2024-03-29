module dialog

include("console.jl")
include("keys.jl")

using DelimitedFiles

using .console
using .keys

export openfiledialog

first = 1
current = 1
scrolled = 0

function readindex(path)
    songs = []
    for line in readlines(path)
        if length(line) < 80 continue end
        info = rstrip(line[1:80])
        args = strip(line[81:end])
        push!(songs, (info, args))
    end
    songs
end

function openfiledialog(path)
    global first, current, scrolled
    if isfile(joinpath(path, "index.txt"))
        songs = readindex(joinpath(path, "index.txt"))
        if isfile(joinpath(path, "set.txt"))
            set = readdlm(joinpath(path, "set.txt"), ',', Int)
            songs = songs[set]
        end
    else
        files = filter(x->endswith(lowercase(x), ".mid"), readdir(path))
        songs = zip(files, files) |> collect
    end
    if length(songs) > 0
        settty()
        cls()
        lines, colums = winsz()
        while true
            last = first + min(lines-1, length(songs) - 1)
            for index in first:last
                outtextxy(1, index - scrolled, rpad(songs[index][1], 80))
            end
            outtextxy(1, current - scrolled, rpad(songs[current][1], 80), 2)
            key = readchar()
            if key == Int('\e')
               current = 0
               break
            elseif key == Int('\r')
                break
            elseif key == KEY_DOWN
               if current < length(songs) current += 1 end
               if current == last + 1
                   first += 1
                   scrolled += 1
               end
            elseif key == KEY_UP
               if current > 1 current -= 1 end
               if current == first - 1
                   first -= 1
                   scrolled -= 1
               end
            end
        end
        resettty()
        cls()
        if current > 0
            args = split(songs[current][2])
            if length(args) > 0
                file = joinpath(path, lowercase(args[end]))
                opts = args[1:end-1]
                song = (file, opts)
            else
                song = ("", "")
            end
        else
            song = (nothing, nothing)
        end
    else
        song = (nothing, nothing)
    end
    song
end

end # module
