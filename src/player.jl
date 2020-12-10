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
    pause::Bool
end

player = nothing

function MidiPlayer(path)
    smf = readsmf(path)
    loadarrangement(smf, path)
    Player(smf, falses(16), falses(16), false, -1, false)
end

function change_mute_state(player, channel)
    setchannel(player.midi, channel, muted=player.muted[channel + 1])
end

function change_solo_state(player, channel)
    player.solo[channel + 1] = !player.solo[channel + 1]
    if player.solo[channel + 1]
        setchannel(player.midi, channel, solo=player.solo[channel + 1])
        for ch in 0:15
            player.muted[ch + 1] = ch != channel ? true : false
            player.solo[ch + 1] = ch == channel ? true : false
        end
    else
        for ch in 0:15
            player.muted[ch + 1] = false
            setchannel(player.midi, ch, muted=false)
        end
    end
end

function dispatch(player, key)
    if key == '\e'
        setsong(player.midi, action=:exit)
        exit(0)
    elseif key == '\t'
        if player.selection >= 0
            player.selection = (player.selection + 1) % 16
        else
            player.selection = 0
        end
        info = channelinfo(player.midi, player.selection)
        while !info[:used]
            player.selection = (player.selection + 1) % 16
            info = channelinfo(player.midi, player.selection)
        end
    elseif key == ' '
        setsong(player.midi, action=:pause)
        player.pause = !player.pause
    elseif key in "1234567890!@#\$%^"
        channel = findfirst(isequal(key), "1234567890!@#\$%^") - 1
        player.muted[channel + 1] = !player.muted[channel + 1]
        change_mute_state(player, channel)
    elseif key == 'a'
        for channel in 0:15
            player.muted[channel + 1] = player.solo[channel + 1] = false
            change_mute_state(player, channel)
        end
    elseif key == 'd'
        player.muted[10] = !player.muted[10]
        change_mute_state(player, 9)
    elseif key == 'D'
        change_solo_state(player, 9)
    elseif haskey(MUTE_ON_OFF, key)
        for channel in 0:15
            info = channelinfo(player.midi, channel)
            if channel != 9 && info[:family] in MUTE_ON_OFF[key]
                player.muted[channel + 1] = !player.muted[channel + 1]
            end
            change_mute_state(player, channel)
        end
    elseif haskey(SOLO_ON, key)
        for channel in 0:15
            info = channelinfo(player.midi, channel)
            if channel != 9 && info[:family] in SOLO_ON[key]
                player.muted[channel + 1] = false
            else
                player.muted[channel + 1] = true
                player.solo[channel + 1] = false
            end
            change_mute_state(player, channel)
        end
    elseif key == '<'
        setsong(player.midi, shift=-1)
    elseif key == '>'
        setsong(player.midi, shift=+1)
    elseif key == '-'
        setsong(player.midi, bpm=-1)
    elseif key == '+'
        setsong(player.midi, bpm=+1)
    elseif key == ','
        if player.selection >= 0
            info = channelinfo(player.midi, player.selection)
            instrument = info[:instrument] - 1
            if instrument < 1 instrument = length(instruments) end
            setchannel(player.midi, player.selection, instrument=instrument)
        else
            setsong(player.midi, bar=-1)
        end
    elseif key == '.'
        if player.selection >= 0
            info = channelinfo(player.midi, player.selection)
            instrument = info[:instrument] + 1
            if instrument > length(instruments) instrument = 1 end
            setchannel(player.midi, player.selection, instrument=instrument)
        else
            setsong(player.midi, bar=+1)
        end
    elseif key == 's'
        savearrangement(player.midi)
    end
end
