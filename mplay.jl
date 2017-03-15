import GLFW

using OpenGL
using smf

const MUTE_ON_OFF = Dict{Char, Any}(
    'b' => ["Bass"], 'g' => ["Guitar"],
    'k' => ["Piano", "Organ", "Strings", "Ensemble"])

const SOLO_ON = Dict{Char, Any}(
    'B' => ["Bass"], 'G' => ["Guitar"],
    'K' => ["Piano", "Organ", "Strings", "Ensemble"])

const shortcuts = Dict{Int, Char}(
    GLFW.KEY_ESCAPE => '\e',
    GLFW.KEY_TAB => '\t',
    GLFW.KEY_UP => '+' ,
    GLFW.KEY_DOWN => '-' ,
    GLFW.KEY_LEFT => ',' ,
    GLFW.KEY_RIGHT => '.' )

type Player
    win::Any
    midi::Any
    muted::Array{Bool,1}
    solo::Array{Bool,1}
    width::Int
    height::Int
    button::Bool
    selection::Int
    pause::Bool
end

player = nothing

function MidiPlayer(win, path, width, height)
    Player(win, readsmf(path), falses(16), falses(16),
           width, height, false, -1, false)
end

function read_image(path)
    f = open(path)
    readline(f)  # magic number
    width, height = [parse(Int, s) for s in split(readline(f)[1:end])]
    readline(f)  # number of colors
    img = read(f)
    close(f)
    img = flipdim(reshape(img, width*3, height), 2)
    width, height, img
end

function copy_pixels(tox, toy, w, h, fromx, fromy)
    glEnable(GL_TEXTURE_2D)
    glBegin(GL_QUADS)
    glTexCoord2i(fromx, fromy)
    glVertex2i(tox, toy)
    glTexCoord2i(fromx+w, fromy)
    glVertex2i(tox+w, toy)
    glTexCoord2i(fromx+w, fromy+h)
    glVertex2i(tox+w, toy+h)
    glTexCoord2i(fromx, fromy+h)
    glVertex2i(tox, toy+h)
    glEnd()
    glDisable(GL_TEXTURE_2D)
end

function draw_text(x, y, s, color=0)
    for c in s
        row = div(Int(c), 16)
        if Int(c) > 127
            row -= 2
        end
        fromx, fromy = (Int(c) % 16 * 7 + 770, 424 - row * 14)
        fromy += [0, -168, 168][color + 1]
        copy_pixels(x, y, 7, 12, fromx, fromy)
        x += 7
    end
end

function draw_line(x1, y1, x2, y2)
    glBegin(GL_LINES)
    glVertex2i(x1, y1)
    glVertex2i(x2, y2)
    glEnd()
end

function paint_knob(centerx, centery, value)
    angle = pi * (value - 64) / 64 * 0.75
    offx, offy = 9 * sin(angle), 9 * cos(angle)
    x, y = (centerx + round(Int, offx), centery + round(Int, offy))
    draw_line(centerx, centery + 9, x, y + 9)
end

function draw_rect(x, y, width, height)
    glColor3d(0.71, 0.83, 1)
    glBegin(GL_QUADS)
    glVertex2i(x, y)
    glVertex2i(x + width, y)
    glVertex2i(x + width, y + height)
    glVertex2i(x, y + height)
    glEnd()
    glColor3d(1, 1, 1)
end

function paint_notes(notes)
    key = (2, 10, 20, 33, 39, 57, 66, 76, 86, 94, 107, 113)
    for note in notes
        x = 312 + key[note % 12 + 1]
        if (note % 12) in [1, 3, 6, 8, 10]
            draw_rect(x, 48, 7, 24)
        else
            draw_rect(x, 14, 10, 24)
        end
    end
end

function update(player)
    copy_pixels(0, 0, 730, 650, 0, 0)
    for channel in 0:15
        color = channel != player.selection ? 0 : 2
        info = channelinfo(player.midi, channel)
        x = 10 + channel * 38
        if info[:used]
            name = channel != 9 ? info[:name] : "Drums"
            draw_text(620, 562 - channel * 14, name, color)
            if player.muted[channel + 1]
                copy_pixels(x - 6, 633, 31, 11, 735, 633)
            end
            if player.solo[channel + 1]
                copy_pixels(x - 6, 619, 31, 10, 735, 619)
            end
        end
        paint_knob(x + 9, 581, info[:sense])
        draw_text(x, 559, lpad(info[:sense], 3), color)
        paint_knob(x + 9, 523, info[:delay])
        draw_text(x, 501, lpad(info[:delay], 3), color)
        paint_knob(x + 9, 465, info[:chorus])
        draw_text(x, 443, lpad(info[:chorus], 3), color)
        paint_knob(x + 9, 407, info[:reverb])
        draw_text(x, 386, lpad(info[:reverb], 3), color)
        pan = info[:pan]
        paint_knob(x + 9, 349, pan)
        lr = "L R"[sign(pan - 64) + 2]
        draw_text(x, 327, string(lr, lpad(abs(pan - 64), 2)), color)
        if info[:used]
            draw_text(x, 310, lpad(info[:instrument], 3), color)
            draw_text(x - 5, 295, lpad(info[:variation], 2), color)
            draw_text(x, 204, lpad(info[:level], 3), color)
            copy_pixels(x + 13, 295, 12, 15, 754, 295)
            level = info[:level]
        else
            level = 0
        end
        copy_pixels(x - 6, 204, 12, 91, 4, 204)
        copy_pixels(x - 6, 219 + div(level, 2), 12, 11, 735, 225)
        copy_pixels(x + 13, 219, 12, div(info[:intensity], 2), 754, 219)
        if info[:intensity] >= 2
            info[:intensity] -= 2
        else
            info[:intensity] = 0
        end
    end

    draw_text(15, 177, fileinfo(player.midi))
    draw_text(15, 162, songinfo(player.midi))
    draw_text(15, 142, lyrics(player.midi), 1)
    chord, notes = chordinfo(player.midi)
    draw_text(15, 120, chord)
    paint_notes(notes)
    ticker = "            Julia MIDI Player (c) 2017 by Josef Heinen "
    beat = beatinfo(player.midi)
    shift = beat % length(strip(ticker)) + 1
    if shift + 12 < length(ticker)
        draw_text(630, 628, ticker[shift: shift + 12])
    end
    for led in 0:3
        if beat % 4 == led
            copy_pixels(632 + led * 20, 309, 16, 30, 770, 585)
        end
    end
    if player.pause
        copy_pixels(665, 251, 10, 10, 850, 604)
    else
        copy_pixels(665, 251, 10, 10, 860, 604)
    end
    draw_rect(10, 2, round(Int, 710 * player.midi.at / player.midi.atend), 3)
end

function change_mute_state(player, channel)
    setchannel(player.midi, channel, muted=player.muted[channel + 1])
end

function change_solo_state(player, channel)
    player.solo[channel + 1] = !player.solo[channel + 1]
    if player.solo[channel + 1]
        setchannel(player.midi, channel, solo=player.solo[channel])
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

function char_callback(_, key)
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
    elseif contains("1234567890!@#\$%^", string(key))
        channel = search("1234567890!@#\$%^", key) - 1
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
        setsong(player.midi, bar=-1)
    elseif key == '.'
        setsong(player.midi, bar=+1)
    end
end

function key_callback(win, key, scancode, action, mods)
    if action == GLFW.PRESS
        if haskey(shortcuts, key)
            char_callback(win, shortcuts[key])
        end
    end
end

function mouse_button_callback(win, button, action, mods)
    x, y = GLFW.GetCursorPos(win)
    player.button = button == GLFW.MOUSE_BUTTON_1 && action == GLFW.PRESS
    x, y = round(Int, x), round(Int, y)
    if 630 < x < 710 && player.button
        if 360 < y < 370
            setsong(player.midi, bar=-1)
        elseif 390 < y < 400
            setsong(player.midi, action=:pause)
            player.pause = !player.pause
        elseif 420 < y < 430
            setsong(player.midi, bar=+1)
        end
        return
    elseif x >= 608
        return
    end
    channel = div(x, 38)
    info = channelinfo(player.midi, channel)
    if info[:used]
        if player.button
            if 6 < y < 18
                player.muted[channel + 1] = !player.muted[channel + 1]
                change_mute_state(player, channel)
            elseif 20 < y < 32
                change_solo_state(player, channel)
            else
                player.selection = channel
            end
        end
    end
end

function cursor_pos_callback(_, x, y)
    x, y = round(Int, x), round(Int, y)
    if x >= 608
        return
    end
    channel = div(x, 38)
    if player.button
        if 34 <= y < 34 + 5 * 58
            y -= 34
            value = 63.5 + atan2(x % 38 - 19, 17 - y % 58) / pi * 127 / 1.5
            value = trunc(Int, min(max(value, 0), 127))
            knob = div(y, 58)
            if knob == 0
                setchannel(player.midi, channel, sense=value)
            elseif knob == 1
                setchannel(player.midi, channel, delay=value)
            elseif knob == 2
                setchannel(player.midi, channel, chorus=value)
            elseif knob == 3
                setchannel(player.midi, channel, reverb=value)
            elseif knob == 4
                setchannel(player.midi, channel, pan=value)
            end
        elseif 358 < y < 430
            value = trunc(Int, min(max((425 - y) * 2, 0), 127))
            setchannel(player.midi, channel, level=value)
        end
    end
end

function change_instrument(player, value)
    if player.selection
        setchannel(player.midi, player.selection, instrument=value)
    end
    return 0
end

function main(path)
    global player

    GLFW.Init()

    win = GLFW.CreateWindow(730, 650, "MIDI Player")

    GLFW.MakeContextCurrent(win)
    GLFW.ShowWindow(win)

    width, height, img = read_image("mixer.ppm")

    glPixelStorei(GL_UNPACK_ALIGNMENT, 1)
    texture = glGenTextures(1)

    glBindTexture(GL_TEXTURE_2D, texture)
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, width, height, 0,
                 GL_RGB, GL_UNSIGNED_BYTE, img)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)

    glMatrixMode(GL_TEXTURE)
    glLoadIdentity()
    glScaled(1 / width, 1 / height, 1)

    glMatrixMode(GL_PROJECTION)
    glLoadIdentity()
    glOrtho(0, 730, 0, 650, 0, 1)

    GLFW.SetKeyCallback(win, key_callback)
    GLFW.SetCharCallback(win, char_callback)
    GLFW.SetMouseButtonCallback(win, mouse_button_callback)
    GLFW.SetCursorPosCallback(win, cursor_pos_callback)

    player = MidiPlayer(win, path, width, height)

    while !GLFW.WindowShouldClose(win)
        delta = play(player.midi)
        update(player)
        if delta > 0
            sleep(delta)
        end
        if player.midi.at >= player.midi.atend
            break
        end
        GLFW.SwapBuffers(win)
        GLFW.PollEvents()
    end
    GLFW.Terminate()
end

if length(ARGS) > 0
    main(ARGS[1])
end
