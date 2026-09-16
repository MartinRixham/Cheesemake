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
	assert_output_contains 'cppcheck --error-exitcode=1  src/'
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

# cppcheck remembers what passed in build/cppcheck, so that it only checks a
# source that has changed since. All three sources of the example include
# numbers.h.

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

testCppcheckDoesNotCheckASourceThatHasNotChanged()
{
	run_cheesemake validate
	assert_status 0
	assert_output_contains 'Checking src/analysis.c'

	run_cheesemake validate

	assert_status 0
	assert_output_lacks 'cppcheck --error-exitcode=1'
}

testCppcheckChecksOnlyTheSourceThatChanged()
{
	run_cheesemake validate
	assert_status 0

	change_source src/numbers.c

	run_cheesemake validate

	assert_status 0
	assert_output_contains 'Checking src/numbers.c'
	assert_output_lacks 'Checking src/analysis.c'
	assert_output_lacks 'Checking test/numbers_test.c'
}

testCppcheckChecksEverySourceThatIncludesAChangedHeader()
{
	run_cheesemake validate
	assert_status 0

	change_source src/numbers.h

	run_cheesemake validate

	assert_status 0
	assert_output_contains 'Checking src/analysis.c'
	assert_output_contains 'Checking src/numbers.c'
	assert_output_contains 'Checking test/numbers_test.c'
}

testCppcheckChecksARejectedSourceOnEveryBuild()
{
	write_rejected_source

	run_cheesemake validate
	assert_failed
	assert_output_contains 'Checking src/bad.c'

	run_cheesemake validate

	assert_failed
	assert_output_contains 'Checking src/bad.c'
}

testCppcheckStopsCheckingARejectedSourceOnceItPasses()
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

	run_cheesemake validate
	assert_status 0
	assert_output_contains 'Checking src/bad.c'

	run_cheesemake validate

	assert_status 0
	assert_output_lacks 'cppcheck --error-exitcode=1'
}

testCppcheckChecksEverythingAgainWhenItsOptionsChange()
{
	run_cheesemake validate
	assert_status 0

	edit_recipe '.plugins |= map(if .name == "cppcheck" then .config = { "options": "--inline-suppr" } else . end)'

	run_cheesemake validate

	assert_status 0
	assert_output_contains 'cppcheck --error-exitcode=1 --inline-suppr'
	assert_output_contains 'Checking src/analysis.c'
	assert_output_contains 'Checking src/numbers.c'
	assert_output_contains 'Checking test/numbers_test.c'
}

# clang-tidy remembers what passed in build/clang-tidy, as cppcheck does, but
# source by source, so that a source that fails does not cost the others that
# passed alongside it another check.

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

testEveryPluginTheExampleConfiguresRuns()
{
	run_cheesemake verify

	assert_status 0
	assert_output_contains 'Checking src/analysis.c'
	assert_output_contains "$(clang_tidy_line src/analysis.c)"
	assert_output_contains 'lines of source in analysis'
	assert_output_contains 'valgrind --leak-check=yes build/bin/analysis this that tother'
	assert_output_contains 'gcovr -s -r .'
	assert_output_contains 'gprof'
}

. "$SHUNIT2"
