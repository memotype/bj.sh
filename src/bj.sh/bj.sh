#!/usr/bin/env bash
# bj.sh is a Bash library for parsing JSON. https://github.com/memotype/bj.sh
# Copyright Isaac Freeman (memotype@gmail.com), licensed under the MIT license

bj() (
  # If $1 is -, just read from stdin, otherwise we push $1 to stdin.
  # The JSON value is read as a stream of characters from stdin.
  [[ $1 = - ]] || exec <<<"$1"
  shift

  # Some of the global variables used:
  # q="the current query parameter we're looking for"
  # c="the current character" l="the previous value of $c"
  # o="array of 'output' characters, to be joined later (array append + printf
  # is faster than appending to a string one character at a time)"

  # c needs to be initialized because we do l=$c before our first read
  c=

  # Read a character
  rd() {
    l=$c
    IFS= read -rd '' -n1 c
  }

  # Join the characters in the $o array
  pr() {
    # Using ':' with arguments is nice for 'bash -x' debugging
    : : "=== pr()"
    printf "%s" "${o[@]}"
  }


  # Scan strings and save them to $o array (or skip for key scanning).
  st() {
    : : "=== st()"
    p=; p=$1
    [[ ! $p ]] && o=()
    while rd; do
      : : "--- lc=$l$c="
      [[ $p && ! $q ]] && o+=("$l")
      case "$l$c" in
        \\?) [[ $p ]] || { o+=("$c"); c=c; } ;;
        ?\\) : ;;
        ?\") break ;;
        *) [[ $p ]] || o+=("$c") ;;
      esac
    done
  }

  # Scan an object
  ob() {
    : : "=== ob()"
    b=1
    while rd; do
      : : "--- l=$l= c=$c= q=$q= ---"
      [[ ! $q ]] && o+=("$l")
      case "$c" in
        {) ((b++)) ;;
        \})
          ((b--))
          [[ $b = 0 ]] && {
            [[ $q ]] && return 1
            o+=(})
            break
          }
        ;;
        \") [[ $q ]] && { st; k=$(pr); } || st 1 ;;
        # Found the key, just return and let the main loop parse from here
        :) [[ $q && $k = "$q" ]] && return ;;
      esac
    done
  }

  lt() {
    : : "=== lt()"
    [[ $q = 0 ]] && return
    n=0 b=1
    while rd; do
      : : "--- l=$l= c=$c= q=$q= b=$b= ---"
      [[ ! $q ]] && o+=("$l")
      case "$b$c" in
        ?\") st 1 ;;
        ?[|?{) ((b++)) ;; # ]) <- fix vim syntax
        ?}) ((b--)) ;;
        ?])
          ((b--))
          [[ $b = 0 ]] && {
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

  # Simple value parsing (numbers, true/false, etc)
  vl() {
    : : "=== vl() $1"
    o=()
    while
      rd \
        && o+=("$l") \
        && [[ $c =~ $1 ]]
    do :;done
  }

  # Main - scan input for query terms
  for q in "$@" ""; do
    # x="exit code"
    [[ $q ]] && x=1
    : : "--- q=$q"
    f= o=()
    while rd; do
      : : "mn --- l=$l c=$c"
      case $c in
        [[:space:]]) : ;;
        \") st; f=1 ;;
        t|f|n) vl "[a-z]"; f=1 ;;
        -|[0-9]) vl "[-0-9\.eE+]"; f=1 ;;
        {) ob && f=1 ;;
        [) lt && f=1 ;; #])
        *) return 2 ;;
      esac
      # If we (f)ound our key, go to the next
      [[ $f ]] && { x=0; break; }
    done
  done

  # Print whatever we last stored in $o
  pr

  return $x
)

: ENDBJ
  
if ((${#BASH_SOURCE[@]}<=1)) && ! [[ $- =~ i ]]; then
  bj "$@"
  c=$?
  echo
  exit $c
fi