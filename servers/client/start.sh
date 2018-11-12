#!/bin/bash

### example
### sh client/start.sh tzy

export platformID=$1

if [[ "x$platformID" == "x" ]]
then
    echo "You must set client platformID"
    exit
fi

echo "start client/start.sh $platformID "

../skynet/skynet client/config.lua $platformID

