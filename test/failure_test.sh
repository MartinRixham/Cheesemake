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

testMissingRecipeStopsTheBuild()
{
	rm "$PROJECT/recipe.json"

	run_cheesemake compile

	assert_status 1
	assert_output_contains 'recipe.json'
	assert_output_lacks 'command not found'
	assert_no_file build/src/greeting.o
}

testInvalidRecipeStopsTheBuild()
{
	write "$PROJECT/recipe.json" <<'EOF'
{ this is not json
EOF

	run_cheesemake compile

	assert_status 1
	assert_output_contains 'recipe.json'
	assert_no_file build/src/greeting.o
}

testMissingRecipeWithNothingToCompileStopsTheBuild()
{
	rm "$PROJECT/recipe.json"
	find "$PROJECT/src" "$PROJECT/test" -name "*.c" -delete

	run_cheesemake package

	assert_status 1
	assert_output_contains 'recipe.json'
	assert_no_file build/bin/greeter
}

. "$SHUNIT2"
