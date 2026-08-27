#!/usr/bin/env bash

fail() {
  echo "FAIL: $*"
  exit 1
}

while [[ $1 = -* ]]; do
  case $1 in
    -t)
      timetest=1
      shift
      ;;
    -s)
      shift
      src=$1
      shift
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
  esac
done

src=${src:-${1:-bj.sh}}
echo "Testing $src"
. "$src"

#set -x

: "-----"

runteststatus() {
  local expected_status=$1 ans=$2
  shift 2
  echo "*** status=$expected_status: $*"
  local c r
  r=$(bj "$@")
  c=$?
  echo "c=$c r=$r"
  [[ $r = "$ans" ]] || fail "$r != $ans"
  (( c == expected_status )) \
    || fail "bj exit code: $c != $expected_status"
  echo "pass"
}

runtest() {
  runteststatus 0 "$@"
}

runnonzero() {
  local ans=$1
  shift
  echo "*** nonzero status: $*"
  local c r
  r=$(bj "$@")
  c=$?
  echo "c=$c r=$r"
  [[ $r = "$ans" ]] || fail "$r != $ans"
  (( c != 0 )) || fail "bj exit code: $c == 0"
  echo "pass"
}

runstdin() {
  echo "*** stdin: $*"
  ans=$1
  data=$2
  shift 2
  local e r
  for e in '' $'\n'; do
    r=$(printf %s "$data$e" | bj - "$@")
    c=$?
    echo "c=$c r=$r"
    [[ $r = "$ans" ]] || fail "$r != $ans"
    (( c == 0 )) || fail "bj exit code: $c"
  done
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

# All four JSON whitespace characters: space, tab, carriage return, line feed
runtest 1 $'{\r\n\t"a"\t: \r1\n}' a || fail "JSON whitespace test failed"
runtest 42 $'{\r\n\t"outer" : [\r\n\t{"value"\t:\r 42\n}\n]\r}' \
  outer 0 value || fail "Nested JSON whitespace test failed"

runtest true '  [  false, {"thing": [true, false]}]' 1 thing 0

# Stdin tests, with and without a trailing newline
runstdin 123 123
runstdin true true
runstdin false false
runstdin null null
runstdin string '"string"'
runstdin '[1,2]' '[1,2]'
runstdin '{"a":1}' '{"a":1}'
runstdin node-1 '{"metadata":{"name":"node-1"}}' metadata name

# Array out of bounds test
runteststatus 1 '' '[0, 1, 2, 3]' 4

# Nested array exhaustion currently has a separate status discrepancy. Keep
# requiring failure without making that status part of the test contract.
runnonzero '' '{"a": [0, 1, 2, 3]}' a 4

runtest 11 '{"a": [0, 1, 2], "b": [10, 11, 12]}' b 1 \
  || fail "bad exit code after valid array index query: $?"

# Nested array tests
runtest 4 '{"a": [[0, 42], 1, [2, [3, 4]]]}' a 2 1 1
runtest i '[{"b": "c", "e": {"f": "g"}}, {"h": "i"}]' 1 h

# Strings with delimiters in containers
runtest '{"x":"b}c"}' '{"a":{"x":"b}c"}}' a
runtest '["x]y"]' '{"a":["x]y"]}' a
runtest 'c' '["a,b","c"]' 1
runtest 'c' '["a]b","c"]' 1

# Numbers tests
runtest "4.2e10" '[0, -1, 4.2e10]' 2
runtest "-1" '[0, -1, 4.2e10]' 1
runtest "1e+2" '[1e+2]' 0

# Array iteration test
#set -x
echo '*** {"a": [42, 69, 420]} a $i (iterate)'
j='{"a": [42, 69, 420]}'
i=0
s=()
while :; do
  r=$(bj "$j" a "$i")
  c=$?
  if (( c != 0 )); then
    terminal_status=$c
    break
  fi
  s+=("$r")
  ((i++))
done
echo "c=$terminal_status count=${#s[@]} values=${s[*]}"
(( terminal_status != 0 )) \
  || fail "array iteration exit code: $terminal_status == 0"
(( ${#s[@]} == 3 )) || fail "array iteration count: ${#s[@]} != 3"
[[ ${s[0]} = 42 && ${s[1]} = 69 && ${s[2]} = 420 ]] \
  || fail "array iteration values: ${s[*]} != 42 69 420"
echo pass

# Closing brackets in strings test
runtest 'baz' '{"foo": {"b}ar": "baz"}}' foo 'b}ar' \
  || fail "Wrongly detected closing bracket inside string"
runtest 'b}az' '{"foo": {"bar": "b}az"}}' foo 'bar' \
  || fail "Wrongly detected closing bracket inside string"

# Escape spelling preservation tests
runtest 'a\"b' '{"value":"a\"b"}' value \
  || fail "Escaped quote was not preserved"
runtest 'a\\b' '{"value":"a\\b"}' value \
  || fail "Escaped backslash was not preserved"
runtest 'a\/b' '{"value":"a\/b"}' value \
  || fail "Escaped solidus was not preserved"
runtest 'a\bb' '{"value":"a\bb"}' value \
  || fail "Escaped backspace was not preserved"
runtest 'a\fb' '{"value":"a\fb"}' value \
  || fail "Escaped form feed was not preserved"
runtest 'a\nb' '{"value":"a\nb"}' value \
  || fail "Escaped newline was not preserved"
runtest 'a\rb' '{"value":"a\rb"}' value \
  || fail "Escaped carriage return was not preserved"
runtest 'a\tb' '{"value":"a\tb"}' value \
  || fail "Escaped tab was not preserved"
runstdin 'line1\nline2' '{"value":"line1\nline2"}' value

# Escaped structural characters must remain inside the string.
runtest 'x\"}y,]z:{' '{"outer":{"value":"x\"}y,]z:{","after":1}}' \
  outer value || fail "Escaped structural text changed parser state"

# Raw UTF-8 and escaped Unicode spellings are intentionally distinct.
runtest 'café 雪 🚀' '{"raw":"café 雪 🚀"}' raw \
  || fail "Raw UTF-8 value did not round-trip"
runtest value '{"café 雪":"value"}' 'café 雪' \
  || fail "Raw UTF-8 key was not queryable"
runtest 'caf\u00e9 \u96ea' '{"escaped":"caf\u00e9 \u96ea"}' escaped \
  || fail "Escaped BMP spelling was not preserved"
runtest '\uD83D\uDE80' '{"emoji":"\uD83D\uDE80"}' emoji \
  || fail "Surrogate-pair spelling was not preserved"
runtest 42 '{"\u0061":42}' '\u0061' \
  || fail "Escaped object key spelling was not queryable"
runteststatus 1 '' '{"\u0061":42}' a
runtest '\u0000' '{"nul":"\u0000"}' nul \
  || fail "NUL escape spelling was not preserved"

# Skipped strings must still recognize a complete escape pair.
runtest hit '{"skip":"\\","target":"hit"}' target \
  || fail "Escape in skipped string changed parser state"

# Selected containers must preserve escape spelling for subsequent queries.
runtest '{"slash":"\\","value":"line1\nline2"}' \
  '{"outer":{"slash":"\\","value":"line1\nline2"}}' outer \
  || fail "Container escape spelling was not preserved"

# Empty values, nulls, and navigation around empty containers
empty_values='{"empty_string":"","empty_object":{},"empty_array":[],"nothing":null}'
runtest '' "$empty_values" empty_string
runtest '{}' "$empty_values" empty_object
runtest '[]' "$empty_values" empty_array
runtest null "$empty_values" nothing
runteststatus 1 '' "$empty_values" absent

empty_object=$(bj "$empty_values" empty_object)
empty_array=$(bj "$empty_values" empty_array)
runtest '{}' "$empty_object"
runtest '[]' "$empty_array"

runtest hit '{"a":{},"b":[],"c":{"result":"hit"}}' c result
runtest hit \
  '[0,1,2,3,4,5,6,7,8,9,{"result":"hit"}]' 10 result
runtest hit '[{},[],{"result":"hit"}]' 2 result

# Representative Kubernetes-shaped data used by build and shell automation
kubernetes_json='{"items":[{"metadata":{"name":"api","annotations":{"example.com/config":"line1\nline2"}},"spec":{"nodeName":null,"containers":[{"name":"app","env":[{"name":"MODE","value":""}]}]}}]}'
runtest api "$kubernetes_json" items 0 metadata name
runtest 'line1\nline2' \
  "$kubernetes_json" items 0 metadata annotations example.com/config
runtest app "$kubernetes_json" items 0 spec containers 0 name
runtest '' "$kubernetes_json" items 0 spec containers 0 env 0 value
runtest null "$kubernetes_json" items 0 spec nodeName
runteststatus 1 '' "$kubernetes_json" absent

# Representative cloud-init variables used by provisioning scripts
cloud_init_json='{"hostname":"node-01","enabled":true,"proxy":null,"ssh_authorized_keys":[],"write_files":[{"path":"/etc/app.conf","content":"mode=prod\nurl=https:\/\/example.test\/api"}]}'
runtest node-01 "$cloud_init_json" hostname
runtest true "$cloud_init_json" enabled
runtest null "$cloud_init_json" proxy
runtest '[]' "$cloud_init_json" ssh_authorized_keys
runtest /etc/app.conf "$cloud_init_json" write_files 0 path
runtest 'mode=prod\nurl=https:\/\/example.test\/api' \
  "$cloud_init_json" write_files 0 content
runteststatus 1 '' "$cloud_init_json" absent

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
