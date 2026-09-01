[![Yes, this bizarre 863-byte Bash JSON parser is actually tested.](https://github.com/memotype/bj.sh/actions/workflows/verify.yml/badge.svg)](https://github.com/memotype/bj.sh/actions/workflows/verify.yml)

bj.sh is a pure GNU Bash library for parsing JSON data.
It requires GNU Bash 4.1 or newer.

bj.sh is meant to be run as a script, sourced as a library, or copied directly
in to your script for maximum flexibility. Great for embedded systems, build
automation, or any environment where 'jq' isn't available (Plus, bj.sh is 1/20th
the size of the 'jq' binary)

bj.sh is *NOT* a JSON validator, behavior is undefined if given invalid JSON!
It will detect some basic JSON errors, but this is not the goal of bj.sh. It
also does not support querying empty JSON object member names (e.g.,
`{"": "foo"}`). If your tool/API outputs JSON objects with empty keys, fix it in
your API/tool, or contact your vendor.

The entire parser is implemented as a single bash function, `bj`, so it can be
`source`d in to your own script, or you can just copy and paste the function in
to your script to reduce your external dependencies. `bj-80-col.sh` (80-
character long lines) and `bj-90-col.sh` versions are intended for exactly this.

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

### Output

`bj.sh` returns the text found at the requested key or index. It does not
decode or encode Unicode or other JSON escape sequences. For example, if a
JSON string contains `\n`, `bj.sh` returns the two ASCII characters `\` and
`n`, not a newline. Other escape sequences, such as `\uD83D\uDE00`, are also
returned literally *as is* in the JSON input.

Object member names follow the same rule when matched. A key spelled
`"\u0061"` in the JSON input is queried as `\u0061`, not as the decoded
character `a`.

It is up to the caller to interpret or otherwise handle escape sequences in
the returned text.

### Testing

Parser test cases live in `tests.yml` and are run by `test.rb`. Each case has a
lower-case hyphenated name, JSON input and transport, query terms, expected
output and status, and a user-facing description. Run the catalog against a
specific implementation with:

    ./test.rb -s ./bj.sh

Optional timing cases require `citylots.json` and are included with `-t`.
Repository-level verification, including every generated implementation under
the default locale and `LC_ALL=C`, is run with:

    make verify
