#! /usr/bin/env bash

# Shared helpers for the cheesemake test suite.
#
# The fixtures are the examples. Each of them is about one thing, so a test
# copies the example that is about the thing it is testing into a temporary
# directory and runs the cheesemake script there. Nothing a test does touches
# the examples themselves.

TEST_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
CHEESE_ROOT="$(dirname "$TEST_DIR")"
CHEESEMAKE="$CHEESE_ROOT/cheesemake"
EXAMPLE="$CHEESE_ROOT/example"
SHUNIT2="${SHUNIT2:-/usr/share/shunit2/shunit2}"

# ---------------------------------------------------------------- workspace

set_up_workspace()
{
	WORK="$(mktemp -d "${SHUNIT_TMPDIR:-/tmp}/cheesemake.XXXXXX")"
	PROJECT="$WORK/project"
	CHEESEMAKE_BIN="$CHEESEMAKE"
	OUTPUT=''
	STATUS=0
}

tear_down_workspace()
{
	if [[ -n "${WORK:-}" && -d "$WORK" ]]; then
		rm -rf "$WORK"
	fi
}

# Copies the script, and the plugins that live beside it, somewhere else so
# that tests can control CHEESE_DIR, which is where cheesemake looks for
# plugins it does not find in the project.
install_cheesemake_copy()
{
	local dir="${1:-$WORK/cheese}"

	mkdir -p "$dir"
	cp "$CHEESEMAKE" "$dir/cheesemake"
	cp "$CHEESE_ROOT"/*.chevre "$dir"
	CHEESEMAKE_BIN="$dir/cheesemake"
	CHEESE_COPY_DIR="$dir"
}

# ---------------------------------------------------------------- fixtures

# write <path>, content on standard input
write()
{
	mkdir -p "$(dirname "$1")"
	cat > "$1"
}

# copy_example <example> [<destination>]
#
# Copies one of the examples, or one of the modules inside one, into the
# workspace, replacing whatever was copied there before. Anything the example
# has already built is left behind, so a test always starts from sources. The
# example copied is remembered so that a test can put a file it has changed
# back the way the example has it.
copy_example()
{
	local dest="${2:-$PROJECT}"

	EXAMPLE_PROJECT="$EXAMPLE/$1"

	rm -rf "$dest"
	mkdir -p "$dest"
	cp -R "$EXAMPLE_PROJECT/." "$dest"
	find "$dest" -type d -name build -prune -exec rm -rf {} +
}

# Puts one file back the way the example has it.
restore_example_file()
{
	cp "$EXAMPLE_PROJECT/$1" "${2:-$PROJECT}/$1"
}

# edit_recipe <jq filter> [<project directory>]
#
# Varies one thing about the recipe the example ships with. A test should only
# need this where the variation is the thing being tested; anything a test
# wants for its own convenience belongs in an example of its own.
edit_recipe()
{
	local dir="${2:-$PROJECT}"

	if jq "$1" "$dir/recipe.json" > "$dir/recipe.edited"; then
		mv "$dir/recipe.edited" "$dir/recipe.json"
	else
		fail "could not edit $dir/recipe.json with: $1"
	fi
}

# Makes a source that no longer compiles.
break_source()
{
	echo 'not a declaration' >> "${2:-$PROJECT}/$1"
}

# A change the compiler does not care about, to move the hash of a file on.
change_source()
{
	echo '/* changed */' >> "${2:-$PROJECT}/$1"
}

# ---------------------------------------------------------------- running

# run_cheesemake [-C directory] <arguments>
run_cheesemake()
{
	local dir="$PROJECT"

	if [[ "${1:-}" == -C ]]; then
		dir="$2"
		shift 2
	fi

	OUTPUT="$(cd "$dir" && "$CHEESEMAKE_BIN" "$@" 2>&1)"
	STATUS=$?

	return $STATUS
}

# The first line of the last run's output containing the given text.
output_line()
{
	echo "$OUTPUT" | grep -m 1 -F -- "$1"
}

# ---------------------------------------------------------------- assertions

assert_status()
{
	assertEquals "unexpected exit status, output was:
$OUTPUT" "$1" "$STATUS"
}

assert_failed()
{
	assertNotEquals "expected a non zero exit status, output was:
$OUTPUT" 0 "$STATUS"
}

assert_contains()
{
	local haystack="$1"
	local needle="$2"
	local found=1

	[[ "$haystack" == *"$needle"* ]] && found=0

	assertEquals "expected to find '$needle' in:
$haystack" 0 "$found"
}

assert_lacks()
{
	local haystack="$1"
	local needle="$2"
	local found=1

	[[ "$haystack" == *"$needle"* ]] && found=0

	assertEquals "did not expect to find '$needle' in:
$haystack" 1 "$found"
}

assert_output_contains()
{
	assert_contains "$OUTPUT" "$1"
}

assert_output_lacks()
{
	assert_lacks "$OUTPUT" "$1"
}

assert_file()
{
	local path="${2:-$PROJECT}/$1"

	assertTrue "expected file $1 to exist, output was:
$OUTPUT" "[ -f '$path' ]"
}

assert_no_file()
{
	local path="${2:-$PROJECT}/$1"

	assertFalse "expected file $1 not to exist, output was:
$OUTPUT" "[ -f '$path' ]"
}

assert_directory()
{
	local path="${2:-$PROJECT}/$1"

	assertTrue "expected directory $1 to exist, output was:
$OUTPUT" "[ -d '$path' ]"
}

assert_no_directory()
{
	local path="${2:-$PROJECT}/$1"

	assertFalse "expected directory $1 not to exist, output was:
$OUTPUT" "[ -d '$path' ]"
}

# assert_before <first> <second>: both appear in the output, in this order.
assert_before()
{
	local first="$(echo "$OUTPUT" | grep -n -m 1 -F -- "$1" | cut -d : -f 1)"
	local second="$(echo "$OUTPUT" | grep -n -m 1 -F -- "$2" | cut -d : -f 1)"

	assertNotNull "expected output to contain '$1':
$OUTPUT" "$first"
	assertNotNull "expected output to contain '$2':
$OUTPUT" "$second"
	assertTrue "expected '$1' before '$2', output was:
$OUTPUT" "[ '${first:-0}' -lt '${second:-0}' ]"
}
