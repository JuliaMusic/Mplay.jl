
const KEY_RIGHT = 262
const KEY_LEFT  = 263
const KEY_DOWN  = 264
const KEY_UP    = 265

const MUTE_ON_OFF = Dict{Char, Any}(
    'b' => ["Bass"], 'g' => ["Guitar"],
    'k' => ["Piano", "Organ", "Strings", "Ensemble"])

const SOLO_ON = Dict{Char, Any}(
    'B' => ["Bass"], 'G' => ["Guitar"],
    'K' => ["Piano", "Organ", "Strings", "Ensemble"])

const parameters = Dict(
    1 => :instrument, 2 => :level, 3 => :pan, 4 => :reverb, 5 => :chorus, 6 => :delay, 7 => :sense, 8 => :shift)

mutable struct Player
    midi::Any
    muted::Array{Bool,1}
    solo::Array{Bool,1}
    button::Bool
    selection::Int
    parameter::Int
    pause::Bool
end

player = nothing

function MidiPlayer(path)
    smf = readsmf(path)
    loadarrangement(smf, path)
    Player(smf, falses(16), falses(16), false, -1, 1, false)
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

function controlchange(player, value)
    info = channelinfo(player.midi, player.selection)
    if player.parameter == 1
        instrument = min(max(info[:instrument] + value, 1), length(instruments))
        setchannel(player.midi, player.selection, instrument=instrument)
    elseif player.parameter == 2
        level = min(max(info[:level] + value, 0), 127)
        setchannel(player.midi, player.selection, level=level)
    elseif player.parameter == 3
        pan = min(max(info[:pan] + value, 0), 127)
        setchannel(player.midi, player.selection, pan=pan)
    elseif player.parameter == 4
        reverb = min(max(info[:reverb] + value, 0), 127)
        setchannel(player.midi, player.selection, reverb=reverb)
    elseif player.parameter == 5
        chorus = min(max(info[:chorus] + value, 0), 127)
        setchannel(player.midi, player.selection, chorus=chorus)
    elseif player.parameter == 6
        delay = min(max(info[:delay] + value, 0), 127)
        setchannel(player.midi, player.selection, delay=delay)
    elseif player.parameter == 7
        sense = min(max(info[:sense] + value, 0), 127)
        setchannel(player.midi, player.selection, sense=sense)
    elseif player.parameter == 8
        shift = min(max(info[:shift] + value, 40), 88)
        setchannel(player.midi, player.selection, shift=shift)
    end
end

function dispatch(player, key)
    if key == '\e'
        setsong(player.midi, action=:exit)
        exit(0)
    elseif key == '\r'
        player.selection = -1
    elseif key == '\t'
        if player.parameter < length(parameters) player.parameter += 1 else player.parameter = 1 end
    elseif key == Char(KEY_DOWN)
        if player.selection < 15 player.selection += 1 else player.selection = 0 end
        info = channelinfo(player.midi, player.selection)
        while !info[:used]
            if player.selection < 15 player.selection += 1 else player.selection = 0 end
            info = channelinfo(player.midi, player.selection)
        end
    elseif key == Char(KEY_UP)
        if player.selection > 0 player.selection -= 1 else player.selection = 15 end
        info = channelinfo(player.midi, player.selection)
        while !info[:used]
            if player.selection > 0 player.selection -= 1 else player.selection = 15 end
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
    elseif key == 'm'
        if player.selection >= 0
            part = player.selection + 1
            player.muted[part] = !player.muted[part]
            change_mute_state(player, player.selection)
        end
    elseif haskey(MUTE_ON_OFF, key)
        for channel in 0:15
            info = channelinfo(player.midi, channel)
            if channel != 9 && info[:family] in MUTE_ON_OFF[key]
                player.muted[channel + 1] = !player.muted[channel + 1]
            end
            change_mute_state(player, channel)
        end
    elseif key == 's'
        if player.selection >= 0
            change_solo_state(player, player.selection)
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
    elseif key == ',' || key == Char(KEY_LEFT)
        if player.selection >= 0
            controlchange(player, -1)
        else
            setsong(player.midi, bar=-1)
        end
    elseif key == '.' || key == Char(KEY_RIGHT)
        if player.selection >= 0
            controlchange(player, +1)
        else
            setsong(player.midi, bar=+1)
        end
    elseif key == 'S'
        savearrangement(player.midi)
    end
end
