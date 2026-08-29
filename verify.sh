#!/usr/bin/env bash

cd -- "$(dirname -- "${BASH_SOURCE[0]}")" || exit 1

fail() {
  echo "VERIFY FAIL: $*" >&2
  exit 1
}

generated=(bj-1line.sh bj-80-col.sh bj-90-col.sh)
implementations=(bj.sh "${generated[@]}")
executables=(bj.sh test.sh verify.sh rollup.rb linebreak.rb "${generated[@]}")

echo "Checking syntax and executable modes"
bash -n bj.sh test.sh verify.sh "${generated[@]}" \
  || fail "Bash syntax check failed"
ruby -c rollup.rb || fail "rollup.rb syntax check failed"
ruby -c linebreak.rb || fail "linebreak.rb syntax check failed"

for file in "${executables[@]}"; do
  [[ -x $file ]] || fail "$file is not executable"
done

echo "Checking bj.sh CLI"
output=$(./bj.sh '{"foo":"bar"}' foo)
status=$?
[[ $output = bar && $status = 0 ]] || fail "bj.sh CLI query failed"

output=$(printf %s '{"foo":"bar"}' | ./bj.sh - foo)
status=$?
[[ $output = bar && $status = 0 ]] || fail "bj.sh CLI stdin query failed"

output=$(./bj.sh '{"foo":"bar"}' missing)
status=$?
[[ -z $output && $status = 1 ]] \
  || fail "bj.sh CLI missing-query status failed"

echo "Checking generated files"
verify_dir=$(mktemp -d) || fail "Could not create temporary directory"
trap 'rm -r -- "$verify_dir"' EXIT

./rollup.rb bj.sh "$verify_dir/bj-1line.sh" \
  || fail "Could not regenerate bj-1line.sh"
./linebreak.rb --max-lines 13 80 \
  "$verify_dir/bj-1line.sh" "$verify_dir/bj-80-col.sh" \
  || fail "Could not regenerate bj-80-col.sh"
./linebreak.rb --max-lines 12 90 \
  "$verify_dir/bj-1line.sh" "$verify_dir/bj-90-col.sh" \
  || fail "Could not regenerate bj-90-col.sh"

for file in "${generated[@]}"; do
  diff -u "$file" "$verify_dir/$file" \
    || fail "$file differs from regenerated output"
done

awk '!/^#/ { code++ } END {
  if (NR != 2 || code != 1) {
    print FILENAME ": expected one header and one code line" > "/dev/stderr"
    exit 1
  }
}' bj-1line.sh || fail "bj-1line.sh is not the canonical one-line form"

check_wrapped() {
  local file=$1 width=$2 max_lines=$3

  awk -v width="$width" -v max_lines="$max_lines" '
    length > width {
      printf "%s:%d exceeds %d columns (%d)\n",
        FILENAME, FNR, width, length($0) > "/dev/stderr"
      bad=1
    }
    !/^#/ { code++ }
    END {
      if (code > max_lines) {
        printf "%s has %d code lines; maximum is %d\n",
          FILENAME, code, max_lines > "/dev/stderr"
        bad=1
      }
      exit bad
    }
  ' "$file" || fail "$file violates its wrapping constraints"
}

check_wrapped bj-80-col.sh 80 13
check_wrapped bj-90-col.sh 90 12

run_functional_tests() {
  local label=$1
  shift

  echo "Functional tests ($label)"
  for implementation in "${implementations[@]}"; do
    "$@" ./test.sh -s "./$implementation" \
      || fail "$implementation failed under $label"
  done
}

run_functional_tests "the default locale"
run_functional_tests "LC_ALL=C" env LC_ALL=C

echo "Checking diffs"
git diff --check || fail "Unstaged changes contain whitespace errors"
git diff --cached --check || fail "Staged changes contain whitespace errors"

echo "Verification passed"
