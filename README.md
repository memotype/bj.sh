bj.sh is a pure GNU Bash library for parsing JSON data.
Copyright Isaac Freeman (memotype@gmail.com)

Licensed under the MIT license. See LICENSING.

bj.sh is meant to be run as a script, sourced as a library, or copied directly
in to your script for maximum flexibility. Great for embedded systems, build
automation, or any environment where 'jq' isn't available (Plus, bj.sh is 1/20th
the size of the 'jq' binary)

bj.sh is *NOT* a JSON validator, behavior is undefined if given invalid JSON!
It will detect some basic JSON errors, but this is not the goal of bj.sh.

The entire parser is implemented as a single bash function, so it can be
`source`d in to your own script, or you can just copy and paste the function in
to your script to reduce your external dependencies. `bj-80x15.sh`
(80-characters lines, 15 lines long) and `bj-90x13.sh` are intended for exactly
this.

Usage:

    source bj.sh
    r=$(bj '{"foo": "bar"}' foo)

or

    r=$(./bj.sh '{"foo": "bar"}' foo)

will set $r to "bar" (without the quotes).

Multiple levels of JSON keys can be queried at once, i.e:

    source bj.sh
    json='{"a": {"foo": {"bar": "baz"}}, "b": [27, 42]}'
    bj "$json" a foo bar  # output: baz
    bj "$json" b 1        # output: 42

bj.sh will also return JSON if the value at the query location isn't a leaf node

    json='{"a": {"foo": {"bar": "baz"}}, "b": [27, 42]}'
    bj "$json" a foo      # output: {"bar": "baz"}

The exit code (`$?`) will be 1 if any of the query items weren't found, and 2 if
there was an error parsing the JSON. This can also be useful for iterating over
arrays:

    json='{"a": [42, 69, 420]}'
    i=0
    while r=$(bj "$j" a $i); do
        echo "$r"
        ((i++))
    done

When run as a separate script, if the first argument is "-" or "--", bj.sh will
read from /dev/stdin:

    echo '{"foo": [false, true, false]}' | ./bj.sh - foo 1

will echo "true"

