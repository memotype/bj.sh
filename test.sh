#!/usr/bin/env bash

fail() {
  echo "FAIL: $*"
  exit 1
}

src=${1:-bj.sh}
echo "Testing $src"
. "$src"

#set -x

: "-----"

runtest() {
  echo "*** $*"
  ans=$1
  shift
  local r
  r=$(bj "$@")
  c=$?
  echo "r=$r"
  if [[ $r = "$ans" ]]; then
    echo "pass"
  else
    fail "$r != $ans"
  fi
  return "$c"
}

runtest bar '{"foo": "bar"}' foo || fail "bj exit code: $?"

runtest '{"bar": [1, 2, 3]}' '{"a": "b", "foo": {"bar": [1, 2, 3]}}' foo

runtest -2 '{"a": {"b": {"c" : ["d" , "e"]} } ,
"foo" : {"bar": [1.0, -2, 3e45] } }' foo bar 1

# Whitespace test
runtest g '  {   "a"
:  {
"b"  :   {  "c"  :  [  "d"  ,  "e"  ] , "e" : [ "f" , "g" ] } } ,
"foo" : {"bar":
[1, 2, 3] } }  ' a b e 1

runtest true '  [  false, {"thing": [true, false]}]' 1 thing 0

# Array out of bounds test
runtest '' '[0, 1, 2, 3]' 4 \
  && fail "bj didn't set exit code for array index out-of-bounds: $?"

runtest '' '{"a": [0, 1, 2, 3]}' a 4 \
  && fail "bj didn't set exit code for array index out-of-bounds: $?"

runtest 11 '{"a": [0, 1, 2], "b": [10, 11, 12]}' b 1 \
  || fail "bad exit code after valid array index query: $?"

# Nested array tests
runtest 4 '{"a": [0, 1, [2, [3, 4]]]}' a 2 1 1

# Numbers tests
runtest "4.2e10" '[0, -1, 4.2e10]' 2
runtest "-1" '[0, -1, 4.2e10]' 1

#set +x
#time bj "$(< citylots.json)" features 1000
#time bj "$(< citylots.json)" features 413000
