#!/usr/bin/env bash
# bj.sh is a Bash library for parsing JSON. https://github.com/memotype/bj.sh
# Copyright Isaac Freeman (memotype@gmail.com), licensed under the MIT license

bj() (
  set +u

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
  r() {
    l=$c
    IFS= read -rN1 c
  }

  # Join the characters in the $o array
  p() {
    # Using ':' with arguments is nice for 'bash -x' debugging
    : : "=== p()"
    printf %s "${o[@]}"
  }


  # Scan strings, saving to $o unless navigation only needs to skip them.
  s() {
    : : "=== s()"
    p=$1
    [[ $p ]] || o=()
    while r; do
      : : "--- lc=$l$c="
      [[ $p && ! $q ]] && o+=("$l")
      case $c in
        \\)
          r || break
          # Skip while navigating. Otherwise include $c only when capturing.
          [[ $p && $q ]] || o+=("$l${c::!p}")
        ;;
        \") break ;;
        *) [[ $p ]] || o+=("$c") ;;
      esac
    done
  }

  # Scan an object or list. $1 is set when scanning a list.
  co() {
    : : "=== co()"
    n= b=1
    while r; do
      : : "--- l=$l= c=$c= q=$q= b=$b= ---"
      [[ $q ]] || o+=("$l")
      case $c in
        \") [[ $1 || ! $q ]] && s 1 || { s; k=$(p); } ;;
        [|{) ((b++)) ;; # ]) <- fix vim syntax
        ]|\})
          ((--b)) || {
            # bj runs in a subshell, so exit only stops this invocation.
            [[ $q ]] && exit 1
            o+=("$c")
            break
          }
        ;;
        # $1 is set for lists, so $1$b is 1 only at direct object depth.
        # Found the key, just stop and let the main loop parse from here.
        :) [[ $1$b = 1 && $q && $k = "$q" ]] && break ;;
        ,)
          ((0$1 && b==1)) \
            && [[ $q = $((++n)) ]] \
            && break
        ;;
      esac
    done
  }

  # Main - scan input for query terms
  for q in "$@" ""; do
    shift && [[ ! $q ]] && return 2
    # x="success"
    x=0
    : : "--- q=$q"
    o=()
    while r; do
      : : "mn --- l=$l c=$c"
      # Prefix with $q so scalar cases only match during final output.
      case $q$c in
        *[[:space:]]) ! : ;;
        \") s ;;
        [tfn0-9-])
          while o+=("$c") \
            && r \
            && [[ $c =~ [-+.0-9Ea-z] ]]
          do :;done
        ;;
        *{) co ;;
        *[) [[ $q = 0 ]] || co 1 ;; #])
        ?) return 2 ;;
        *) return 1 ;;
      esac && x=1 && break
    done
  done

  # Print whatever we last stored in $o
  p

  ((x))
)

: ENDBJ
  
if ((${#BASH_SOURCE[@]}<=1)) && ! [[ $- =~ i ]]; then
  bj "$@"
  c=$?
  echo
  exit $c
fi
