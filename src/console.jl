module console

const libconsole = joinpath(@__DIR__, Sys.KERNEL == :NT ? "lib/libconsole.dll" :
                                      Sys.KERNEL == :Linux ? "lib/libconsole.so" : "lib/libconsole.dylib")

function settty()
    ccall((:settty, libconsole),
          Nothing,
          (),
          )
end
export settty

function resettty()
    ccall((:resettty, libconsole),
          Nothing,
          (),
          )
end
export resettty

function kbhit()
    result = ccall((:kbhit, libconsole),
                   Int32,
                   (),
                   )
    result != 0
end
export kbhit

function readchar()
    ccall((:readchar, libconsole),
          UInt32,
          (),
          )
end
export readchar

function outtextxy(x::Int, y::Int, s::AbstractString, color=0)
    ccall((:outtextxy, libconsole),
          Nothing,
          (Int32, Int32, Cstring, Int32),
          x, y, s, color)
end
export outtextxy

function cls()
    ccall((:cls, libconsole),
          Nothing,
          (),
          )
end
export cls

end
