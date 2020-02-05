#!/usr/bin/env bash
# bj.sh is a Bash library for parsing JSON. https://github.com/memotype/bj.sh
# Copyright Isaac Freeman (memotype@gmail.com), licensed under the MIT license

bj() (
  # Push $1 to stdin, the JSON value is read as a stream of characters
  exec <<<"$1"
  shift

  # Some of global variables used:
  # c="the current character" l="the last (previous) character that was seen"
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
    : : "=== pr()"
    printf "%s" "${o[@]}"
  }


  # Scan strings and optionally save them to $o array if $1 is set
  st() {
    : : "=== st()"
    #[[ $1 ]] && o=()
    o=()
    while rd; do
      case "$l$c" in
        \\?) #[[ $1 ]] && \
          o+=("$c") ;;
        ?\\) : ;;
        ?\") break ;;
        *) #[[ $1 ]] && \
          o+=("$c") ;;
      esac
    done
  }

  # Scan an object
  ob() {
    : : "=== ob()"
    bl=1
    while rd; do
      : : "--- l=$l= c=$c= q=$q= ---"
      [[ ! $q ]] && o+=("$l")
      # We match on $b1 and $c so the action can depend if we're processing an
      # array or an object
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
        \") [[ $q ]] && { st 1; k=$(pr); } ;;
        # Found the key, just return and let the main loop parse from here
        :) [[ $q && $k = "$q" ]] && return ;;
        ,) k= ;;
      esac
    done
  }

  lt() {
    : : "=== lt()"
    [[ $q = 0 ]] && return
    n=0 bl=1
    while rd; do
      : : "--- l=$l= c=$c= q=$q= bl=$bl= ---"
      [[ ! $q ]] && o+=("$l")
      case "$bl$c" in
        ?[|?{) # ])
          ((bl++))
        ;;
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

  # Numeric parsing
  nm() {
    : : "=== nm()"
    o=()
    while
      rd \
        && o+=("$l") \
        && [[ $c =~ [-0-9\.eE\+] ]]
    do :;done
  }

  tf() {
    : : "=== tf()"
    o=()
    while
      rd \
        && o+=("$l") \
        && [[ $c =~ [a-z] ]]
    do :; done
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
        \") st 1; f=1 ;;
        t|f|n) tf; f=1 ;;
        -|[0-9]) nm; f=1 ;;
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

if ((${#BASH_SOURCE[@]}<1)); then
  if [[ $1 =~ ^--?$ ]]; then
    shift
    args=("$(</dev/stdin)" "$@")
  else
    args=("$@")
  fi
  
  bj "${args[@]}"
  c=$?
  echo
  exit $c
fi
