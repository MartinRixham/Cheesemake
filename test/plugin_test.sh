#! /usr/bin/env bash

# Plugins: where they are found, what they are given and what their failure does.
#
# The plugins example configures the plugins that come with cheesemake,
# version and cppcheck and valgrind and the rest, and one of its own,
# lines.chevre, which counts the lines of source and fails the build if there
# are more of them than its configuration allows.

. "$(dirname "$(readlink -f "$0")")/helpers.sh"

setUp()
{
	set_up_workspace
	copy_example plugins
}

tearDown()
{
	tear_down_workspace
}

# The number of lines of source that the lines plugin should report.
count_lines()
{
	find "$PROJECT/src" "$PROJECT/test" -name "*.c*" -exec cat {} + | wc -l
}

testPluginOfTheProjectIsFoundInTheProjectDirectory()
{
	run_cheesemake validate

	assert_status 0
	assert_output_contains "$(count_lines) lines of source in analysis"
}

testPluginIsFoundNextToTheScript()
{
	install_cheesemake_copy
	mv "$PROJECT/lines.chevre" "$CHEESE_COPY_DIR/lines.chevre"

	run_cheesemake validate

	assert_status 0
	assert_output_contains 'lines of source in analysis'
}

testPluginInTheProjectDirectoryTakesPrecedence()
{
	install_cheesemake_copy
	{
		cat "$PROJECT/lines.chevre"
		echo 'echo "counted next to the script"'
	} > "$CHEESE_COPY_DIR/lines.chevre"

	run_cheesemake validate

	assert_status 0
	assert_output_contains 'lines of source in analysis'
	assert_output_lacks 'counted next to the script'
}

testMissingPluginFailsTheBuild()
{
	rm "$PROJECT/lines.chevre"

	run_cheesemake validate

	assert_status 1
	assert_no_file build/src/analysis.o
}

testPluginReceivesItsConfigurationAsJson()
{
	run_cheesemake verify

	assert_status 0
	assert_output_contains 'valgrind --leak-check=yes build/bin/analysis this that tother'
}

testPluginWithoutConfigurationReceivesNull()
{
	# cppcheck is configured with nothing, and asks for its options anyway.
	run_cheesemake validate

	assert_status 0
	assert_output_contains 'cppcheck --cppcheck-build-dir=build/cppcheck --error-exitcode=1  -Isrc src/'
}

testPluginCanUseTheFunctionsOfTheScript()
{
	rm "$PROJECT/src/numbers.c"

	run_cheesemake validate

	assert_status 0
	assert_output_contains "$(count_lines) lines of source in analysis"
}

testValidationPluginsRunBeforeAnythingIsCompiled()
{
	run_cheesemake package

	assert_status 0
	assert_before 'lines of source in analysis' '-c -o build/src/analysis.o'
	assert_before 'Checking src/analysis.c' '-c -o build/src/analysis.o'
}

testVerificationPluginsDoNotRunBeforeTheVerifyPhase()
{
	run_cheesemake package

	assert_status 0
	assert_output_lacks 'valgrind'

	run_cheesemake verify

	assert_status 0
	assert_output_contains 'valgrind'
}

testVerificationPluginRunsAfterPackagingAndBeforeRunning()
{
	run_cheesemake run

	assert_status 0
	assert_before 'gcc -o build/bin/analysis' 'valgrind --leak-check=yes'
	assert_before 'valgrind --leak-check=yes' 'build/bin/analysis --no-worries'
}

testValidationPluginFailureStopsTheBuild()
{
	edit_recipe '.plugins |= map(if .name == "lines" then .config.maximum = "1" else . end)'

	run_cheesemake package

	assert_status 1
	assert_output_contains 'analysis has more than 1 lines of source.'
	assert_output_lacks '-c -o build/src/analysis.o'
	assert_no_file build/bin/analysis
}

testVerificationPluginFailureStopsTheRun()
{
	edit_recipe '.plugins = [{ "name": "lines", "phase": "verify", "config": { "maximum": "1" } }]'

	run_cheesemake run

	assert_status 1
	assert_file build/bin/analysis
	assert_output_lacks 'the number is 7'
}

# cppcheck keeps its own cache in build/cppcheck, and is given every source on
# every build so that it can analyse the whole program. It hashes a source as
# preprocessed, so it is a change to the code, not to the comments, that has it
# analyse a source again, and it says it is checking every source either way.
# What it really analysed is told by which of its .a1 files it wrote. All three
# sources of the example include numbers.h.

# A change cppcheck cares about, unlike change_source.
change_code()
{
	echo 'int changed(void);' >> "$PROJECT/$1"
}

# Starts the clock for analysed_sources.
mark_analysis()
{
	touch "$WORK/analysis.mark"
}

# The sources cppcheck analysed since mark_analysis, one to a line, sorted.
# files.txt maps each .a1 file to its source.
analysed_sources()
{
	local a1

	for a1 in $(cd "$PROJECT/build/cppcheck" && find . -name '*.a1' -newer "$WORK/analysis.mark"); do
		grep "^${a1#./}:" "$PROJECT/build/cppcheck/files.txt" | sed 's/.*://'
	done | sort
}

assert_analysed()
{
	assertEquals "unexpected sources analysed, output was:
$OUTPUT" "$1" "$(analysed_sources)"
}

# A source cppcheck rejects, out of bounds by one.
write_rejected_source()
{
	write "$PROJECT/src/bad.c" <<'EOF'
int bad(void)
{
	int a[2];

	a[3] = 1;

	return a[0];
}
EOF
}

testCppcheckDoesNotAnalyseASourceThatHasNotChanged()
{
	run_cheesemake validate
	assert_status 0
	assert_output_contains 'Checking src/analysis.c'

	mark_analysis
	run_cheesemake validate

	assert_status 0
	assert_analysed ''
}

testCppcheckAnalysesOnlyTheSourceThatChanged()
{
	run_cheesemake validate
	assert_status 0

	change_code src/numbers.c
	mark_analysis
	run_cheesemake validate

	assert_status 0
	assert_analysed 'src/numbers.c'
}

testCppcheckAnalysesEverySourceThatIncludesAChangedHeader()
{
	run_cheesemake validate
	assert_status 0

	change_code src/numbers.h
	mark_analysis
	run_cheesemake validate

	assert_status 0
	assert_analysed 'src/analysis.c
src/numbers.c
test/numbers_test.c'
}

testCppcheckRejectsARejectedSourceOnEveryBuild()
{
	write_rejected_source

	run_cheesemake validate
	assert_failed
	assert_output_contains 'arrayIndexOutOfBounds'

	mark_analysis
	run_cheesemake validate

	assert_failed
	assert_output_contains 'arrayIndexOutOfBounds'
	assert_analysed ''
}

testCppcheckPassesARejectedSourceOnceItIsFixed()
{
	write_rejected_source

	run_cheesemake validate
	assert_failed

	write "$PROJECT/src/bad.c" <<'EOF'
int bad(void)
{
	return 0;
}
EOF

	mark_analysis
	run_cheesemake validate

	assert_status 0
	assert_analysed 'src/bad.c'
}

# clang-tidy is told to look away from it too, so that it is cppcheck alone
# that passes or fails the build.
testCppcheckAppliesItsOptionsToWhatItHasCached()
{
	write "$PROJECT/src/bad.c" <<'EOF'
int bad(void)
{
	int a[2];

	// cppcheck-suppress arrayIndexOutOfBounds
	a[3] = 1; // NOLINT

	return a[0];
}
EOF

	run_cheesemake validate
	assert_failed

	edit_recipe '.plugins |= map(if .name == "cppcheck" then .config = { "options": "--inline-suppr" } else . end)'

	run_cheesemake validate

	assert_status 0
	assert_output_contains 'cppcheck --cppcheck-build-dir=build/cppcheck --error-exitcode=1 --inline-suppr'
}

testCppcheckAnalysesEverythingAgainWhenItsOptionsChange()
{
	run_cheesemake validate
	assert_status 0

	edit_recipe '.plugins |= map(if .name == "cppcheck" then .config = { "options": "-DCHANGED" } else . end)'

	mark_analysis
	run_cheesemake validate

	assert_status 0
	assert_analysed 'src/analysis.c
src/numbers.c
test/numbers_test.c'
}

# clang-tidy remembers what passed in build/clang-tidy, source by source, so
# that a source that fails does not cost the others that passed alongside it
# another check.

CLANG_TIDY='clang-tidy --checks=-*,bugprone-*,clang-analyzer-* --warnings-as-errors=*'

# The line clang-tidy prints for a source it checks, up to its flags.
clang_tidy_line()
{
	echo "$CLANG_TIDY $1 -- "
}

# A source clang-tidy rejects, with identical branches, and cppcheck does not,
# so that cppcheck does not stop the build before clang-tidy gets to it.
write_unclear_source()
{
	write "$PROJECT/src/unclear.c" <<'EOF'
int unclear(int a)
{
	if (a)
	{
		return 1;
	}
	else
	{
		return 1;
	}
}
EOF
}

testClangTidyChecksEverySourceWithTheFlagsItIsCompiledWith()
{
	run_cheesemake validate

	assert_status 0
	assert_output_contains "$(clang_tidy_line src/analysis.c)-Isrc -Ibuild/include"
	assert_output_contains "$(clang_tidy_line src/numbers.c)-Isrc -Ibuild/include"
	assert_output_contains "$(clang_tidy_line test/numbers_test.c)-Itest -Isrc -Ibuild/include"
}

testClangTidyIsGivenTheDefinesOfTheRecipe()
{
	edit_recipe '.define = { "NDEBUG": "true" }'

	run_cheesemake validate

	assert_status 0
	assert_output_contains "$(clang_tidy_line src/analysis.c)-DNDEBUG -Isrc"
}

testClangTidyDoesNotCheckASourceThatHasNotChanged()
{
	run_cheesemake validate
	assert_status 0

	run_cheesemake validate

	assert_status 0
	assert_output_lacks 'clang-tidy'
}

testClangTidyChecksOnlyTheSourceThatChanged()
{
	run_cheesemake validate
	assert_status 0

	change_source src/numbers.c

	run_cheesemake validate

	assert_status 0
	assert_output_contains "$(clang_tidy_line src/numbers.c)"
	assert_output_lacks "$(clang_tidy_line src/analysis.c)"
	assert_output_lacks "$(clang_tidy_line test/numbers_test.c)"
}

testClangTidyChecksEverySourceThatIncludesAChangedHeader()
{
	run_cheesemake validate
	assert_status 0

	change_source src/numbers.h

	run_cheesemake validate

	assert_status 0
	assert_output_contains "$(clang_tidy_line src/analysis.c)"
	assert_output_contains "$(clang_tidy_line src/numbers.c)"
	assert_output_contains "$(clang_tidy_line test/numbers_test.c)"
}

testClangTidyFailureStopsTheBuild()
{
	write_unclear_source

	run_cheesemake compile

	assert_failed
	assert_output_contains 'bugprone-branch-clone'
	assert_output_lacks '-c -o build/src/analysis.o'
}

testClangTidyChecksOnlyARejectedSourceAgain()
{
	write_unclear_source

	run_cheesemake validate
	assert_failed

	run_cheesemake validate

	assert_failed
	assert_output_contains "$(clang_tidy_line src/unclear.c)"
	assert_output_lacks "$(clang_tidy_line src/analysis.c)"
	assert_output_lacks "$(clang_tidy_line src/numbers.c)"
}

testClangTidyStopsCheckingARejectedSourceOnceItPasses()
{
	write_unclear_source

	run_cheesemake validate
	assert_failed

	write "$PROJECT/src/unclear.c" <<'EOF'
int unclear(int a)
{
	return a;
}
EOF

	run_cheesemake validate
	assert_status 0
	assert_output_contains "$(clang_tidy_line src/unclear.c)"

	run_cheesemake validate

	assert_status 0
	assert_output_lacks 'clang-tidy'
}

testClangTidyChecksEverythingAgainWhenItsChecksChange()
{
	run_cheesemake validate
	assert_status 0

	edit_recipe '.plugins |= map(if .name == "clang-tidy" then .config.checks = "-*,clang-analyzer-*" else . end)'

	run_cheesemake validate

	assert_status 0
	assert_output_contains 'clang-tidy --checks=-*,clang-analyzer-* --warnings-as-errors=* src/analysis.c'
	assert_output_contains 'clang-tidy --checks=-*,clang-analyzer-* --warnings-as-errors=* src/numbers.c'
	assert_output_contains 'clang-tidy --checks=-*,clang-analyzer-* --warnings-as-errors=* test/numbers_test.c'
}

testClangTidyWarningsAreNotErrorsUnlessConfigured()
{
	edit_recipe '.plugins |= map(if .name == "clang-tidy" then del(.config["warnings-as-errors"]) else . end)'
	write_unclear_source

	run_cheesemake validate

	assert_status 0
	assert_output_contains 'bugprone-branch-clone'
}

testClangTidyIsGivenItsOtherOptionsAsTheyAre()
{
	edit_recipe '.plugins |= map(if .name == "clang-tidy" then .config.options = "--quiet --extra-arg=-std=c11" else . end)'

	run_cheesemake validate

	assert_status 0
	assert_output_contains 'clang-tidy --checks=-*,bugprone-*,clang-analyzer-* --warnings-as-errors=* --quiet --extra-arg=-std=c11 src/analysis.c'
}

testClangTidyWithoutConfigurationLeavesItToTheConfigurationFile()
{
	edit_recipe '.plugins |= map(if .name == "clang-tidy" then del(.config) else . end)'
	write "$PROJECT/.clang-tidy" <<'EOF'
Checks: '-*,bugprone-*'
EOF

	run_cheesemake validate

	assert_status 0
	assert_output_contains 'clang-tidy src/analysis.c -- '
}

testClangTidyChecksEverythingAgainWhenItsConfigurationFileChanges()
{
	run_cheesemake validate
	assert_status 0

	write "$PROJECT/.clang-tidy" <<'EOF'
CheckOptions:
  bugprone-branch-clone.IgnoreCaseWithSingleStatement: true
EOF

	run_cheesemake validate

	assert_status 0
	assert_output_contains "$(clang_tidy_line src/analysis.c)"
	assert_output_contains "$(clang_tidy_line src/numbers.c)"
	assert_output_contains "$(clang_tidy_line test/numbers_test.c)"
}

# The sanitizer plugins, sanitize (ASan with UBSan), msan and tsan, each build
# the program again under build/<plugin> with their sanitizer and run it. Each
# remembers what it compiled in its own build/hashes, as the build does, and
# compiles everything again when the command it compiles with changes.

ASAN='-fsanitize=address,undefined'
MSAN='-fsanitize=memory'
TSAN='-fsanitize=thread'

# Leaves the one plugin being tested, as the example configures it, so that
# no other plugin gets to a bug before it does.
only_plugin()
{
	edit_recipe ".plugins |= map(select(.name == \"$1\"))"
}

# The sources the last run compiled with the given sanitizer, by name.
sanitized_sources()
{
	echo "$OUTPUT" | grep -F -- "$1" | grep -F -- ' -c -o ' | awk '{ print $NF }' | sort | tr '\n' ' ' | sed 's/ $//'
}

# assert_sanitized <sanitizer> <sources>
assert_sanitized()
{
	assertEquals "unexpected sources compiled with $1, output was:
$OUTPUT" "$2" "$(sanitized_sources "$1")"
}

# A bug that only shows when the program runs, in a source of its own that
# runs it before main, so that the sources of the example stay as they are.
write_bug()
{
	write "$PROJECT/src/bug.c"
}

# sanitizer_compiles_nothing_that_has_not_changed <plugin> <sanitizer>
sanitizer_compiles_nothing_that_has_not_changed()
{
	only_plugin "$1"

	run_cheesemake verify
	assert_status 0
	assert_sanitized "$2" 'src/analysis.c src/numbers.c'

	run_cheesemake verify

	assert_status 0
	assert_sanitized "$2" ''
	assert_output_contains 'the number is 7'
}

# sanitizer_compiles_only_the_source_that_changed <plugin> <sanitizer>
sanitizer_compiles_only_the_source_that_changed()
{
	only_plugin "$1"

	run_cheesemake verify
	assert_status 0

	change_source src/numbers.c

	run_cheesemake verify

	assert_status 0
	assert_sanitized "$2" 'src/numbers.c'
}

# sanitizer_compiles_every_source_that_includes_a_changed_header <plugin> <sanitizer>
sanitizer_compiles_every_source_that_includes_a_changed_header()
{
	only_plugin "$1"

	run_cheesemake verify
	assert_status 0

	change_source src/numbers.h

	run_cheesemake verify

	assert_status 0
	assert_sanitized "$2" 'src/analysis.c src/numbers.c'
}

# sanitizer_compiles_everything_again_when_its_flags_change <plugin> <sanitizer>
sanitizer_compiles_everything_again_when_its_flags_change()
{
	only_plugin "$1"

	run_cheesemake verify
	assert_status 0

	edit_recipe ".plugins |= map(if .name == \"$1\" then .config.flags = \"-O1\" else . end)"

	run_cheesemake verify

	assert_status 0
	assert_output_contains "$2"
	assert_output_contains '-O1 -Isrc'
	assert_sanitized "$2" 'src/analysis.c src/numbers.c'
}

testSanitizeCompilesNothingThatHasNotChanged()
{
	sanitizer_compiles_nothing_that_has_not_changed sanitize "$ASAN"
}

testSanitizeCompilesOnlyTheSourceThatChanged()
{
	sanitizer_compiles_only_the_source_that_changed sanitize "$ASAN"
}

testSanitizeCompilesEverySourceThatIncludesAChangedHeader()
{
	sanitizer_compiles_every_source_that_includes_a_changed_header sanitize "$ASAN"
}

testSanitizeCompilesEverythingAgainWhenItsFlagsChange()
{
	sanitizer_compiles_everything_again_when_its_flags_change sanitize "$ASAN"
}

testSanitizeFailsTheBuildOnAMemoryError()
{
	only_plugin sanitize
	write_bug <<'EOF'
#include <stdlib.h>

__attribute__((constructor)) static void overflow(void)
{
	volatile char *bytes = malloc(2);

	bytes[2] = 1;
	free((void *) bytes);
}
EOF

	run_cheesemake verify

	assert_failed
	assert_output_contains 'ERROR: AddressSanitizer: heap-buffer-overflow'
}

testSanitizeFailsTheBuildOnUndefinedBehaviour()
{
	only_plugin sanitize
	write_bug <<'EOF'
#include <limits.h>

__attribute__((constructor)) static void overflow(void)
{
	volatile int big = INT_MAX;

	big = big + 1;
}
EOF

	run_cheesemake verify

	assert_failed
	assert_output_contains 'runtime error: signed integer overflow'
}

testSanitizeGivesTheProgramItsAsanOptions()
{
	only_plugin sanitize
	write_bug <<'EOF'
#include <stdlib.h>

void *volatile leaked;

__attribute__((constructor)) static void leak(void)
{
	leaked = malloc(8);
	leaked = NULL;
}
EOF

	run_cheesemake verify
	assert_failed
	assert_output_contains 'ERROR: LeakSanitizer: detected memory leaks'

	edit_recipe '.plugins |= map(if .name == "sanitize" then .config["asan-options"] = "detect_leaks=0" else . end)'

	run_cheesemake verify

	assert_status 0
	assert_output_contains 'ASAN_OPTIONS=detect_leaks=0 UBSAN_OPTIONS=print_stacktrace=1 build/bin/analysis this that tother'
}

testMsanCompilesNothingThatHasNotChanged()
{
	sanitizer_compiles_nothing_that_has_not_changed msan "$MSAN"
}

testMsanCompilesOnlyTheSourceThatChanged()
{
	sanitizer_compiles_only_the_source_that_changed msan "$MSAN"
}

testMsanCompilesEverySourceThatIncludesAChangedHeader()
{
	sanitizer_compiles_every_source_that_includes_a_changed_header msan "$MSAN"
}

testMsanCompilesEverythingAgainWhenItsFlagsChange()
{
	sanitizer_compiles_everything_again_when_its_flags_change msan "$MSAN"
}

# Memory sanitizer is clang's, so msan compiles with clang, whatever the
# recipe compiles with, but keeps the arguments the recipe gives its compiler.
testMsanCompilesWithClangAndTheArgumentsOfTheRecipe()
{
	only_plugin msan

	run_cheesemake verify

	assert_status 0
	assert_output_contains "clang -g -Wall $MSAN"
}

testMsanCompilesWithTheCompilerItIsConfiguredWith()
{
	local clang="$(command -v clang)"

	only_plugin msan
	edit_recipe ".plugins |= map(if .name == \"msan\" then .config.compiler = \"$clang\" else . end)"

	run_cheesemake verify

	assert_status 0
	assert_output_contains "$clang -g -Wall $MSAN"
}

# A library built without memory sanitizer would hide what it does from msan,
# so msan compiles the sources of every module along with those of the project.
testMsanCompilesTheSourcesOfEveryModule()
{
	copy_example modules
	edit_recipe '.plugins = [{ "name": "msan", "phase": "verify" }]'

	run_cheesemake verify

	assert_status 0
	assert_sanitized "$MSAN" 'modules/middle/bottom/src/bottom.c modules/middle/src/middle.c src/subd/code.c src/top.c'
	assert_output_contains '-Isrc -Imodules/middle/src -Imodules/middle/bottom/src'
	assert_output_contains 'modules 11 1'
}

testMsanCompilesEverySourceThatIncludesAChangedHeaderOfAModule()
{
	copy_example modules
	edit_recipe '.plugins = [{ "name": "msan", "phase": "verify" }]'

	run_cheesemake verify
	assert_status 0

	change_source middle/bottom/src/bottom.h

	run_cheesemake verify

	assert_status 0
	assert_sanitized "$MSAN" 'modules/middle/bottom/src/bottom.c modules/middle/src/middle.c src/top.c'
}

# An uninitialised read, which only memory sanitizer of the three sees.
write_uninitialised_read()
{
	write_bug <<'EOF'
#include <stdio.h>
#include <stdlib.h>

__attribute__((constructor)) static void uninitialised(void)
{
	int *number = malloc(sizeof *number);

	if (*number)
	{
		puts("set");
	}

	free(number);
}
EOF
}

testMsanFailsTheBuildOnAnUninitialisedRead()
{
	only_plugin msan
	write_uninitialised_read

	run_cheesemake verify

	assert_failed
	assert_output_contains 'WARNING: MemorySanitizer: use-of-uninitialized-value'
}

testMsanGivesTheProgramItsOptions()
{
	only_plugin msan
	edit_recipe '.plugins |= map(if .name == "msan" then .config.options = "exitcode=0" else . end)'
	write_uninitialised_read

	run_cheesemake verify

	assert_status 0
	assert_output_contains 'MSAN_OPTIONS=exitcode=0 build/bin/analysis this that tother'
	assert_output_contains 'WARNING: MemorySanitizer: use-of-uninitialized-value'
}

testTsanCompilesNothingThatHasNotChanged()
{
	sanitizer_compiles_nothing_that_has_not_changed tsan "$TSAN"
}

testTsanCompilesOnlyTheSourceThatChanged()
{
	sanitizer_compiles_only_the_source_that_changed tsan "$TSAN"
}

testTsanCompilesEverySourceThatIncludesAChangedHeader()
{
	sanitizer_compiles_every_source_that_includes_a_changed_header tsan "$TSAN"
}

testTsanCompilesEverythingAgainWhenItsFlagsChange()
{
	sanitizer_compiles_everything_again_when_its_flags_change tsan "$TSAN"
}

# Two threads counting at once, enough times over that thread sanitizer always
# sees them overlap.
write_data_race()
{
	write_bug <<'EOF'
#include <pthread.h>

static volatile int counter;

static void *count(void *unused)
{
	int i;

	for (i = 0; i < 100000; i++)
	{
		counter++;
	}

	return unused;
}

__attribute__((constructor)) static void race(void)
{
	pthread_t thread;

	pthread_create(&thread, NULL, count, NULL);
	count(NULL);
	pthread_join(thread, NULL);
}
EOF
}

testTsanFailsTheBuildOnADataRace()
{
	only_plugin tsan
	write_data_race

	run_cheesemake verify

	assert_failed
	assert_output_contains 'WARNING: ThreadSanitizer: data race'
}

testTsanGivesTheProgramItsOptions()
{
	only_plugin tsan
	edit_recipe '.plugins |= map(if .name == "tsan" then .config.options = "exitcode=0" else . end)'
	write_data_race

	run_cheesemake verify

	assert_status 0
	assert_output_contains 'TSAN_OPTIONS=exitcode=0 build/bin/analysis this that tother'
	assert_output_contains 'WARNING: ThreadSanitizer: data race'
}

testEveryPluginTheExampleConfiguresRuns()
{
	run_cheesemake verify

	assert_status 0
	assert_output_contains 'Checking src/analysis.c'
	assert_output_contains "$(clang_tidy_line src/analysis.c)"
	assert_output_contains 'lines of source in analysis'
	assert_output_contains 'valgrind --leak-check=yes build/bin/analysis this that tother'
	assert_output_contains 'ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=print_stacktrace=1 build/bin/analysis this that tother'
	assert_output_contains 'MSAN_OPTIONS= build/bin/analysis this that tother'
	assert_output_contains 'TSAN_OPTIONS= build/bin/analysis this that tother'
	assert_output_contains 'gcovr -s -r .'
	assert_output_contains 'gprof'
}

. "$SHUNIT2"
