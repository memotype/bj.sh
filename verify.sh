#!/usr/bin/env bash

cd -- "$(dirname -- "${BASH_SOURCE[0]}")" || exit 1

fail() {
  echo "VERIFY FAIL: $*" >&2
  exit 1
}

generated=(bj-1line.sh bj-80-col.sh bj-90-col.sh)
implementations=(bj.sh "${generated[@]}")
executables=(bj.sh test.rb verify.sh rollup.rb linebreak.rb "${generated[@]}")

echo "Checking syntax and executable modes"
bash -n bj.sh verify.sh "${generated[@]}" \
  || fail "Bash syntax check failed"
ruby -c rollup.rb || fail "rollup.rb syntax check failed"
ruby -c linebreak.rb || fail "linebreak.rb syntax check failed"
ruby -c test.rb || fail "test.rb syntax check failed"

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

verify_dir=$(mktemp -d) || fail "Could not create temporary directory"
trap 'rm -r -- "$verify_dir"' EXIT

echo "Checking test harness guardrails"
bad_source="$verify_dir/disables-nounset.sh"
bad_source_log="$verify_dir/disables-nounset.log"
printf '. %q\nset +u\n' "$PWD/bj.sh" > "$bad_source"
if ./test.rb -s "$bad_source" > "$bad_source_log" 2>&1; then
  fail "test runner accepted a source that disables nounset"
fi
grep -F 'PASS top-level-string-value' "$bad_source_log" > /dev/null \
  || fail "nounset guardrail source failed unrelated tests"
grep -F 'FAIL nounset-object-output' "$bad_source_log" > /dev/null \
  || fail "test runner did not reject source-time nounset corruption"
grep -F 'status actual=125 expected=0' "$bad_source_log" > /dev/null \
  || fail "nounset corruption did not use the runner guardrail status"

file_argument_json="$verify_dir/file-argument.json"
file_argument_catalog="$verify_dir/file-argument.yml"
file_argument_log="$verify_dir/file-argument.log"
printf %s '{"value":"ok"}' > "$file_argument_json"
printf '%s\n' \
  'version: 1' \
  'report:' \
  '  success: "PASS %{name}: %{description}"' \
  '  failure: "FAIL %{name}: %{description}"' \
  'tests:' \
  '  - name: nounset-file-argument' \
  '    description: rejects source-time nounset corruption for file arguments' \
  '    input:' \
  '      file: file-argument.json' \
  '      transport: argument' \
  '    query: [value]' \
  '    shell: {nounset: true}' \
  '    expected:' \
  "      output: 'ok'" \
  '      status: 0' \
  > "$file_argument_catalog"
if ./test.rb -f "$file_argument_catalog" -s "$bad_source" \
    > "$file_argument_log" 2>&1
then
  fail "file-argument driver accepted a source that disables nounset"
fi
grep -F 'FAIL nounset-file-argument' "$file_argument_log" > /dev/null \
  || fail "file-argument driver did not reject source-time nounset corruption"
grep -F 'status actual=125 expected=0' "$file_argument_log" > /dev/null \
  || fail "file-argument nounset corruption did not use guardrail status"

check_catalog_rejected() {
  local name=$1 from=$2 to=$3 expected=$4
  local catalog="$verify_dir/$name.yml"
  local log="$verify_dir/$name.log"

  ruby -e '
    input, output, from, to = ARGV
    text = File.read(input)
    abort "Source text not found: #{from.inspect}" unless text.sub!(from, to)
    File.write(output, text)
  ' tests.yml "$catalog" "$from" "$to" \
    || fail "could not prepare $name catalog check"
  if ./test.rb -f "$catalog" > "$log" 2>&1; then
    fail "test runner accepted $name"
  fi
  grep -F "$expected" "$log" > /dev/null \
    || fail "test runner rejected $name for the wrong reason"
}

check_catalog_rejected unknown-document-key \
  'version: 1' $'version: 1\nunknown: true' \
  'catalog: unknown key "unknown"'
check_catalog_rejected unknown-report-key \
  $'report:\n  success:' $'report:\n  unknown: true\n  success:' \
  'report: unknown key "unknown"'
check_catalog_rejected unknown-test-key \
  '  - name: top-level-string-value' \
  $'  - name: top-level-string-value\n    unknown: true' \
  'test 1: unknown key "unknown"'
check_catalog_rejected unknown-input-key \
  $'    input:\n      json:' \
  $'    input:\n      transprot: stdin\n      json:' \
  'top-level-string-value input: unknown key "transprot"'
check_catalog_rejected unknown-expected-key \
  $'    expected:\n      output:' \
  $'    expected:\n      statsu: 0\n      output:' \
  'top-level-string-value expected: unknown key "statsu"'
check_catalog_rejected unknown-shell-key \
  '    shell: {nounset: true}' \
  '    shell: {nounset: true, nounsett: true}' \
  'nounset-object-output shell: unknown key "nounsett"'
check_catalog_rejected unsupported-tag \
  '    tags: [timing]' '    tags: [benchmark]' \
  'timing-large-fixture-argument: unsupported tags "benchmark"'

echo "Checking generated files"
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
    "$@" ./test.rb -s "./$implementation" \
      || fail "$implementation failed under $label"
  done
}

run_functional_tests "the default locale"
run_functional_tests "LC_ALL=C" env LC_ALL=C

echo "Checking diffs"
git diff --check || fail "Unstaged changes contain whitespace errors"
git diff --cached --check || fail "Staged changes contain whitespace errors"

echo "Verification passed"
