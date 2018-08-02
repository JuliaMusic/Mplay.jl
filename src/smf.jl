module smf

using ..midi

export readsmf, play, fileinfo, songinfo, beatinfo, lyrics, chordinfo,
       setsong, channelinfo, setchannel, cpuload
export midi

@static if VERSION > v"0.7.0-"
    function dec(n::Int, pad::Int=0)
        string(n, pad=pad)
    end
end

const debug = false
const gm1 = true

const instruments = (
    "Piano 1", "Piano 2", "Piano 3", "Honky-tonk",
    "E.Piano 1", "E.Piano 2", "Harpsichord", "Clav.",
    "Celesta", "Glockenspl", "Music Box", "Vibraphone",
    "Marimba", "Xylophone", "Tubularbell", "Santur",
    "Organ 1", "Organ 2", "Organ 3", "Church Org1",
    "Reed Organ", "Accordion F", "Harmonica", "Bandoneon",
    "Nylon Gt.", "Steel Gt.", "Jazz Gt.", "Clean Gt.",
    "Muted Gt.", "OverdriveGt", "Dist.Gt.", "Gt.Harmonix",
    "Acoustic Bs", "Fingered Bs", "Picked Bass", "Fretless Bs",
    "Slap Bass 1", "Slap Bass 2", "Syn.Bass 1", "Syn.Bass 2",
    "Violin", "Viola", "Cello", "Contrabass",
    "Tremolo Str", "Pizzicato", "Harp", "Timpani",
    "Strings", "SlowStrings", "SynStrings1", "SynStrings2",
    "Choir Aahs", "Voice Oohs", "SynVox", "Orchest.Hit",
    "Trumpet", "Trombone", "Tuba", "MuteTrumpet",
    "French Horn", "Brass 1", "Syn.Brass 1", "Syn.Brass 2",
    "Soprano Sax", "Alto Sax", "Tenor Sax", "BaritoneSax",
    "Oboe", "EnglishHorn", "Bassoon", "Clarinet",
    "Piccolo", "Flute", "Recorder", "Pan Flute",
    "Bottle Blow", "Shakuhachi", "Whistle", "Ocarina",
    "Square Wave", "Saw Wave", "SynCalliope", "ChifferLead",
    "Charang", "Solo Vox", "5th Saw", "Bass & Lead",
    "Fantasia", "Warm Pad", "Polysynth", "Space Voice",
    "Bowed Glass", "Metal Pad", "Halo Pad", "Sweep Pad",
    "Ice Rain", "Soundtrack", "Crystal", "Atmosphere",
    "Brightness", "Goblin", "Echo Drops", "Star Theme",
    "Sitar", "Banjo", "Shamisen", "Koto",
    "Kalimba", "Bagpipe", "Fiddle", "Shanai",
    "Tinkle Bell", "Agogo", "Steel Drums", "Woodblock",
    "Taiko", "Melo. Tom 1", "Synth Drum", "Reverse Cym",
    "Gt.FretNoiz", "BreathNoise", "Seashore", "Bird",
    "Telephone 1", "Helicopter", "Applause", "Gun Shot")

const families = (
    "Piano", "Chromatic Percussion", "Organ", "Guitar",
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
    status::Int
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
end


function StandardMidiFile()
    if VERSION > v"0.7.0-"
        ev = Array{Array{Any}}(undef,0)
        channel = Array{Any}(undef,16)
    else
        ev = Array{Array{Any}}(0)
        channel = Array{Any}(16)
    end
    smf = SMF("", 0, 0, zeros(UInt8,0), 1, ev, 0, 0, 1,
              0, -1, 0, 0, 0, 384, 120, 0, "", "", "", [], div(60000000,120),
              4, 4, 24, 8, 8, 0, 2, channel)
    for ch in 1:16
        smf.channel[ch] = Dict(:used => false,
                               :muted => false,
                               :name => "",
                               :instrument => 0,
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
    end
    smf
end


function bytes(smf, n)
    smf.mf[smf.off : smf.off + n - 1]
end

function extractbyte(smf)
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
            if smf.mf[smf.off] & 0x80 != 0
                smf.off += 1
            else
                break
            end
        end
    else
        value = smf.mf[smf.off]
    end
    smf.off += 1
    value
end

function readevents(smf)
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
                    println(dec(at, 6), " Meta Event 0xi", hex(me_type, 2),
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
                    if state in [0, 1]
                        if chan != 9
                            s = " (" * notes[byte1 % 12 + 1] *
                                string(div(byte1, 12)) * ")"
                        else
                            s = " (" * drum_instruments[byte1 + 1] * ")"
                        end
                    else
                        s = ""
                    end
                    if state in [0, 1, 2, 3, 6]
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


function fileinfo(smf)
    hsecs = div(round(Int, smf.playing_time), 10)
    secs = div(hsecs, 100)
    mins = div(secs, 60)
    secs %= 60
    hsecs %= 100
    string(rpad(smf.path, 12), "     Format:  $(smf.format)     Tracks:  $(smf.tracks)   Playing Time:  ", dec(mins, 2), ":", dec(secs, 2), ".", dec(hsecs, 2), "     Key:  ", lpad(keys[smf.key + 7 + 1], 2), modes[smf.mode + 1], "/", rpad(smf.key_shift, 3))
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
    string("Clock:  ", dec(mins, 2), ":", dec(secs, 2), ".", dec(hsecs, 2), "   Song Position:  ", dec(div(div(ticks, smf.division), 4) + 1, 4), ":", dec(div(ticks, smf.division) % smf.numerator + 1, 2), ":", dec(div(ticks * 1000, smf.division) % 1000, 3), "   Tempo:  ", lpad(dec(smf.bpm), 3), " bpm   Time:  ", dec(smf.numerator, 2), "/", dec(smf.denominator, 2), "  ", dec(smf.clocks_per_beat, 2), "/", dec(smf.notes_per_quarter, 2))
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
    for channel = 0:15
        info = smf.channel[channel + 1]
        if channel != 9 && info[:family] != "Bass"
            for note in info[:notes]
                keys_pressed |= (1 << (note % 12))
            end
        end
    end
    if VERSION > v"0.7.0-"
        bits = digits(keys_pressed, base=2)
    else
        bits = digits(keys_pressed, 2)
    end
    if count(!iszero, bits) in [3, 4, 5]
        for key = 0:11
            if keys_pressed in chords.keys
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


function writemidi(smf, buf)
    start = 1
    if !gm1 && buf[1] < 0xf0
        if buf[1] == smf.status
            start += 1
        else
            smf.status = buf[1]
        end
    end
    midiwrite(buf[start:end])
    if debug
        s = sep = ""
        for byte in buf[start:end]
            s *= sep * "0x" * hex(byte, 2)
            sep = " "
        end
        println(round(time() - smf.start, 4), " ", s)
    end
end


function allnotesoff(smf, channel)
    for note in smf.channel[channel + 1][:notes]
        writemidi(smf, [0x80 + channel, note, 0])
    end
    smf.channel[channel + 1][:notes] = []
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
        for ch = 0:15
            allnotesoff(smf, ch)
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
        for ch = 0:15
            allnotesoff(smf, ch)
        end
        songposition(smf, beat)
        if smf.pause != 0
            smf.pause = time()
        end
    elseif haskey(info, :action)
        if info[:action] == :exit
            for ch = 0:15
                allnotesoff(smf, ch)
            end
            midiclose()
        elseif info[:action] == :pause
            if smf.pause == 0
                smf.pause = time()
                writemidi(smf, [0xfc])
                for ch = 0:15
                    allnotesoff(smf, ch)
                end
            else
                smf.elapsed_time += time() - smf.pause
                smf.pause = 0
                writemidi(smf, [0xfb])
            end
        end
    end
end


function channelinfo(smf, channel)
    smf.channel[channel + 1]
end


function setchannel(smf, channel; info...)
    info = Dict(info)
    if haskey(info, :muted)
        smf.channel[channel + 1][:muted] = info[:muted]
        if info[:muted]
            allnotesoff(smf, channel)
        end
    elseif haskey(info, :solo)
        for ch = 0:15
            smf.channel[ch + 1][:muted] = ch != channel
            if smf.channel[ch + 1][:muted]
                allnotesoff(smf, ch)
            end
        end
    elseif haskey(info, :level)
        smf.channel[channel + 1][:level] = info[:level]
        writemidi(smf, [0xb0 + channel, 7, info[:level]])
    elseif haskey(info, :sense)
        smf.channel[channel + 1][:sense] = info[:sense]
        block = (1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 10, 11, 12, 13, 14, 15)
        mididataset1(0x40101a + block[channel + 1] << 8, info[:sense])
        sleep(0.04)
    elseif haskey(info, :delay)
        smf.channel[channel + 1][:delay] = info[:delay]
        writemidi(smf, [0xb0 + channel, 94, info[:delay]])
    elseif haskey(info, :chorus)
        smf.channel[channel + 1][:chorus] = info[:chorus]
        writemidi(smf, [0xb0 + channel, 93, info[:chorus]])
    elseif haskey(info, :reverb)
        smf.channel[channel + 1][:reverb] = info[:reverb]
        writemidi(smf, [0xb0 + channel, 91, info[:reverb]])
    elseif haskey(info, :pan)
        smf.channel[channel + 1][:pan] = info[:pan]
        writemidi(smf, [0xb0 + channel, 10, info[:pan]])
    elseif haskey(info, :instrument)
        smf.channel[channel + 1][:instrument] = info[:instrument]
        smf.channel[channel + 1][:name] = instruments[info[:instrument] + 1]
        writemidi(smf, [0xc0 + channel, info[:instrument]])
    end
end


function timing(smf, at)
    if at >= smf.midi_clock
        writemidi(smf, [0xf8])
        smf.midi_clock += div(smf.division, 24)
    end
end


function cpuload()
    return midisystemload()
end


function play(smf)
    if smf.start < 0
        midiopen()
        mididataset1(0x400130, 0x04)   # Hall 1
        mididataset1(0x40007f, 0x00)   # GS Reset
        sleep(0.04)
        smf.start = time()
        writemidi(smf, [0xfc, 0xfa])
        smf.elapsed_time = smf.start
        smf.line = ""
    end
    if smf.pause != 0
        return 0.04
    end
    for ev in smf.ev[smf.next:end]
        at, message, byte1, byte2 = ev
        now = time() - smf.elapsed_time
        while at > now * smf.division * 1000000 / smf.tempo
            timing(smf, at)
            delta = (at - now * smf.division * 1000000 / smf.tempo) / 1000
            delta = min(delta, 1.0 / (smf.division / 24))
            return delta
        end
        timing(smf, at)
        smf.at = at
        if message == 0xff
            (at, message, me_type, data) = ev
            if me_type == 0x05
                if data[1] in [13, 10]
                    smf.line = ""
                else
                    if data[end] in [13, 10]
                        smf.text = smf.line * printable(data[:end])
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
            info = smf.channel[channel + 1]
            info[:used] = true
            if me_type in [0x80, 0x90] && channel != 9
                byte1 += smf.key_shift
            end
            if me_type == 0x80
                if byte1 in info[:notes]
                    info[:notes] = setdiff(info[:notes], byte1)
                end
                info[:velocity] = 0
            elseif me_type == 0x90
                if byte2 != 0
                    if byte1 in info[:notes]
                        println("Note retriggered")
                    else
                        info[:notes] = [info[:notes]; byte1]
                    end
                    if !info[:muted]
                        info[:intensity] = byte2
                    end
                elseif byte1 in info[:notes]
                    info[:notes] = setdiff(info[:notes], byte1)
                end
                info[:velocity] = byte2
            elseif me_type == 0xb0
                if byte1 == 0
                    info[:variation] = byte2
                elseif byte1 == 32
                    byte2 = 2
                elseif byte1 == 7
                    info[:level] = byte2
                elseif byte1 == 10
                    info[:pan] = byte2
                elseif byte1 == 91
                    info[:reverb] = byte2
                elseif byte1 == 93
                    info[:chorus] = byte2
                elseif byte1 == 94
                    info[:delay] = byte2
                end
            elseif me_type == 0xc0
                info[:name] = instruments[byte1 + 1]
                info[:instrument] = byte1
                info[:family] = families[div(byte1, 8) + 1]
            end
            if !info[:muted]
                if me_type != 0xc0
                    writemidi(smf, [message, byte1, byte2])
                else
                    writemidi(smf, [message, byte1])
                end
            end
        end
        smf.next += 1
    end
    writemidi(smf, [0xfc])
    return 0
end


end
