module smf

using Printf

using ..midi

export readsmf, loadarrangement, savearrangement, play,
       fileinfo, songinfo, beatinfo, lyrics, chordinfo, getprogram,
       setsong, partinfo, setpart, allnotesoff, cpuload
export midi

oct(n) = string(n, base=8)

function dec(n::Int, pad::Int=0)
    string(n, pad=pad)
end

function hex(n, pad::Int=0)
    string(n, base=16, pad=pad)
end

debug = false
warnings = false

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

const parameters = (
    :muted, :channel, :instrument, :variation, :level, :pan,
    :reverb, :chorus, :delay, :sense, :shift)

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


mutable struct SMF
    path::AbstractString
    format::Int
    tracks::Int
    mf::Array{UInt8}
    off::Int
    ev::Array{Array{Any}}
    status::UInt8
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
    line::String
    text::String
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
    channel::Array{Any}
    default::Array{Any}
end


function StandardMidiFile()
    ev = Array{Array{Any}}(undef,0)
    channel = Array{Any}(undef,16)
    default = Array{Any}(undef,16)
    smf = SMF("", 0, 0, zeros(UInt8,0), 1, ev, 0x00, 0, 1,
              0, -1, 0, 0, 0, 384, 120, 0, "", "", "", [], div(60000000,120),
              4, 4, 24, 8, 8, 0, 2, channel, default)
    for part in 1:16
        smf.channel[part] = Dict(:used => false,
                                 :muted => false,
                                 :name => "",
                                 :channel => part - 1,
                                 :instrument => 1,
                                 :family => "",
                                 :variation => 0,
                                 :level => 100,
                                 :pan => 64,
                                 :reverb => 40,
                                 :chorus => 0,
                                 :delay => 0,
                                 :sense => 64,
                                 :shift => 64,
                                 :velocity => 0,
                                 :intensity => 0,
                                 :notes => [])
        smf.default[part] = Dict(:muted => -1,
                                 :channel => -1,
                                 :instrument => -1,
                                 :variation => -1,
                                 :level => -1,
                                 :pan => -1,
                                 :reverb => -1,
                                 :chorus => -1,
                                 :delay => -1,
                                 :sense => -1,
                                 :shift => -1)
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
    global debug
    state = 0
    chan = 0
    at = 0
    while true
        delta = extractnumber(smf)
        at += delta
        me = extractbyte(smf)
        if me == 0xf0 || me == 0xf7
            num_bytes = extractnumber(smf)
            smf.off += num_bytes
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
                push!(smf.ev,
                      [at, me, me_type, extractbytes(smf, num_bytes)])
            elseif me_type == 0x20
                byte1 = extractbyte(smf)
                push!(smf.ev, [at, me, me_type, byte1])
                if debug
                    println(dec(at, 6), " Channel Prefix 0x", hex(byte1, 2))
                end
            elseif me_type == 0x21
                byte1 = extractbyte(smf)
                push!(smf.ev, [at, me, me_type, byte1])
                if debug
                    println(dec(at, 6), " Port Number 0x", hex(byte1, 2))
                end
            elseif me_type == 0x2f
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
            row = [parse(Int, x) for x in split(line)]
            for column in 1:11
                smf.default[part][parameters[column]] = row[column]
            end
            line = readline(file)
        end
        close(file)
    end
end


function savearrangement(smf)
    path = replace(smf.path, ".mid" => ".arr")
    file = open(path, "w")
    @printf(file, "#!MPlay\n# M Ch Ins Var Vol Pan Rev Cho Del Sen +/-\n")
    for part = 1:16
        values = [smf.default[part][parameters[column]] for column in 1:11]
        @printf(file, "%3d %2d %3d %3d %3d %3d %3d %3d %3d %3d %3d\n", values...)
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


function lyrics(smf)
    rpad(smf.text, 80)
end


function chordinfo(smf)
    keys_pressed = 0
    for part in 1:16
        info = smf.channel[part]
        if part != 10 && info[:family] != "Bass"
            for note ∈ info[:notes]
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
    channel = smf.channel[part][:channel]
    for note ∈ smf.channel[part][:notes]
        writemidi(smf, UInt8[0x80 + channel, note, 0])
    end
    smf.channel[part][:notes] = []
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
    smf.channel[part]
end


function setpart(smf, part; info...)
    channel = smf.channel[part][:channel]
    info = Dict(info)
    if haskey(info, :muted)
        smf.channel[part][:muted] = info[:muted]
        if info[:muted]
            allnotesoff(smf, part)
        end
    elseif haskey(info, :level)
        smf.channel[part][:level] = info[:level]
        smf.default[part][:level] = info[:level]
        writemidi(smf, UInt8[0xb0 + channel, 7, info[:level]])
    elseif haskey(info, :sense)
        smf.channel[part][:sense] = info[:sense]
        smf.default[part][:sense] = info[:sense]
        mididataset1(0x40101a + block[part] << 8, info[:sense])
        sleep(0.04)
    elseif haskey(info, :shift)
        allnotesoff(smf, part)
        smf.channel[part][:shift] = info[:shift]
        smf.default[part][:shift] = info[:shift]
        mididataset1(0x401016 + block[part] << 8, info[:shift])
        sleep(0.04)
    elseif haskey(info, :delay)
        smf.channel[part][:delay] = info[:delay]
        smf.default[part][:delay] = info[:delay]
        writemidi(smf, UInt8[0xb0 + channel, 94, info[:delay]])
    elseif haskey(info, :chorus)
        smf.channel[part][:chorus] = info[:chorus]
        smf.default[part][:chorus] = info[:chorus]
        writemidi(smf, UInt8[0xb0 + channel, 93, info[:chorus]])
    elseif haskey(info, :reverb)
        smf.channel[part][:reverb] = info[:reverb]
        smf.default[part][:reverb] = info[:reverb]
        writemidi(smf, UInt8[0xb0 + channel, 91, info[:reverb]])
    elseif haskey(info, :pan)
        smf.channel[part][:pan] = info[:pan]
        smf.default[part][:pan] = info[:pan]
        writemidi(smf, UInt8[0xb0 + channel, 10, info[:pan]])
    elseif haskey(info, :instrument)
        name, program, variation = instruments[info[:instrument]]
        smf.channel[part][:instrument] = info[:instrument]
        smf.channel[part][:name] = name
        writemidi(smf, UInt8[0xb0 + channel, 0x20, gm1 ? 0x00 : 0x02]) # 0=default, 1=SC-55, 2=SC-88
        writemidi(smf, UInt8[0xb0 + channel, 0x00, variation])
        writemidi(smf, UInt8[0xc0 + channel, program])
        smf.default[part][:instrument] = program
        smf.default[part][:variation] = variation
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
        if info[:notes] == [] || info[:muted]
            if info[:intensity] >= 2
                info[:intensity] -= 2
            else
                info[:intensity] = 0
            end
        end
    end
end


function play(smf, device="")
    global debug
    if smf.start < 0
        midiopen(device)
        mididataset1(0x400130, 0x04)   # Hall 1
        mididataset1(0x40007f, 0x00)   # GS Reset
        sleep(0.04)
        smf.start = time()
        writemidi(smf, UInt8[0xfc, 0xfa])
        for part in 1:16
            arr = smf.default[part]
            if arr[:instrument] != -1 && arr[:variation] != -1
                instrument = getinstrument(part, arr[:instrument], max(arr[:variation], 0))
                setpart(smf, part, instrument=instrument)
            end
            if arr[:level] != -1 setpart(smf, part, level=arr[:level]) end
            if arr[:pan] != -1 setpart(smf, part, pan=arr[:pan]) end
            if arr[:reverb] != -1 setpart(smf, part, reverb=arr[:reverb]) end
            if arr[:chorus] != -1 setpart(smf, part, chorus=arr[:chorus]) end
            if arr[:delay] != -1 setpart(smf, part, delay=arr[:delay]) end
        end
        smf.elapsed_time = smf.start
        smf.line = ""
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
            smf.next += 1
            return 0
        elseif message == 0xff
            at, message, me_type, data = ev
            if me_type == 0x05
                if data[1] ∈ (13, 10)
                    smf.line = ""
                else
                    if data[end] ∈ (13, 10)
                        smf.text = smf.line * printable(data[1:end-1])
                        smf.line = ""
                    else
                        smf.line *= printable(data)
                        smf.text = smf.line
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
            info = smf.channel[part]
            info[:used] = true
            default = smf.default[part]
            if me_type ∈ (0x80, 0x90) && info[:channel] != 9
                byte1 += smf.key_shift
            end
            if me_type == 0x80
                if byte1 in info[:notes]
                    info[:notes] = setdiff(info[:notes], byte1)
                end
                info[:velocity] = 0
            elseif me_type == 0x90
                if byte2 != 0
                    if byte1 ∈ info[:notes]
                        if debug println("Note retriggered") end
                    else
                        info[:notes] = [info[:notes]; byte1]
                    end
                    if !info[:muted]
                        info[:intensity] = byte2
                    end
                elseif byte1 ∈ info[:notes]
                    info[:notes] = setdiff(info[:notes], byte1)
                end
                info[:velocity] = byte2
            elseif me_type == 0xb0
                if byte1 == 0
                    default[:variation] != -1 && (byte2 = default[:variation])
                    program = info[:instrument]
                    getinstrument(part, program, byte2) == program && (byte2 = 0)
                    info[:variation] = byte2
                elseif byte1 == 32
                    byte2 = gm1 ? 0 : 2 # 0=default, 1=SC-55, 2=SC-88
                elseif byte1 == 7
                    default[:level] != -1 && (byte2 = default[:level])
                    info[:level] = byte2
                elseif byte1 == 10
                    default[:pan] != -1 && (byte2 = default[:pan])
                    info[:pan] = byte2
                elseif byte1 == 91
                    default[:reverb] != -1 && (byte2 = default[:reverb])
                    info[:reverb] = byte2
                elseif byte1 == 93
                    default[:chorus] != -1 && (byte2 = default[:chorus])
                    info[:chorus] = byte2
                elseif byte1 == 94
                    default[:delay] != -1 && (byte2 = default[:delay])
                    info[:delay] = byte2
                end
            elseif me_type == 0xc0
                default[:instrument] != -1 && (byte1 = default[:instrument])
                byte2 = max(default[:variation], 0)
                instrument = getinstrument(part, byte1, byte2)
                info[:name] = instruments[instrument][1]
                info[:instrument] = instrument
                info[:family] = families[div(byte1, 8) + 1]
            end
            if !info[:muted] && default[:muted] ∈ (-1, 0)
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
