#!/bin/bash

function realpath {
    local r=$1; local t=$(readlink $r)
    while [ $t ]; do
        r=$(cd $(dirname $r) && cd $(dirname $t) && pwd -P)/$(basename $t)
        t=$(readlink $r)
    done
    echo $r
}

MPLAY_HOME=$(dirname $(realpath "$0"))
julia="${JULIA:-julia}"

function usage()
{
    echo "Mplay [-h|--help] [--device=midi-device] [--gui] midi-file"
}

device="scva"
interface="tui"
file=""

while :; do
    case $1 in
        -h | -\? | --help)
            usage
            exit
            ;;
        --device=?*)
            device=${1#*=}
            ;;
        --gui)
            interface="Mplay"
            ;;
        -*)
            usage
            exit 1
            ;;
        *)
            file="$@"
            break
            ;;
    esac
    shift
done

if [ "$file" == "" ]; then
    usage
    exit 1
fi

env MIDI_DEVICE=${device} ${julia} ${MPLAY_HOME}/${interface}.jl "${file}"
