#!/usr/bin/env bash

fail() {
  echo "${@:-fail}"
  exit 1
}

src=${1:-bj.sh}
. "$src"

#set -x

: "-----"

r=$(bj '{"foo": "bar"}' foo)
echo "*** $r"
[[ $r = bar ]] || fail

r=$(bj '{"a": "b", "foo": {"bar": [1, 2, 3]}}' foo)
echo "*** $r"
[[ $r = '{"bar": [1, 2, 3]}' ]] || fail

r=$(bj '{"a": {"b": {"c" : ["d" , "e"]} } ,
"foo" : {"bar": [1.0, -2, 3e45] } }' foo bar 1)
echo "*** $r"
[[ $r = -2 ]] || fail

r=$(bj '{"a": {"b": {"c" : ["d" , "e"] , "e" : [ "f" , "g" ] } } ,
"foo" : {"bar":
[1, 2, 3] } }' a b e 1)
echo "*** $r"
[[ $r = g ]] || fail

r=$(bj '[false, {"thing": [true, false]}]' 1 thing 0)
echo "*** $r"
[[ $r = true ]] || fail

#set +x
#time bj "$(< citylots.json)" features 1000
#time bj "$(< citylots.json)" features 413000
