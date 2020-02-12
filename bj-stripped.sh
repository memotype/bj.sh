#!/usr/bin/env bash
# bj.sh is a Bash library for parsing JSON. https://github.com/memotype/bj.sh
# Copyright Isaac Freeman (memotype@gmail.com), licensed under the MIT license
bj() (
  [[ $1 = - ]] || exec <<<"$1"
  shift
  c=
  rd() {
    l=$c
    IFS= read -rd '' -n1 c
  }
  pr() {
    printf "%s" "${o[@]}"
  }
  st() {
    o=()
    while rd; do
      case "$l$c" in
        \\?) o+=("$c"); c=c ;;
        ?\\) : ;;
        ?\") break ;;
        *) o+=("$c") ;;
      esac
    done
  }
  ob() {
    bl=1
    while rd; do
      [[ ! $q ]] && o+=("$l")
      case "$c" in
        {) ((bl++)) ;;
        \})
          ((bl--))
          [[ $bl = 0 ]] && {
            [[ $q ]] && return 1
            o+=(})
            break
          }
        ;;
        \") [[ $q ]] && { st; k=$(pr); } ;;
        :) [[ $q && $k = "$q" ]] && return ;;
      esac
    done
  }
  lt() {
    [[ $q = 0 ]] && return
    n=0 bl=1
    while rd; do
      [[ ! $q ]] && o+=("$l")
      case "$bl$c" in
        ?[|?{) ((bl++)) ;;
        ?}) ((bl--)) ;;
        ?])
          ((bl--))
          [[ $bl = 0 ]] && {
            [[ $q ]] && return 1
            o+=(])
            break
          }
        ;;
        1,)
          ((n++))
          [[ $n = "$q" ]] && break
        ;;
      esac
    done
  }
  vl() {
    o=()
    while
      rd \
        && o+=("$l") \
        && [[ $c =~ $1 ]]
    do :;done
  }
  for q in "$@" ""; do
    [[ $q ]] && x=1
    f= o=()
    while rd; do
      case $c in
        [[:space:]]) : ;;
        \") st; f=1 ;;
        t|f|n) vl "[a-z]"; f=1 ;;
        -|[0-9]) vl "[-0-9\.eE\+]"; f=1 ;;
        {) ob && f=1 ;;
        [) lt && f=1 ;;
        *) return 2 ;;
      esac
      [[ $f ]] && { x=0; break; }
    done
  done
  pr
  return $x
)
if ((${#BASH_SOURCE[@]}<=1)) && ! [[ $- =~ i ]]; then
  bj "$@"
  c=$?
  echo
  exit $c
fi
