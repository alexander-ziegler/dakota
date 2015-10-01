#!/bin/bash

# check that obj/%.cc has one more line than %.dk


exit_val=0

paths=$(echo obj/*.cc)
for ccfile in $paths; do
    base=$(basename $ccfile .cc)
    dkfile="$base.dk"
    dkfile_lines=($(wc -l $dkfile))
    ccfile_lines=($(wc -l $ccfile))
    dkfile_lines=${dkfile_lines[0]}
    ccfile_lines=${ccfile_lines[0]}
    if (( $dkfile_lines != $ccfile_lines - 1 )); then
        echo "ERROR: rewriting modified the number of lines in traslation unit: $dkfile: $dkfile_lines != $ccfile_lines - 1" >&2
        exit_val=1
    fi
done

exit $exit_val
