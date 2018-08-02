module midi

const libmidi = Sys.KERNEL == :NT ? "lib/libmidi.dll" : "lib/libmidi.dylib"

@static if VERSION < v"0.7.0-DEV.3137"
  const Nothing = Void
end

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
