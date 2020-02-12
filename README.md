bj.sh is a pure GNU Bash library for parsing JSON data.

bj.sh is meant to be run as a script, sourced as a library, or copied directly
in to your script for maximum flexibility. Great for embedded systems, build
automation, or any environment where 'jq' isn't available (Plus, bj.sh is 1/20th
the size of the 'jq' binary)

bj.sh is *NOT* a JSON validator, behavior is undefined if given invalid JSON!
It will detect some basic JSON errors, but this is not the goal of bj.sh.

The entire parser is implemented as a single bash function, so it can be
`source`d in to your own script, or you can just copy and paste the function in
to your script to reduce your external dependencies. `bj-80x13.sh` (80-character
lines, 13 lines long) and `bj-90x12.sh` (90-character lines, 12 lines long)
versions are intended for exactly this.

### Usage

Called as an external script:

    bj.sh [DATA] [QUERY ...]


Sourced or copied in to your script:

    source bj.sh
    bj [DATA] [QUERY ...]

DATA can be a JSON string, or `-`. If DATA is `-`, JSON data is read
from stdin.

QUERY terms are the keys and indexes you want to query from the JSON data.

### Examples

    source bj.sh
    r=$(bj '{"foo": {"bar": "baz"}}' foo bar)

`r` will be set to the string `baz`.

    r=$(curl https://myapi.example.com/api/call | bj - nodes 0)

Assuming the api call returns something like `{"nodes": ["node0", "node1"]}`,
this will set `r` to `node0`. To get the list of nodes and iterate over them:

    nodes=$(curl https://myapi.example.com/api/call | bj - nodes)
    i=0
    while node=$(bj "$nodes" "$i"); do
        ping -c1 "$node"
        (( i++ ))
    done

`bj` will return the JSON data at the key if it's not a leaf node, so the first
call returns `["node0", "node1"]`. Also, `bj` will exit with a code of 1 if the
queried key or index doesn't exist. So, when `$i` is `2`, `bj` will return 1,
breaking out of the `while` loop.
