#!/bin/bash

### example
### sh server_alloc/start.sh node1 1

## NodeName = node1
## ServerNo = 1

### so we can use getenv in skynet
export NodeName=$1
export ServerNo=$2

### check valid for NodeName, ServerNo
if [[ "x$NodeName" == "x" || "x$ServerNo" == "x" ]]
then
    echo "You must set NodeName and ServerNo"
    exit
fi

echo "NodeName = $NodeName, ServerKind = server_alloc, ServerNo = $ServerNo"

### so we can distinguish different skynet processes
../skynet/skynet server_alloc/config.lua $NodeName $ServerNo
