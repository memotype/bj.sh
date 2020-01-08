#!/usr/bin/env bash
# rollup.sh is a script to condense scripts. https://github.com/memotype/bj.sh
# Copyright Isaac Freeman (memotype@gmail.com), licensed under the MIT license
# Usage:
#  rollup.sh [input path] [output path]
# If no input path or output path are given, assume stdin and stdout. Input
# path can be "-" to imply stdin.

# grep PCREs to extract things like strings to protect them from later
# transformations. They will be replaced with random UUIDs and re-inserted
# after everything else.
pre_re=(
  "'[^']*'"
  '"(?:[^"\\]|\\.)*"'
  '\\;'
)

# sed -E commands to run after the lines are combined in to one by semicolons.
# The combined line will begin with a semicolon to make matching the beginning
# of commands simpler.
sed_expr=(
  -e 's/[[:space:]]+/ /g'
  -e 's/; /;/g'
  -e 's/ *\{;/{ /g'
  -e 's/ *&& */\&\&/g'
  -e 's/;then;/;then /g'
  -e 's/;else;/;else /g'
  -e 's/;case ([^ ]*) in *; */;case \1 in /g'
  -e 's/;do;/;do /g'
  -e 's/ *;;;* */;;/g'
  -e 's/; *([^\(\)]*\))[ ;]*/;\1/g'
  -e 's/;: ENDBJ.*//'

  # Remove first and last semicolon
  -e 's/^;//'
  -e 's/;$//'
)

## Main logic

infile=${1:--}

# Trim end code and remove comments and blank lines
script=$(grep -v '^ *#\|^ *$' "$infile")
#script=${script%%: ENDBJ*}

declare -A strings
find_strings() {
  local str_id match
  while IFS= read -rd '' match; do
    str_id=$(</proc/sys/kernel/random/uuid)
    strings[$str_id]=$match
    script=${script/"$match"/"$str_id"}
  done < <(grep -ozP "(s?)$1" <<< "$script")
}

for re in "${pre_re[@]}"; do
  find_strings "$re"
done

# Debug
#echo "$script"
#for str_id in "${!strings[@]}"; do
#  echo "$str_id - ${strings[$str_id]}"
#done

## Remove comments, combine lines with semicolons, then run sed transformations
script=$(
  awk '/\\$/ {gsub(/\\$/,""); printf $0; next} {printf "%s;",$0}' \
      <<<";$script" \
  | sed -E "${sed_expr[@]}"
)

## Put the strings back in
for str_id in "${!strings[@]}"; do
  script=${script/"$str_id"/"${strings[$str_id]}"}
done

outfile=${2:-/dev/stdout}
echo "# (C) Isaac Freeman (memotype@gmail.com)." \
  "See https://github.com/memotype/bj.sh" \
  >"$outfile"
echo "$script" >>"$outfile"
