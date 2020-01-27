#!/usr/bin/env bash
# bj.sh is a Bash library for parsing JSON. https://github.com/memotype/bj.sh
# Copyright Isaac Freeman (memotype@gmail.com), licensed under the MIT license

bj() {
  local i b s=() v

  for q in "${@:2}"; do
    for (( i=0; i<${#1}; i++ )); do
      case ${1:$i:1} in
        \")
          b=$i
          (( i++ ))
          while [[ ${1:$i:1} != \" ]]; do
            (( i++ ))
            [[ ${1:$i:1} = \\ ]] \
              && (( i+=2 ))
          done
          v=${1:$b:$i}\"
        ;;
        \{)
          
      esac
    done
  done
}
