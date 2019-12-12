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
to your script to reduce your external dependencies. `bj-small.sh` is intended
for exactly this.

Usage:

    source bj.sh
    r=$(bj '{"foo": "bar"}' foo)

or

    r=$(./bj.sh '{"foo": "bar"}' foo)

will set $r to "bar" (without the quotes). If the first argument is "-" or "--",
bj.sh will read from /dev/stdin:

    echo '{"foo": [false, true, false]}' | ./bj.sh - foo 1

will echo "true"

