module midi

const libmidi = joinpath(@__DIR__, Sys.KERNEL == :NT ? "lib/libmidi.dll" :
                                   Sys.KERNEL == :Linux ? "lib/libmidi.so" : "lib/libmidi.dylib")

function midiopen(device="")
    ccall((:midiopen, libmidi),
          Nothing,
          (Ptr{UInt8}, ),
          device)
end
export midiopen

function midiwrite(buffer)
    nbytes = length(buffer)
    ccall((:midiwrite, libmidi),
          Nothing,
          (Ptr{UInt8}, Int32),
          convert(Vector{UInt8}, buffer), nbytes)
end
export midiwrite

function mididataset1(address, data)
    ccall((:mididataset1, libmidi),
          Nothing,
          (Int32, Int32),
          address, data)
end
export mididataset1

function midiread()
    timestamp = Cuint[0]
    event = Cuint[0]
    ccall((:midiread, libmidi),
          Nothing,
          (Ptr{UInt32}, Ptr{UInt32}),
          timestamp, event)
    return timestamp[1], event[1]
end
export midiread

function midiclose()
    ccall((:midiclose, libmidi),
          Nothing,
          (),
          )
end
export midiclose

function midisystemload()
    return ccall((:midisystemload, libmidi),
                 Float32,
                 (),
                 )
end
export midisystemload

end
