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
    fre=$wre'(,|\}|$)'$wre nre='^(-?(0|[1-9][0-9]*)(\.[0-9]+)?'$xre
  # j="json string" v="json value" k="json key" n="json array index"
  # i="json string pointer" q="query key" ol="object level/depth"
  # l="object parsing pointer" b1="open bracket [/{" b2="closing bracket ]/}"
  # x="the value we're looking for (x marks the spot)" c="return code"
  # s="skip forward amount"
  local j=$1 v= k= n i q ol l b1 b2 c s
  shift

  # Drill down based on query arguments
  for q; do
    n=0 c=1 s=0

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
        return 2
      fi

      echo "k=$k"
      echo "($((${#j}-i))) j=${j:$i:60}"

      ### Parse (v)alue
      # String, number or boolean
      if [[ ${j:$i} =~ $sre || ${j:$i} =~ $nre || ${j:$i} =~ $bre ]]; then
        if [[ $k = $q ]]; then
          j=${BASH_REMATCH[1]} c=0
          break
        fi
        # Set scan ahead for next item
        ((i+=${#BASH_REMATCH[0]}))

      # Object/dict or list
      elif [[ ${j:$i} =~ $ore ]]; then
        ol=0
        b1=${BASH_REMATCH[1]}
        b2=${bs[$b1]}
        # Looking for matching '}' or ']'
        echo "Scanning object"
        for ((l="$i"; l<"${#j}"; l++)); do
          case ${j:$l:1} in
            $b1) ((ol++)) ;;
            $b2)
              ((ol--))
              ((ol<1)) && break
            ;;
          esac
        done
        echo "Finished scanning object"
        ((s=l-i+1))
        if [[ $k = $q ]]; then
          j=${j:$i:$s} c=0
          echo "FOUND $j"
          break
        fi
        ((i+=s))
      fi

      # Skip field seperator
      [[ ${j:$i} =~ ^$fre ]] \
        && ((i+=${#BASH_REMATCH[0]}-1))
    done
    #j=$x
  done

  ((c==0)) \
    && echo "$j"
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
