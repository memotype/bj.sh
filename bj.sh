#!/usr/bin/env bash
# bj.sh is a Bash library for parsing JSON. https://github.com/memotype/bj.sh
# Copyright Isaac Freeman (memotype@gmail.com), licensed under the MIT license

bj() {
  # Matching brackets
  declare -A bs=(['[']=] ['{']=})
  # Define regexes in variables because quoting is tricky in [[ =~ ]]
  local gre='^[[:space:]]+(.*)' wre='[[:space:]]*' ore='^(\[|\{)' \
    xre='([eE][+-]?[0-9]+)?)'
  local sre=^$wre'"(([^\"]|\\.)*)"' bre="^$wre(true|false|null)" \
    fre="$wre(,|\\}|\$)$wre" nre='^(-?(0|[1-9][0-9]*)(\.[0-9]+)?'$xre
  # j="json string" v="json value" k="json key" n="json array index"
  # i="json string pointer" q="query key" ol="object level/depth"
  # l="object parsing pointer" b1="open bracket [/{" b2="closing bracket ]/}"
  # x="the value we're looking for (x marks the spot)" c="return code"
  local j=$1 v= k= n i q ol l b1 b2 x c
  shift

  # Drill down based on query arguments
  for q in "$@"; do
    n=0 x= c=1

    # Trim leading whitespace
    [[ ${j:$i} =~ $gre ]] \
      && j=${BASH_REMATCH[1]}

    # Scan characters in current JSON sub-string
    for ((i=1; i<${#j}; i++)); do

      ### Parse (k)ey
      # If beginning of current value is a list, set 'k' to list index
      if [[ ${j:0:1} = '[' ]]; then
        k=$((n++))

      # Otherwise, set 'k' to object key
      elif [[ ${j:$i} =~ $sre$wre:$wre ]]; then
        k=${BASH_REMATCH[1]}
        ((i+=${#BASH_REMATCH[0]}))

      # JSON syntax error
      else
        return 1
      fi

      ### Parse (v)alue
      # String, number or boolean
      if [[ ${j:$i} =~ $sre || ${j:$i} =~ $nre || ${j:$i} =~ $bre ]]; then
        v=${BASH_REMATCH[1]}
        # Scan ahead for next item
        ((i+=${#BASH_REMATCH[0]}))

      # Object/dict or list
      elif [[ ${j:$i} =~ $ore ]]; then
        ol=0
        b1=${BASH_REMATCH[1]}
        b2=${bs[$b1]}
        # Looking for matching '}' or ']'
        for ((l="$i"; l<"${#j}"; l++)); do
          case ${j:$l:1} in
            $b1) ((ol++)) ;;
            $b2)
              ((ol--))
              ((ol<1)) && break
            ;;
          esac
        done
        v=${j:$i:$((l-i+1))}
        ((i+=${#v}))
      fi

      ### Check if we found the query item
      if [[ $k = "$q" ]]; then
        x=$v c=0
        break
      fi

      # Skip field seperator
      if [[ ${j:$i} =~ ^$fre ]]; then
        ((i+=${#BASH_REMATCH[0]}-1))
      fi
    done
    : 'j=$x'
    j=$x
  done

  echo "$x"
  return "$c"
}

: ENDBJ

if (( ${#BASH_SOURCE[@]} <= 1 )); then
  if [[ $1 =~ --? ]]; then
    shift
    args=("$(</dev/stdin)" "$@")
  else
    args=("$@")
  fi

  bj "${args[@]}"
fi
