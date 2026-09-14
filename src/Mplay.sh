#!/bin/bash

function realpath {
    local r=$1; local t=$(readlink "$r")
    while [ "$t" ]; do
        r=$(cd "$(dirname "$r")" && cd "$(dirname "$t")" && pwd -P)/$(basename "$t")
        t=$(readlink "$r")
    done
    echo "$r"
}

MPLAY_HOME=$(dirname "$(realpath "$0")")
julia="${JULIA:-julia}"
exec "$julia" "$MPLAY_HOME/Mplay.jl" "$@"
