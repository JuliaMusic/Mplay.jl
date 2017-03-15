module midi

const libmidi = Sys.KERNEL == :NT ? "libmidi.dll" : "libmidi.dylib"

function midiopen(device="")
    ccall((:midiopen, libmidi),
          Void,
          (Ptr{UInt8}, ),
          device)
end
export midiopen

function midiwrite(buffer)
    nbytes = length(buffer)
    ccall((:midiwrite, libmidi),
          Void,
          (Ptr{UInt8}, Int32),
          convert(Vector{UInt8}, buffer), nbytes)
end
export midiwrite

function mididataset1(address, data)
    ccall((:mididataset1, libmidi),
          Void,
          (Int32, Int32),
          address, data)
end
export mididataset1

function midiclose()
    ccall((:midiclose, libmidi),
          Void,
          (),
          )
end
export midiclose

end
