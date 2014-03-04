#!/bin/sh -u

# $1 can be "set", "counted-set", or "table"

if ((0 == $#)); then
    echo "//  using default \"set\""
    part="set"
else
    if ((1 == $#)); then
        part="$1"
    else
        echo "$0 [ set | counted-set | table ]"
        exit 1;
    fi
fi

if [ -e lib/libdakota.$SO_EXT ]; then
    echo "//  lib/libdakota.$SO_EXT"
    dakota-introspector --only hashed-$part lib/libdakota.$SO_EXT > /tmp/hashed-$part.ctlg
    dakota-introspector --only sorted-$part lib/libdakota.$SO_EXT > /tmp/sorted-$part.ctlg
else
    echo "//  /usr/local/lib/libdakota.$SO_EXT"
    dakota-introspector --only hashed-$part /usr/local/lib/libdakota.$SO_EXT > /tmp/hashed-$part.ctlg
    dakota-introspector --only sorted-$part /usr/local/lib/libdakota.$SO_EXT > /tmp/sorted-$part.ctlg
fi

diff /tmp/hashed-$part.ctlg /tmp/sorted-$part.ctlg
