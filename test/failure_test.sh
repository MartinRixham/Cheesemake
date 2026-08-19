#! /usr/bin/env bash

# Failure modes: what makes a build stop, and what it leaves behind.

. "$(dirname "$(readlink -f "$0")")/helpers.sh"

setUp()
{
	set_up_workspace
	copy_example executable
}

tearDown()
{
	tear_down_workspace
}

testCompilationErrorStopsTheBuild()
{
	break_source src/greeting.c

	run_cheesemake package

	assert_status 1
	assert_no_file build/src/greeting.o
	assert_no_file build/bin/greeter
}

testAFailedSourceIsNotRecordedInTheHashes()
{
	break_source src/greeting.c

	run_cheesemake compile

	assert_status 1
	assert_lacks "$(cat "$PROJECT/build/hashes")" 'src/greeting.c'
}

testFailingTestStopsTheBuildBeforePackaging()
{
	# The test of the example asserts what greeting returns.
	sed -i 's/"hello"/"goodbye"/' "$PROJECT/src/greeting.c"

	run_cheesemake package

	assert_status 1
	assert_output_contains 'build/test/greeting_test'
	assert_no_file build/bin/greeter
}

testLinkErrorStopsTheBuild()
{
	rm "$PROJECT/test/greeting_test.c"
	rm "$PROJECT/src/greeting.c"

	run_cheesemake package

	assert_status 1
	assert_file build/src/greeter.o
	assert_no_file build/bin/greeter
}

testMissingSourceDirectoryStopsTheBuild()
{
	rm -r "$PROJECT/src"

	run_cheesemake compile

	assert_status 1
	assert_output_contains 'src'
}

testMissingTestDirectoryStopsTheBuild()
{
	rm -r "$PROJECT/test"

	run_cheesemake compile

	assert_status 1
	assert_output_contains 'test'
}

testRunningAProjectThatDoesNotCompileProducesNoBinary()
{
	break_source src/greeter.c

	run_cheesemake run

	assert_status 1
	assert_no_file build/bin/greeter
	assert_output_lacks 'hello world'
}

# KNOWN DEFECT: the recipe is never checked. Every use of it goes through a
# pipeline, and a pipeline takes its status from its last command, so the jq
# failures are printed on standard error and then swallowed. The build only
# stops because the compiler read out of the recipe is empty and so is not a
# command, and a project with nothing to compile reports success. These three
# tests pin the current behaviour; flip them when the recipe is validated
# before the phases run.
testMissingRecipeIsReportedButNotChecked()
{
	rm "$PROJECT/recipe.json"

	run_cheesemake compile

	assert_failed
	assert_output_contains 'recipe.json'
	assert_output_contains 'command not found'
	assert_no_file build/src/greeting.o
}

testInvalidRecipeIsReportedButNotChecked()
{
	write "$PROJECT/recipe.json" <<'EOF'
{ this is not json
EOF

	run_cheesemake compile

	assert_failed
	assert_output_contains 'error'
	assert_no_file build/src/greeting.o
}

testMissingRecipeWithNothingToCompileReportsSuccess()
{
	rm "$PROJECT/recipe.json"
	find "$PROJECT/src" "$PROJECT/test" -name "*.c" -delete

	run_cheesemake package

	assert_status 0
	assert_no_file build/bin/greeter
}

. "$SHUNIT2"
