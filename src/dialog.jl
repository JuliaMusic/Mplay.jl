module dialog

include("console.jl")
include("keys.jl")

using .console
using .keys

export openfiledialog

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
    if isfile(joinpath(path, "index.txt"))
        songs = readindex(joinpath(path, "index.txt"))
    else
        files = filter(x->endswith(x, ".mid"), readdir(path))
        songs = zip(files, files) |> collect
    end
    if length(songs) > 0
        settty()
        cls()

        first = 1
        current = 1
        scrolled = 0
        while true
            last = first + 23
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

        song = current > 0 ? joinpath(path, lowercase(split(songs[current][2])[end])) : nothing
    else
        song = nothing
    end
    song
end

end # module
