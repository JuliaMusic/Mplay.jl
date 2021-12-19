module Mplay

include("GLFW.jl")
include("OpenGL.jl")
include("midi.jl")
include("smf.jl")
include("keys.jl")

using .GLFW

using .OpenGL
using .midi
using .smf
using .keys

include("player.jl")

const shortcuts = Dict(
    GLFW.KEY_ESCAPE => Int('\e'),
    GLFW.KEY_TAB => Int('\t'),
    GLFW.KEY_UP => KEY_UP,
    GLFW.KEY_DOWN => KEY_DOWN,
    GLFW.KEY_LEFT => KEY_LEFT,
    GLFW.KEY_RIGHT => KEY_RIGHT )

function read_image(path)
    f = open(path)
    readline(f)  # magic number
    width, height = [parse(Int, s) for s in split(readline(f)[1:end])]
    readline(f)  # number of colors
    img = read(f)
    close(f)
    img = reverse(reshape(img, width*3, height), dims=2)
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

function showlyrics(smf)
    if 1 <= smf.line <= length(smf.lyrics)
        draw_text(15, 147, rpad(smf.lyrics[smf.line], 80), 1)
        column = smf.column > 1 ? smf.column - length(smf.text) : smf.column
        draw_text(15 + (column - 1) * 7, 147, rstrip(smf.text), 2)
        draw_text(15, 132, rpad(smf.line < length(smf.lyrics) ? smf.lyrics[smf.line + max(smf.skiplines, 1)] : "", 80), 1)
    end
end

function update(player)
    copy_pixels(0, 0, 730, 650, 0, 0)
    for part in 1:16
        color = part != player.selection ? 0 : 2
        info = partinfo(player.midi, part)
        x = 10 + (part - 1) * 38
        if info.used
            draw_text(620, 562 - (part - 1) * 14, info.name, player.parameter == 1 ? color : 0)
            if player.muted[part]
                copy_pixels(x - 6, 633, 31, 11, 735, 633)
            end
            if player.solo[part]
                copy_pixels(x - 6, 619, 31, 10, 735, 619)
            end
        end
        paint_knob(x + 9, 581, info.sense)
        draw_text(x, 559, lpad(info.sense, 3), player.parameter == 7 ? color : 0)
        paint_knob(x + 9, 523, info.delay)
        draw_text(x, 501, lpad(info.delay, 3), player.parameter == 6 ? color : 0)
        paint_knob(x + 9, 465, info.chorus)
        draw_text(x, 443, lpad(info.chorus, 3), player.parameter == 5 ? color : 0)
        paint_knob(x + 9, 407, info.reverb)
        draw_text(x, 386, lpad(info.reverb, 3), player.parameter == 4 ? color : 0)
        pan = info.pan
        paint_knob(x + 9, 349, pan)
        lr = "L R"[sign(pan - 64) + 2]
        draw_text(x, 327, string(lr, lpad(abs(pan - 64), 2)), player.parameter == 3 ? color : 0)
        if info.used
            program, variation = getprogram(info.instrument)
            draw_text(x, 310, lpad(program, 3), player.parameter == 1 ? color : 0)
            draw_text(x - 5, 295, lpad(variation, 2), player.parameter == 1 ? color : 0)
            draw_text(x, 204, lpad(info.level, 3), player.parameter == 2 ? color : 0)
            copy_pixels(x + 13, 295, 12, 15, 754, 295)
            level = info.level
        else
            level = 0
        end
        copy_pixels(x - 6, 217, 12, 78, 4, 217)
        copy_pixels(x - 6, 219 + div(level, 2), 12, 11, 735, 225)
        copy_pixels(x + 13, 219, 12, div(info.intensity, 2), 754, 219)
    end

    draw_text(15, 177, fileinfo(player.midi))
    draw_text(15, 162, songinfo(player.midi))
    showlyrics(player.midi)
    chord, notes = chordinfo(player.midi)
    draw_text(15, 117, chord)
    paint_notes(notes)
    text = "Julia MIDI Player  @ 2018-2020 by Josef Heinen"
    scrolling_text = " " ^ 12 * text * " "
    scrolling_text = unsafe_wrap(Array{UInt8, 1}, pointer(scrolling_text),
                                 length(scrolling_text))
    scrolling_text[32] = 0xa8  # @ => © (Latin-1)
    beat = beatinfo(player.midi)
    shift = beat % length(text) + 1
    if shift + 12 < length(scrolling_text)
        draw_text(630, 628, scrolling_text[shift: shift + 12])
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
    draw_text(695, 177, "CPU")
    draw_rect(703, 120, 5, round(Int, 50 * cpuload()))
end

function char_callback(_, key)
    key = Char(key)
    dispatch(player, key)
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
    elseif 620 < x < 720
        if 76 < y < 300
            player.selection = div(y - 76, 14) + 1
        end
        return
    elseif x >= 608
        return
    end
    part = div(x, 38) + 1
    info = partinfo(player.midi, part)
    if info.used
        if player.button
            if 6 < y < 18
                player.muted[part] = !player.muted[part]
                change_mute_state(player, part)
            elseif 20 < y < 32
                change_solo_state(player, part)
            else
                player.selection = part
            end
        end
    end
end

function cursor_pos_callback(_, x, y)
    x, y = round(Int, x), round(Int, y)
    if x >= 608
        return
    end
    part = div(x, 38) + 1
    if player.button
        if 34 <= y < 34 + 5 * 58
            y -= 34
            value = 63.5 + atan(x % 38 - 19, 17 - y % 58) / pi * 127 / 1.5
            value = trunc(Int, min(max(value, 0), 127))
            knob = div(y, 58)
            if knob == 0
                setpart(player.midi, part, sense=value)
            elseif knob == 1
                setpart(player.midi, part, delay=value)
            elseif knob == 2
                setpart(player.midi, part, chorus=value)
            elseif knob == 3
                setpart(player.midi, part, reverb=value)
            elseif knob == 4
                setpart(player.midi, part, pan=value)
            end
        elseif 358 < y < 430
            value = trunc(Int, min(max((425 - y) * 2, 0), 127))
            setpart(player.midi, part, level=value)
        end
    end
end

function mplay(path, device="")
    global player

    GLFW.Init()

    win = GLFW.CreateWindow(730, 650, "MIDI Player")

    GLFW.MakeContextCurrent(win)
    GLFW.ShowWindow(win)

    width, height, img = read_image(joinpath(@__DIR__, "mixer.ppm"))

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

    player = MidiPlayer(path)

    while GLFW.WindowShouldClose(win) == 0
        delta = play(player.midi, device)
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

export mplay

function main()
    if length(ARGS) > 0
        path = ARGS[1]
        device = haskey(ENV, "MIDI_DEVICE") ? ENV["MIDI_DEVICE"] : ""
        mplay(path, device)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

end #module
