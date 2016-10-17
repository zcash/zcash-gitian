#!/bin/sh
OPTIONS=`vagrant ssh-config zcash-build | awk -v ORS=' ' '{print "-o " $1 "=" $2}'`
scp ${OPTIONS} "$@" || echo "Transfer failed."
