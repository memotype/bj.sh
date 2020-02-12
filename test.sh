#!/usr/bin/env bash

fail() {
  echo "FAIL: $*"
  exit 1
}

if [[ $1 = '-t' ]]; then
  timetest=1
  shift
fi

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
  echo "c=$c r=$r"
  if [[ $r = "$ans" ]]; then
    echo "pass"
  else
    fail "$r != $ans"
  fi
  return "$c"
}

runtest bar '{"foo": "bar"}' foo || fail "bj exit code: $?"

runtest '{"bar": [1, 2, 3]}' '{"a": "b", "foo": {"bar": [1, 2, 3]}}' foo

runtest 'baz' \
  '{"a": {"b": "c"}, "d": {"e": {"f": "g"}, "h": "i"}, "foo": {"bar": "baz"}}' \
  foo bar

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
runtest 4 '{"a": [[0, 42], 1, [2, [3, 4]]]}' a 2 1 1
runtest i '[{"b": "c", "e": {"f": "g"}}, {"h": "i"}]' 1 h

# Numbers tests
runtest "4.2e10" '[0, -1, 4.2e10]' 2
runtest "-1" '[0, -1, 4.2e10]' 1

# Array iteration test
#set -x
echo '*** {"a": [42, 69, 420]} a $i (iterate)'
j='{"a": [42, 69, 420]}'
i=0
s=()
while r=$(bj "$j" a $i); do
  s=("$r" "${s[@]}")
  ((i++))
done

# Closing brackets in strings test
runtest 'baz' '{"foo": {"b}ar": "baz"}}' foo 'b}ar' \
  || fail "Wrongly detected closing bracket inside string"
runtest 'b}az' '{"foo": {"bar": "b}az"}}' foo 'bar' \
  || fail "Wrongly detected closing bracket inside string"

# Escapes in string test
runtest '"foo" bar' '{"a": "\"", "foo": "\"foo\" bar"}' foo
runtest '\foo\ bar' '{"a": "\\", "foo": "\\foo\\ bar"}' foo

if (( timetest )); then
  set +x
  echo '*** time r=$(bj "$(< citylots.json)" features 1000 geometry coordinates 0 0 1)'
  time r=$(bj "$(< citylots.json)" features 1000 geometry coordinates 0 0 1)
  echo "r=$r"
  if [[ $r = 37.805335380794915 ]]; then
    echo pass
  else
    echo "FAIL: $r != 37.805335380794915"
  fi

  echo '*** time r=$(bj - features 1000 geometry coordinates 0 0 1 <citylots.json)'
  time r=$(bj - features 1000 geometry coordinates 0 0 1 <citylots.json)
  echo "r=$r"
  if [[ $r = 37.805335380794915 ]]; then
    echo pass
  else
    echo "FAIL: $r != 37.805335380794915"
  fi
  
  time bj - features 413000 <citylots.json
  time jq '.features[413000]' <citylots.json
fi
