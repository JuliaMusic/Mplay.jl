module GLFW

const libGLFW = joinpath(@__DIR__, Sys.KERNEL == :NT ? "lib/libglfw.dll" : "lib/libglfw.dylib")

const PRESS = 1
export PRESS

const KEY_ESCAPE = 256
export KEY_ESCAPE
const KEY_TAB = 258
export KEY_TAB
const KEY_RIGHT = 262
export KEY_RIGHT
const KEY_LEFT = 263
export KEY_LEFT
const KEY_DOWN = 264
export KEY_DOWN
const KEY_UP = 265
export KEY_UP

const MOUSE_BUTTON_1 = 0
export MOUSE_BUTTON_1

const Window = Ptr{Cvoid}

const _callback_refs = Vector{Function}(undef, 4)

@static if !isdefined(Base, Symbol("@cfunction"))
    macro cfunction(f, rt, tup)
        :(Base.cfunction($(esc(f)), $(esc(rt)), Tuple{$(esc(tup))...}))
    end
end

function Init()
    ccall((:glfwInit, libGLFW),
          Cvoid,
          ())
end
export Init

function Terminate()
    ccall((:glfwTerminate, libGLFW),
          Cvoid,
          ())
end
export Terminate

function CreateWindow(width::Integer, height::Integer, title::AbstractString)
    window = ccall((:glfwCreateWindow, libGLFW),
                   Ptr{Cvoid},
                   (Cint, Cint, Cstring, Ptr{Cvoid}, Ptr{Cvoid}),
                   width, height, title, C_NULL, C_NULL)
    window
end
export CreateWindow

function MakeContextCurrent(window::Window)
    ccall((:glfwMakeContextCurrent, libGLFW),
          Cvoid,
          (Ptr{Cvoid},),
          window)
end
export MakeContextCurrent

function ShowWindow(window::Window)
    ccall((:glfwShowWindow, libGLFW),
          Cvoid,
          (Ptr{Cvoid},),
          window)
end
export ShowWindow

function SwapBuffers(window::Window)
    ccall((:glfwSwapBuffers, libGLFW),
          Cvoid,
          (Ptr{Cvoid},),
          window)
end
export SwapBuffers

function WindowShouldClose(window::Window)
    return ccall((:glfwWindowShouldClose, libGLFW),
                 Cint,
                 (Ptr{Cvoid},),
                 window)
end
export WindowShouldClose

function PollEvents()
    ccall((:glfwPollEvents, libGLFW),
          Cvoid,
          ())
end
export PollEvents

function GetCursorPos(window::Window)
    xpos = Cdouble[0]
    ypos = Cdouble[0]
    ccall((:glfwGetCursorPos, libGLFW),
          Cvoid,
          (Ptr{Cvoid}, Ptr{Cdouble}, Ptr{Cdouble}),
          window, xpos, ypos)
    return xpos[], ypos[]
end
export GetCursorPos

_KeyCallback(window::Window, key::Cint, scancode::Cint, action::Cint, mods::Cint) = begin
    _callback_refs[1](window, key, scancode, action, mods)
    return nothing
end

function SetKeyCallback(window::Window, callback::Function)
    _callback_refs[1] = callback
    callback_c = @cfunction(_KeyCallback, Cvoid, (Ptr{Cvoid}, Cint, Cint, Cint, Cint))
    ccall((:glfwSetKeyCallback, libGLFW),
          Cvoid,
          (Ptr{Cvoid}, Ptr{Cvoid}),
          window, callback_c)
end
export SetKeyCallback

_CharCallback(window::Window, codepoint::Cuint) = begin
    _callback_refs[2](window, codepoint)
    return nothing
end

function SetCharCallback(window::Window, callback::Function)
    _callback_refs[2] = callback
    callback_c = @cfunction(_CharCallback, Cvoid, (Ptr{Cvoid}, Cuint))
    ccall((:glfwSetCharCallback, libGLFW),
          Cvoid,
          (Ptr{Cvoid}, Ptr{Cvoid}),
          window, callback_c)
end
export SetCharCallback

_MouseButtonCallback(window::Window, button::Cint, action::Cint, mods::Cint) = begin
    _callback_refs[3](window, button, action, mods)
    return nothing
end

function SetMouseButtonCallback(window::Window, callback::Function)
    _callback_refs[3] = callback
    callback_c = @cfunction(_MouseButtonCallback, Cvoid, (Ptr{Cvoid}, Cint, Cint, Cint))
    ccall((:glfwSetMouseButtonCallback, libGLFW),
          Cvoid,
          (Ptr{Cvoid}, Ptr{Cvoid}),
          window, callback_c)
end
export SetMouseButtonCallback

_CursorPosCallback(window::Window, xpos::Cdouble, ypos::Cdouble) = begin
    _callback_refs[4](window, xpos, ypos)
    return nothing
end

function SetCursorPosCallback(window::Window, callback::Function)
    _callback_refs[4] = callback
    callback_c = @cfunction(_CursorPosCallback, Cvoid, (Ptr{Cvoid}, Cdouble, Cdouble))
    ccall((:glfwSetCursorPosCallback, libGLFW),
          Cvoid,
          (Ptr{Cvoid}, Ptr{Cvoid}),
          window, callback_c)
end
export SetCursorPosCallback

end
