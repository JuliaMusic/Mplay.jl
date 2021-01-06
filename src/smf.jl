module smf

using Printf

using ..midi

export setopts, readsmf, loadarrangement, savearrangement, play,
       fileinfo, songinfo, beatinfo, chordinfo, getprogram,
       setsong, partinfo, setpart, allnotesoff, allsoundoff, cpuload
export midi

include("korg.jl")

oct(n) = string(n, base=8)

function dec(n::Int, pad::Int=0)
    string(n, pad=pad)
end

function hex(n, pad::Int=0)
    string(n, base=16, pad=pad)
end

debug = false
warnings = false
soft_shift = false

const gm1 = false

include("instruments.jl")

const instruments = sc88_instruments
export instruments

const families = (
    "Piano", "Chrom Perc", "Organ", "Guitar",
    "Bass", "Strings", "Ensemble", "Brass",
    "Reed", "Pipe", "Synth Lead", "Synth Pad",
    "Synth Effects", "Ethnic", "Percussive", "Sound Effects")

const drum_instruments = (
    "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
    "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
    "", "", "", "Acoustic Bass Drum",
    "Bass Drum 1", "Side Stick", "Acoustic Snare", "Hand Clap",
    "Electric Snare", "Low Floor Tom", "Closed Hi-Hat", "High Floor Tom",
    "Pedal Hi-Hat", "Low Tom", "Open Hi-Hat", "Low-Mid Tom",
    "Hi-Mid Tom", "Crash Cymbal 1", "High Tom", "Ride Cymbal 1",
    "Chinese Cymbal", "Ride Bell", "Tambourine", "Splash Cymbal",
    "Cowbell", "Crash Cymbal 2", "Vibraslap", "Ride Cymbal 2",
    "Hi Bongo", "Low Bongo", "Mute Hi Conga", "Open Hi Conga",
    "Low Conga", "High Timbale", "Low Timbale", "High Agogo",
    "Low Agogo", "Cabasa", "Maracas", "Short Whistle",
    "Long Whistle", "Short Guiro", "Long Guiro", "Claves",
    "Hi Wood Block", "Low Wood Block", "Mute Cuica", "Open Cuica",
    "Mute Triangle", "Open Triangle", "", "",
    "", "", "", "", "", "", "", "", "", "", "", "",
    "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
    "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "")

const keys = ("Cb", "Gb", "Db", "Ab", "Eb", "Bb", " F",
              " C", " G", " D", " A", " E", " B", "F#",
              "C#", "*/")
const modes = (" ", "m", "*")

const notes = ("C", "Db", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B")

const chords = Dict(
    0b000010010001 => "",
    0b000010100001 => "sus",
    0b000001010001 => "-5",
    0b000100010001 => "+5",
    0b001010010001 => "6",
    0b010010010001 => "7",
    0b100010010001 => "maj7",
    0b000010010101 => "add9",
    0b100010010101 => "maj9",
    0b001010010101 => "6/9",
    0b010010100001 => "7/4",
    0b011010010001 => "7/6",
    0b010100010001 => "7/+5",
    0b010001010001 => "7/-5",
    0b010010010101 => "7/9",
    0b010011010001 => "7/+9",
    0b010010010011 => "7-9",
    0b010001010011 => "7-9-5",
    0b001001001001 => "dim",
    0b000100010101 => "9+5",
    0b000001010101 => "9-5",
    0b010100010011 => "7-9+5",
    0b000010001001 => "m",
    0b001010001001 => "m6",
    0b010010001001 => "m7",
    0b100010001001 => "mmaj7",
    0b010001001001 => "m7-5",
    0b000010001101 => "m9",
    0b000010101001 => "m11")

const messages = (
    "Note Off", "Note  On", "Key Pressure", "Control Change",
    "Program Change", "Channel Pressure", "Pitch Wheel")

const meta = (
    "Sequence Number", "Text", "Copyright", "Sequence Name",
    "Instrument", "Lyric", "Marker", "Cue Point")

const block = (
    1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 10, 11, 12, 13, 14, 15)

firstdrumset = 0


function getinstrument(part, program, variation)
    global firstdrumset
    if part == 10
        if firstdrumset == 0
            for i in 1:length(instruments)
                if startswith(instruments[i][1], "STANDARD")
                    firstdrumset = i
                    break
                end
            end
        end
        first = firstdrumset
    else
        first = 1
    end
    for i in first:length(instruments)
        if program == instruments[i][2] && variation == instruments[i][3]
             return i
        end
    end
    return program
end


function getprogram(instrument)
   instruments[instrument][2], instruments[instrument][3]
end


function printable(chars)
    result = ""
    for b in chars
        if b == UInt8('\n')
            result *= "\\n"
        elseif b == UInt8('\r')
            result *= "\\r"
        elseif b < UInt8(' ')
            result *= "\\0" * oct(b)
        else
            result *= string(Char(b))
        end
    end
    return result
end

mutable struct Part
    used::Bool
    muted::Bool
    name::String
    channel::Int
    instrument::Int
    family::String
    variation::Int
    level::Int
    pan::Int
    reverb::Int
    chorus::Int
    delay::Int
    sense::Int
    shift::Int
    velocity::Int
    intensity::Int
    notes::Array{Int}
end

mutable struct Arrangement
    muted::Int
    channel::Int
    instrument::Int
    variation::Int
    level::Int
    pan::Int
    reverb::Int
    chorus::Int
    delay::Int
    sense::Int
    shift::Int
end

mutable struct SMF
    path::AbstractString
    format::Int
    tracks::Int
    mf::Array{UInt8}
    off::Int
    ev::Array{Array{Any}}
    lyrics::Array{Any}
    midi_clock::Int
    next::Int
    at::Float64
    start::Float64
    atend::Float64
    elapsed_time::Float64
    pause::Float64
    division::Int
    bpm::Int
    playing_time::Float64
    text::String
    line::Int
    column::Int
    chord::String
    notes::Array{Any}
    tempo::Int
    numerator::Int
    denominator::Int
    clocks_per_beat::Int
    notes_per_quarter::Int
    key::Int
    key_shift::Int
    mode::Int
    info::Array{Part}
    preset::Array{Arrangement}
end


function StandardMidiFile()
    ev = Array{Array{Any}}(undef,0)
    info = Array{Any}(undef,16)
    preset = Array{Any}(undef,16)
    smf = SMF("", 0, 0, zeros(UInt8,0), 1, ev, [], 0, 1,
              0, -1, 0, 0, 0, 384, 120, 0, "", 0, 1, "", [], div(60000000,120),
              4, 4, 24, 8, 8, 0, 2, info, preset)
    for part in 1:16
        smf.info[part] = Part(false, false, "", part - 1, 1, "", 0, 100, 64,
                              40, 0, 0, 64, 64, 0, 0, [])
        smf.preset[part] = Arrangement(-ones(11)...)
    end
    smf
end


function bytes(smf, n)
    smf.mf[smf.off : smf.off + n - 1]
end

function extractbyte(smf)::UInt8
    value = smf.mf[smf.off]
    smf.off += 1
    value
end

function extractbytes(smf, n)
    value = smf.mf[smf.off : smf.off + n - 1]
    smf.off += n
    value
end

function extractshort(smf)
    value = (Int(smf.mf[smf.off]) << 8) + smf.mf[smf.off + 1]
    smf.off += 2
    value
end

function extractnumber(smf)
    value = 0
    if smf.mf[smf.off] & 0x80 != 0
        while true
            value = (value << 7) + (smf.mf[smf.off] & 0x7f)
            smf.mf[smf.off] & 0x80 != 0 || break
            smf.off += 1
        end
    else
        value = smf.mf[smf.off]
    end
    smf.off += 1
    value
end

function readevents(smf)
    global debug, korg, drum_channel
    state = 0
    chan = 0
    at = 0
    while true
        if smf.off + 4 > length(smf.mf) break end # sanity check
        delta = extractnumber(smf)
        at += delta
        me = extractbyte(smf)
        if me == 0xf0 || me == 0xf7
            num_bytes = extractnumber(smf)
            metadata = extractbytes(smf, num_bytes)
            push!(smf.ev, [at, me, num_bytes, metadata])
            if debug
                println(dec(at, 6), " System Exclusive ($num_bytes bytes)")
            end
        elseif me == 0xff
            me_type = extractbyte(smf)
            num_bytes = extractnumber(smf)
            if me_type < 8
                text = extractbytes(smf, num_bytes)
                push!(smf.ev, [at, me, me_type, text])
                if debug
                    println(dec(at, 6), " $(meta[me_type + 1]): ",
                            printable(text))
                end
            elseif me_type <= 0x0f
                smf.off += num_bytes
            elseif me_type == 0x20
                byte1 = extractbyte(smf)
                if debug
                    println(dec(at, 6), " Channel Prefix 0x", hex(byte1, 2))
                end
            elseif me_type == 0x21
                byte1 = extractbyte(smf)
                if debug
                    println(dec(at, 6), " Port Number 0x", hex(byte1, 2))
                end
            elseif me_type == 0x2f
                push!(smf.ev, [at, 0, 0, 0])
                if debug
                    println(dec(at, 6), " End of Track")
                end
                return
            elseif me_type == 0x51
                data = extractbytes(smf, 3)
                push!(smf.ev, [at, me, me_type, data])
                if debug
                    tempo = (Int(data[1]) << 16) + (Int(data[2]) << 8) + data[3]
                    println(dec(at, 6), " Tempo 0x", hex(data[1], 2),
                            " 0x", hex(data[2], 2), " 0x", hex(data[3], 2),
                            " ($tempo, ", div(60000000, tempo), " bpm)")
                end
            elseif me_type == 0x58
                data = extractbytes(smf, 4)
                push!(smf.ev, [at, me, me_type, data])
                if debug
                    println(dec(at, 6), " Time 0x", hex(data[1], 2),
                            " 0x", hex(data[2], 2), " 0x", hex(data[3], 2),
                            " 0x", hex(data[4], 2))
                end
            elseif me_type == 0x59
                data = extractbytes(smf, 2)
                push!(smf.ev, [at, me, me_type, data])
                if debug
                    println(dec(at, 6), " Key 0x", hex(data[1], 2),
                            " 0x", hex(data[2], 2))
                end
            else
                smf.off += num_bytes
                if debug
                    println(dec(at, 6), " Meta Event 0x", hex(me_type, 2),
                            " ($num_bytes bytes)")
                end
            end
        else
            byte1 = me
            if byte1 & 0x80 != 0
                chan = byte1 & 0x0f
                state = (byte1 >> 4) & 0x07
                byte1 = extractbyte(smf) & 0x7f
            end
            if state < 7
                message = 0x80 | (state << 4) | chan
                if state != 4 && state != 5
                    byte2 = extractbyte(smf) & 0x7f
                else
                    byte2 = 0
                end
                push!(smf.ev, [at, message, byte1, byte2])
                if korg && state == 4 && byte1 == 9
                    drum_channel = chan
                end
                if debug
                    if state ∈ (0, 1)
                        if chan != 9
                            s = " (" * notes[byte1 % 12 + 1] *
                                string(div(byte1, 12)) * ")"
                        else
                            if drum_instruments[byte1 + 1] != ""
                                s = " (" * drum_instruments[byte1 + 1] * ")"
                            else
                                s = ""
                            end
                        end
                    else
                        s = ""
                    end
                    if state ∈ (0, 1, 2, 3, 6)
                        println(dec(at, 6), " ", messages[state + 1],
                                " 0x", hex(chan, 2), " 0x", hex(byte1, 2),
                                " 0x", hex(byte2, 2), s)
                    else
                        println(dec(at, 6), " ", messages[state + 1],
                                " 0x", hex(chan, 2), " 0x", hex(byte1, 2))
                    end
                end
            else
                println("Corrupt MIDI file")
            end
        end
    end
end


function collectlyrics(smf)
    lyrics = []
    line = ""
    for ev in smf.ev[1:end]
        at, message, me_type, data = ev
        if message == 0xff && me_type == 0x05
            if data[1] ∈ (13, 10)
               push!(lyrics, line)
               line = ""
            else
                if data[end] ∈ (13, 10)
                    push!(lyrics, line * printable(data[1:end-1]))
                    line = ""
                else
                    line *= printable(data)
                end
            end
        end
    end
    lyrics
end


function setopts(opts)
    global korg, drum_channel, drumkit, bank
    korg = "-korg" ∈ opts
    if korg
        drumkit = zeros(Int, 16)
        bank = zeros(Int, 16)
        drum_channel = 9
    end
end


function readsmf(path)
    global debug
    debug = haskey(ENV, "DEBUG")
    smf = StandardMidiFile()
    smf.path = basename(path)
    smf.mf = read(path)
    if String(bytes(smf, 4)) == "MThd"
        smf.off += 8
        smf.format = extractshort(smf)
        smf.tracks = extractshort(smf)
        smf.division = extractshort(smf)
    end
    if debug
        println("Format: $(smf.format), Tracks: $(smf.tracks), Division: $(smf.division)")
    end
    for track = 1:smf.tracks
        if String(bytes(smf, 4)) == "MTrk"
            smf.off += 8
            readevents(smf)
        else
            println("Missing track")
        end
    end

    smf.ev = sort(smf.ev[1:end], by=x->x[1])

    smf.lyrics = collectlyrics(smf)

    smf.playing_time = 0
    at = start = 0
    tempo = smf.tempo
    for ev in smf.ev[1:end]
        at, message, me_type, data = ev
        if message == 0xff && me_type == 0x51
            smf.playing_time += (at - start) / smf.division * tempo / 1000
            start = at
            tempo = (Int(data[1]) << 16) + (Int(data[2]) << 8) + data[3]
        end
    end
    smf.atend = at
    smf.playing_time += (at - start) / smf.division * tempo / 1000

    smf
end


function loadarrangement(smf, path)
    path = replace(path, ".mid" => ".arr")
    if isfile(path)
        file = open(path, "r")
        line = readline(file)
        while startswith(line, "#")
            line = readline(file)
        end
        for part = 1:16
            smf.preset[part] = Arrangement([parse(Int, x) for x in split(line)]...)
            line = readline(file)
        end
        close(file)
    else
        for part = 1:16
            smf.preset[part] = Arrangement(-ones(11)...)
        end
    end
end


function savearrangement(smf)
    path = replace(smf.path, ".mid" => ".arr")
    file = open(path, "w")
    @printf(file, "#!MPlay\n# M Ch Ins Var Vol Pan Rev Cho Del Sen +/-\n")
    for part = 1:16
        arr = smf.preset[part]
        @printf(file, "%3d %2d %3d %3d %3d %3d %3d %3d %3d %3d %3d\n",
                arr.muted, arr.channel, arr.instrument, arr.variation, arr.level, arr.pan,
                arr.reverb, arr.chorus, arr.delay, arr.sense, arr.shift)
    end
    close(file)
end


function fileinfo(smf)
    hsecs = div(round(Int, smf.playing_time), 10)
    secs = div(hsecs, 100)
    mins = div(secs, 60)
    secs %= 60
    hsecs %= 100
    string(rpad(smf.path, 12), "   Format: $(smf.format)   Tracks: $(smf.tracks)  Playing Time:  ", dec(mins, 2), ":", dec(secs, 2), ".", dec(hsecs, 2), "   Key:  ", lpad(keys[smf.key + 7 + 1], 2), modes[smf.mode + 1], "/", rpad(smf.key_shift, 3))
end


function songinfo(smf)
    if smf.pause != 0
        now = (smf.pause - smf.elapsed_time) * 1000
    else
        now = (time() - smf.elapsed_time) * 1000
    end
    ticks = round(Int, now * smf.division * 1000 / smf.tempo)
    hsecs = round(Int, now / 10)
    secs = div(hsecs, 100)
    mins = div(secs, 60)
    secs %= 60
    hsecs %= 100
    string("Clock: ", dec(mins, 2), ":", dec(secs, 2), ".", dec(hsecs, 2), "   Song Position: ", dec(div(div(ticks, smf.division), 4) + 1, 4), ":", dec(div(ticks, smf.division) % smf.numerator + 1, 2), ":", dec(div(ticks * 1000, smf.division) % 1000, 3), "  Tempo: ", lpad(dec(smf.bpm), 3), " bpm   Time: ", dec(smf.numerator, 2), "/", dec(smf.denominator, 2), "  ", dec(smf.clocks_per_beat, 2), "/", dec(smf.notes_per_quarter, 2))
end


function beatinfo(smf)
    if smf.pause != 0
        now = (smf.pause - smf.elapsed_time) * 1000
    else
        now = (time() - smf.elapsed_time) * 1000
    end
    trunc(Int, now * 1000 / smf.tempo)
end


function chordinfo(smf)
    keys_pressed = 0
    for part in 1:16
        info = smf.info[part]
        if part != 10 && info.family != "Bass"
            for note ∈ info.notes
                keys_pressed |= (1 << (note % 12))
            end
        end
    end
    bits = digits(keys_pressed, base=2)
    if count(!iszero, bits) ∈ (3, 4, 5)
        for key = 0:11
            if keys_pressed ∈ chords.keys
                smf.chord = rpad(notes[key + 1] * chords[keys_pressed] * "    ", 10)
                smf.notes = []
                for note = 0:11
                    if keys_pressed & (1 << note) != 0
                        smf.chord *= "  " * notes[(key + note) % 12 + 1]
                        smf.notes = [smf.notes; 60 + key + note]
                    end
                end
                smf.chord = rpad(smf.chord, 50)
                break
            end
            if keys_pressed & 1 != 0
                keys_pressed |= (1 << 12)
            end
            keys_pressed = (keys_pressed >> 1) & 0xfff
        end
    end
    smf.chord, smf.notes
end


function writemidi(smf, buf::Array{UInt8})
    global debug
    midiwrite(buf)
    if debug
        s = sep = ""
        for byte in buf
            s *= sep * "0x" * hex(byte, 2)
            sep = " "
        end
        println(round(time() - smf.start, digits=4), " ", s)
    end
end


function allnotesoff(smf, part)
    channel = smf.info[part].channel
    for note ∈ smf.info[part].notes
        writemidi(smf, UInt8[0x80 + channel, note, 0])
    end
    smf.info[part].notes = []
end


function allsoundoff(smf)
    for channel in 0:15
        writemidi(smf, UInt8[0xb0 + channel, 0x79, 0x00]) # Reset all controllers
        writemidi(smf, UInt8[0xb0 + channel, 0x7b, 0x00]) # All notes off
    end
end


function songposition(smf, beat)
    smf.next = 1
    for ev in smf.ev
        at, message, byte1, byte2 = ev
        if at > beat * smf.division
            smf.elapsed_time = time() - at / smf.division / 1000000. * smf.tempo
            break
        end
        smf.next += 1
    end
end


function setsong(smf; info...)
    info = Dict(info)
    if haskey(info, :shift)
        for part = 1:16
            allnotesoff(smf, part)
        end
        smf.key_shift += info[:shift]
    elseif haskey(info, :bpm)
        smf.bpm += info[:bpm]
        now = time()
        tempo = smf.tempo
        smf.tempo = div(div(60000000, smf.bpm) * 4, smf.denominator)
        smf.elapsed_time = now - (now - smf.elapsed_time) * smf.tempo / tempo
    elseif haskey(info, :bar)
        now = (time() - smf.elapsed_time) * 1000
        beat = round(Int, now * 1000 / smf.tempo)
        beat += 4 * info[:bar] - (beat % 4)
        for part = 1:16
            allnotesoff(smf, part)
        end
        songposition(smf, beat)
        if smf.pause != 0
            smf.pause = time()
        end
    elseif haskey(info, :action)
        if info[:action] == :exit
            for part = 1:16
                allnotesoff(smf, part)
            end
            allsoundoff(smf)
            midiclose()
        elseif info[:action] == :pause
            if smf.pause == 0
                smf.pause = time()
                writemidi(smf, UInt8[0xfc])
                for part = 1:16
                    allnotesoff(smf, part)
                end
            else
                smf.elapsed_time += time() - smf.pause
                smf.pause = 0
                writemidi(smf, UInt8[0xfb])
            end
        end
    end
end


function partinfo(smf, part)
    smf.info[part]
end


function setpart(smf, part; info...)
    channel = smf.info[part].channel
    info = Dict(info)
    if haskey(info, :muted)
        smf.info[part].muted = info[:muted]
        if info[:muted]
            allnotesoff(smf, part)
        end
    elseif haskey(info, :level)
        smf.info[part].level = info[:level]
        smf.preset[part].level = info[:level]
        writemidi(smf, UInt8[0xb0 + channel, 7, info[:level]])
    elseif haskey(info, :sense)
        smf.info[part].sense = info[:sense]
        smf.preset[part].sense = info[:sense]
        mididataset1(0x40101a + block[part] << 8, info[:sense])
        sleep(0.04)
    elseif haskey(info, :shift)
        allnotesoff(smf, part)
        smf.info[part].shift = info[:shift]
        smf.preset[part].shift = info[:shift]
        mididataset1(0x401016 + block[part] << 8, info[:shift])
        sleep(0.04)
    elseif haskey(info, :delay)
        smf.info[part].delay = info[:delay]
        smf.preset[part].delay = info[:delay]
        writemidi(smf, UInt8[0xb0 + channel, 94, info[:delay]])
    elseif haskey(info, :chorus)
        smf.info[part].chorus = info[:chorus]
        smf.preset[part].chorus = info[:chorus]
        writemidi(smf, UInt8[0xb0 + channel, 93, info[:chorus]])
    elseif haskey(info, :reverb)
        smf.info[part].reverb = info[:reverb]
        smf.preset[part].reverb = info[:reverb]
        writemidi(smf, UInt8[0xb0 + channel, 91, info[:reverb]])
    elseif haskey(info, :pan)
        smf.info[part].pan = info[:pan]
        smf.preset[part].pan = info[:pan]
        writemidi(smf, UInt8[0xb0 + channel, 10, info[:pan]])
    elseif haskey(info, :instrument)
        name, program, variation = instruments[info[:instrument]]
        smf.info[part].instrument = info[:instrument]
        smf.info[part].name = name
        writemidi(smf, UInt8[0xb0 + channel, 0x20, !gm1 ? 0 : 2]) # 0=default, 1=SC-55, 2=SC-88
        writemidi(smf, UInt8[0xb0 + channel, 0x00, variation])
        writemidi(smf, UInt8[0xc0 + channel, program])
        smf.preset[part].instrument = program
        smf.preset[part].variation = variation
    end
end


function timing(smf, at)
    if at >= smf.midi_clock
        writemidi(smf, UInt8[0xf8])
        smf.midi_clock += div(smf.division, 24)
    end
end


function cpuload()
    return midisystemload()
end


function updatelevels(smf)
    for part in 1:16
        info = partinfo(smf, part)
        if info.notes == [] || info.muted == 1
            if info.intensity >= 2
                info.intensity -= 2
            else
                info.intensity = 0
            end
        end
    end
end


function setdrumpart(smf)
    global korg, drum_channel
    if korg
        smf.info[10].channel = drum_channel
        smf.info[drum_channel + 1].channel = 9
    else
        smf.info[10].name = instruments[getinstrument(10, 0, 0)][1]
        smf.info[10].family = "Drums"
    end
end


function play(smf, device="")
    global debug, korg, drum_channel, drumkit, bank
    if smf.start < 0
        midiopen(device)
        mididataset1(0x40007f, 0x00)   # GS Reset
        sleep(0.04)
        mididataset1(0x400130, 0x04)   # Hall 1
        sleep(0.04)
        setdrumpart(smf)
        for part in 1:16
            arr = smf.preset[part]
            if arr.instrument != -1 && arr.variation != -1
                instrument = getinstrument(part, arr.instrument, max(arr.variation, 0))
                setpart(smf, part, instrument=instrument)
            end
            if arr.level != -1 setpart(smf, part, level=arr.level) end
            if arr.pan != -1 setpart(smf, part, pan=arr.pan) end
            if arr.reverb != -1 setpart(smf, part, reverb=arr.reverb) end
            if arr.chorus != -1 setpart(smf, part, chorus=arr.chorus) end
            if arr.delay != -1 setpart(smf, part, delay=arr.delay) end
        end
        smf.start = time()
        writemidi(smf, UInt8[0xfc, 0xfa])
        smf.elapsed_time = smf.start
        smf.line = 0
    end
    if smf.pause != 0
        return 0.04
    end
    for ev in smf.ev[smf.next:end]
        at, message, byte1, byte2 = ev
        now = time() - smf.elapsed_time
        updatelevels(smf)
        if at > now * smf.division * 1000000 / smf.tempo
            timing(smf, at)
            delta = (at - now * smf.division * 1000000 / smf.tempo) / 1000
            delta = min(delta, 1.0 / (smf.division / 24))
            return delta
        end
        if warnings
            drift = now * smf.division * 1000000 / smf.tempo - at
            if drift > 20
                @printf("MIDI sync drift: %d\n", drift)
            end
        end
        timing(smf, at)
        smf.at = at
        if message == 0xf0 || message == 0xf7
            at, message, num_bytes, metadata, = ev
            writemidi(smf, UInt8[0xf0, metadata..., 0xf7])
        elseif message == 0xff
            at, message, me_type, data = ev
            if me_type == 0x05
                if data[1] ∈ (13, 10)
                    smf.line += 1
                    smf.column = 0
                else
                    if data[end] ∈ (13, 10)
                        smf.text = printable(data[1:end-1])
                        smf.line += 1
                        smf.column = 1
                    else
                        smf.text = printable(data)
                        smf.column += length(smf.text)
                    end
                end
            elseif me_type == 0x51
                now = time()
                tempo = smf.tempo
                smf.tempo = (Int(data[1]) << 16) + (Int(data[2]) << 8) + data[3]
                smf.bpm = div(60000000, smf.tempo) * smf.denominator / 4
                smf.elapsed_time = now - (now - smf.elapsed_time) * smf.tempo / tempo
            elseif me_type == 0x58
                smf.numerator = data[1]
                smf.denominator = 1 << data[2]
                smf.clocks_per_beat = data[3]
                smf.notes_per_quarter = data[4]
            elseif me_type == 0x59
                smf.key = data[1]
                smf.mode = data[2]
                if smf.key < -7 || smf.key > 8
                    smf.key = 8
                end
                if smf.mode < 0 || smf.mode > 2
                    smf.mode = 2
                end
            end
        else
            me_type = message & 0xf0
            channel = message & 0x0f
            part = channel + 1
            info = smf.info[part]
            info.used = true
            preset = smf.preset[part]
            if me_type ∈ (0x80, 0x90)
                if korg && info.channel == 9
                    if 35 < byte1 < 96
                        byte1 = korg_drumset[drumkit[part] + 1][byte1 - 35]
                    else
                        byte1 = 0
                    end
                    if byte1 == 0
                        smf.next += 1
                        continue
                    end
                    message = me_type | 0x09
                end
                if info.channel != 9
                    byte1 += smf.key_shift
                    if soft_shift
                        byte1 += info.shift - 64
                    end
                end
            end
            if me_type == 0x80
                if byte1 in info.notes
                    info.notes = setdiff(info.notes, byte1)
                end
                info.velocity = 0
            elseif me_type == 0x90
                if byte2 != 0
                    if byte1 ∈ info.notes
                        if debug println("Note retriggered") end
                    else
                        info.notes = [info.notes; byte1]
                    end
                    if info.muted == 0
                        info.intensity = byte2
                    end
                elseif byte1 ∈ info.notes
                    info.notes = setdiff(info.notes, byte1)
                end
                info.velocity = byte2
            elseif me_type == 0xb0
                if byte1 == 0
                    preset.variation != -1 && (byte2 = preset.variation)
                    program = instruments[info.instrument][2]
                    getinstrument(part, program, byte2) == program && (byte2 = 0)
                    bank[part] = 0
                    info.variation = byte2
                    info.family = families[div(program, 8) + 1]
                elseif byte1 == 32
                    bank[part] |= byte2
                    byte2 = !gm1 ? 0 : 2 # 0=default, 1=SC-55, 2=SC-88
                elseif byte1 == 7
                    preset.level != -1 && (byte2 = preset.level)
                    info.level = byte2
                elseif byte1 == 10
                    preset.pan != -1 && (byte2 = preset.pan)
                    info.pan = byte2
                elseif byte1 == 91
                    preset.reverb != -1 && (byte2 = preset.reverb)
                    info.reverb = byte2
                elseif byte1 == 93
                    preset.chorus != -1 && (byte2 = preset.chorus)
                    info.chorus = byte2
                elseif byte1 == 94
                    preset.delay != -1 && (byte2 = preset.delay)
                    info.delay = byte2
                end
            elseif me_type == 0xc0
                if korg
                    if bank[part] < 2 && byte1 < 100
                        if byte1 ∈ (9, 29)
                            info.channel = 9
                            drumkit[part] = bank[part] * 2 + ((byte1 == 9) ? 0 : 1)
                        end
                        i = korg_map[bank[part] + 1][byte1 + 1]
                        byte1 = abs(i) - 1
                        if info.channel != 9
                            instrument = getinstrument(info.channel + 1, byte1, 0)
                        else
                            instrument = getinstrument(10, 0, 0)
                        end
                        info.shift = i < 0 ? 64 - 12 : 64
                        if i < 0 && !soft_shift
                            setpart(smf, part, shift=info.shift)
                        end
                    else
                        smf.next += 1
                        continue
                    end
                else
                    preset.instrument != -1 && (byte1 = preset.instrument)
                    byte2 = max(preset.variation, 0)
                    instrument = getinstrument(part, byte1, byte2)
                end
                info.name = instruments[instrument][1]
                info.instrument = instrument
                if info.channel != 9
                    program = instruments[instrument][2]
                    info.family = families[div(program, 8) + 1]
                else
                    info.family = "Drums"
                end
            end
            if info.muted == 0 && preset.muted ∈ (-1, 0)
                if korg
                    message = me_type | info.channel
                end
                if me_type != 0xc0
                    writemidi(smf, UInt8[message, byte1, byte2])
                else
                    writemidi(smf, UInt8[message, byte1])
                end
            end
        end
        smf.next += 1
    end
    writemidi(smf, UInt8[0xfc])
    return 0
end


end
