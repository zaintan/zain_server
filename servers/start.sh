#!/bin/bash
### center server
sh server_center/start.sh node1 0

### alloc server
sh server_alloc/start.sh node1 0

### agent servers
sh server_agent/start.sh node1 0
sh server_agent/start.sh node1 1

### gameservers
sh server_game/start.sh node1 0
sh server_game/start.sh node1 1

