#!/bin/sh
julia -q --project -e 'using PackageCompiler; create_app(".", "Mplay")'
