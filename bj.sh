#!/usr/bin/env bash
# bj.sh is a Bash library for parsing JSON. https://github.com/memotype/bj.sh
# Copyright Isaac Freeman (memotype@gmail.com), licensed under the MIT license

bj() {
  local sre='"(([^\"]|\\.)*)"' bre='[[:space:]]+' wre='[[:space:]]*'
  local j=$1 v= k= n i q; shift

  _bjv() {
    if [[ $1 =~ $2 ]]; then
      v=${BASH_REMATCH[1]}
      ((i+=${#BASH_REMATCH[0]}))
    else
      return 1
    fi
  }

  _bjo() {
    local ol=0 j
    for ((j=0; j<${#1}; j++)); do
      case ${1:$j:1} in
        $2) ((ol++)) ;;
        $3)
          ((ol--))
          ((ol<1)) && break
        ;;
      esac
    done
    v=${1:0:$((j+1))}
    ((i+=${#v}))
  }

  for q in "$@"; do
    n=0
    for ((i=1; i<${#j}; i++)); do
      if [[ ${j:$i} =~ ^$bre ]]; then
        ((i+=${#BASH_REMATCH[0]}-1))
        continue
      elif [[ ${j:0:1} = '[' ]]; then
        k=$((n++))
      elif [[ ${j:$i} =~ ^$sre$wre:$wre ]]; then
        k=${BASH_REMATCH[1]}
        ((i+=${#BASH_REMATCH[0]}))
      else
        return 1
      fi

      : "x${j:$i}x"
      : case ${j:$i:1} in
      case ${j:$i:1} in
        '"') _bjv "${j:$i}" "^$sre" ;;
        [0-9]*) _bjv "${j:$i}" '^([0-9]*)' ;;
        t|f|n) _bjv "${j:$i}" '^(true|false|null)' ;;
        '{') _bjo "${j:$i}" '{' '}' ;;
        '[') _bjo "${j:$i}" '[' ']' ;;
      esac

      if [[ ${j:$i} =~ ^$wre,$wre ]]; then
        ((i+=${#BASH_REMATCH[0]}-1))
      elif [[ ${j:$i} =~ ^$wre'}'$wre ]]; then
        ((i+=${#BASH_REMATCH[0]}-1))
        break
      fi

      if [[ $k = "$q" ]]; then
        break
      fi
    done
    j=$v
  done

  unset _bjv _bjo
  echo "$v"
}

if (( ${#BASH_SOURCE[@]} <= 1 )); then
  if [[ $1 =~ --? ]]; then
    shift
    args=("$(</dev/stdin)" "$@")
  else
    args=("$@")
  fi

  bj "${args[@]}"
fi
