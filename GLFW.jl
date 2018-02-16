module GLFW

const libGLFW = "/usr/local/lib/libglfw.dylib"

@static if VERSION < v"0.7.0-DEV.3137"
  const Cvoid = Void
end

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
const _callback_refs = Dict{Ptr, Any}()

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

function SetKeyCallback(window::Window, callback::Function)
    callback_c = cfunction(callback, Cvoid, Tuple{Ptr{Cvoid}, Cint, Cint, Cint, Cint})
    _callback_refs[callback_c] = callback
    ccall((:glfwSetKeyCallback, libGLFW),
          Cvoid,
          (Ptr{Cvoid}, Ptr{Cvoid}),
          window, callback_c)
end
export SetKeyCallback

function SetCharCallback(window::Window, callback::Function)
    callback_c = cfunction(callback, Cvoid, Tuple{Ptr{Cvoid}, Cuint})
    _callback_refs[callback_c] = callback
    ccall((:glfwSetCharCallback, libGLFW),
          Cvoid,
          (Ptr{Cvoid}, Ptr{Cvoid}),
          window, callback_c)
end
export SetCharCallback

function SetMouseButtonCallback(window::Window, callback::Function)
    callback_c = cfunction(callback, Cvoid, Tuple{Ptr{Cvoid}, Cint, Cint, Cint})
    _callback_refs[callback_c] = callback
    ccall((:glfwSetMouseButtonCallback, libGLFW),
          Cvoid,
          (Ptr{Cvoid}, Ptr{Cvoid}),
          window, callback_c)
end
export SetMouseButtonCallback

function SetCursorPosCallback(window::Window, callback::Function)
    callback_c = cfunction(callback, Cvoid, Tuple{Ptr{Cvoid}, Cdouble, Cdouble})
    _callback_refs[callback_c] = callback
    ccall((:glfwSetCursorPosCallback, libGLFW),
          Cvoid,
          (Ptr{Cvoid}, Ptr{Cvoid}),
          window, callback_c)
end
export SetCursorPosCallback

end
