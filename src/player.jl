
const MUTE_ON_OFF = Dict{Char, Any}(
    'b' => ["Bass"], 'g' => ["Guitar"],
    'k' => ["Piano", "Organ", "Strings", "Ensemble"])

const SOLO_ON = Dict{Char, Any}(
    'B' => ["Bass"], 'G' => ["Guitar"],
    'K' => ["Piano", "Organ", "Strings", "Ensemble"])

mutable struct Player
    midi::Any
    muted::Array{Bool,1}
    solo::Array{Bool,1}
    button::Bool
    selection::Int
    parameter::Int
    pause::Bool
    fretboard::Bool
end

function MidiPlayer(path)
    if isfile(path)
        smf = readsmf(path)
        loadarrangement(smf, path)
        player = Player(smf, falses(16), falses(16), false, 0, 1, false, false)
    else
        println("Can't open $path")
        exit(1)
    end
    player
end

function change_mute_state(player, part)
    state = player.muted[part]
    if state
        player.solo[part] = false
        allnotesoff(player.midi, part)
    end
    setpart(player.midi, part, muted=state)
end

function change_solo_state(player, part)
    player.solo[part] = !player.solo[part]
    player.muted[part] = false
    setpart(player.midi, part, muted=false)
    state = player.solo[part]
    for other in 1:16
        if other != part
            player.solo[other] = false
            player.muted[other] = state
            if state
                allnotesoff(player.midi, other)
            end
            setpart(player.midi, other, muted=state)
        end
    end
end

function controlchange(player, value)
    info = partinfo(player.midi, player.selection)
    if player.parameter == 1
        instrument = min(max(info.instrument + value, 1), length(instruments))
        setpart(player.midi, player.selection, instrument=instrument)
    elseif player.parameter == 2
        level = min(max(info.level + value, 0), 127)
        setpart(player.midi, player.selection, level=level)
    elseif player.parameter == 3
        pan = min(max(info.pan + value, 0), 127)
        setpart(player.midi, player.selection, pan=pan)
    elseif player.parameter == 4
        reverb = min(max(info.reverb + value, 0), 127)
        setpart(player.midi, player.selection, reverb=reverb)
    elseif player.parameter == 5
        chorus = min(max(info.chorus + value, 0), 127)
        setpart(player.midi, player.selection, chorus=chorus)
    elseif player.parameter == 6
        delay = min(max(info.delay + value, 0), 127)
        setpart(player.midi, player.selection, delay=delay)
    elseif player.parameter == 7
        sense = min(max(info.sense + value, 0), 127)
        setpart(player.midi, player.selection, sense=sense)
    elseif player.parameter == 8
        shift = min(max(info.shift + value, 40), 88)
        setpart(player.midi, player.selection, shift=shift)
    end
end

function dispatch(player, key)
    if key == '\e'
        setsong(player.midi, action=:exit)
        exit(0)
    elseif key == '\r'
        player.selection = 0
    elseif key == '\t'
        if player.parameter < 8 player.parameter += 1 else player.parameter = 1 end
    elseif key == Char(KEY_DOWN)
        if player.selection < 16 player.selection += 1 else player.selection = 1 end
        info = partinfo(player.midi, player.selection)
        while !info.used
            if player.selection < 16 player.selection += 1 else player.selection = 1 end
            info = partinfo(player.midi, player.selection)
        end
    elseif key == Char(KEY_UP)
        if player.selection > 1 player.selection -= 1 else player.selection = 16 end
        info = partinfo(player.midi, player.selection)
        while !info.used
            if player.selection > 1 player.selection -= 1 else player.selection = 16 end
            info = partinfo(player.midi, player.selection)
        end
    elseif key == ' '
        setsong(player.midi, action=:pause)
        player.pause = !player.pause
    elseif key ∈ "1234567890!@#\$%^"
        part = findfirst(isequal(key), "1234567890!@#\$%^")
        player.muted[part] = !player.muted[part]
        change_mute_state(player, part)
    elseif key == 'a'
        for part in 1:16
            player.muted[part] = player.solo[part] = false
            change_mute_state(player, part)
        end
    elseif key == 'd'
        player.muted[10] = !player.muted[10]
        change_mute_state(player, 10)
    elseif key == 'D'
        change_solo_state(player, 10)
    elseif key == 'f'
        player.fretboard = !player.fretboard
    elseif key == 'm'
        if player.selection > 0
            part = player.selection
            player.muted[part] = !player.muted[part]
            change_mute_state(player, player.selection)
        end
    elseif key == 'p'
        player.midi.percussion = !player.midi.percussion
    elseif haskey(MUTE_ON_OFF, key)
        for part in 1:16
            info = partinfo(player.midi, part)
            if info.family ∈ MUTE_ON_OFF[key]
                player.muted[part] = !player.muted[part]
            change_mute_state(player, part)
            end
        end
    elseif key == 's'
        if player.selection > 0
            change_solo_state(player, player.selection)
        end
    elseif haskey(SOLO_ON, key)
        for part in 1:16
            info = partinfo(player.midi, part)
            player.muted[part] = info.family ∉ SOLO_ON[key]
            change_mute_state(player, part)
        end
    elseif key == '<'
        setsong(player.midi, shift=-1)
    elseif key == '>'
        setsong(player.midi, shift=+1)
    elseif key == '-'
        setsong(player.midi, bpm=-1)
    elseif key == '+'
        setsong(player.midi, bpm=+1)
    elseif key == ',' || key == Char(KEY_LEFT)
        if player.selection > 0
            controlchange(player, -1)
        else
            setsong(player.midi, bar=-1)
        end
    elseif key == '.' || key == Char(KEY_RIGHT)
        if player.selection > 0
            controlchange(player, +1)
        else
            setsong(player.midi, bar=+1)
        end
    elseif key == 'S'
        savearrangement(player.midi)
    end
end
