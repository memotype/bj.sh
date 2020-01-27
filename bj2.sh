#/usr/bin/env bash
# bj.sh is a Bash library for parsing JSON. https://github.com/memotype/bj.sh
# Copyright Isaac Freeman (memotype@gmail.com), licensed under the MIT license

bj() {
  # Matching brackets
  declare -A bs=(['[']=] ['{']=})
  # Define regexes in variables because quoting is tricky in [[ =~ ]]
  local gre='^[[:space:]]+(.*)' wre='[[:space:]]*' ore='^(\[|\{)' \
    xre='([eE][+-]?[0-9]+)?)'
  local sre=^$wre'"(([^\"]|\\.)*)"' bre="^$wre(true|false|null)" \
    fre=$wre'(,|\}|$)'$wre nre='^(-?(0|[1-9][0-9]*)(\.[0-9]+)?'$xre
  # v="json value" k="json key" n="json array index"
  # i="json string pointer" q="query key" ol="object level/depth"
  # l="object parsing pointer" b1="open bracket [/{" b2="closing bracket ]/}"
  # x="the value we're looking for (x marks the spot)" c="return code"
  # s="skip forward amount"
  local v= k= n i=0 q ol l b1 b2 c s
  shift

  # Skip leading whitespace
  [[ $1 =~ $wre ]] \
    && ((i+=${#BASH_REMATCH[0]}))

  for ((; 1<${#1}; i++)); do
    for q; do
      n=0 #c=1 s=0

      ### Parse (k)ey
      # If beginning of current value is a list, set 'k' to list index
      if [[ ${1:$i:1} = '[' ]]; then
        k=$((n++))

      # Otherwise, set 'k' to object key
      elif [[ ${1:$i} =~ $sre$wre:$wre ]]; then
        k=${BASH_REMATCH[1]}
        ((i+=${#BASH_REMATCH[0]}))

