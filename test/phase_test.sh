#! /usr/bin/env bash

# What each phase does, and that every phase implies the earlier ones.

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

testValidateOnlyPreparesTheBuildDirectories()
{
	run_cheesemake validate

	assert_status 0
	assert_output_contains 'Making greeter'
	assert_directory build/bin
	assert_directory build/lib
	assert_directory build/include
	assert_no_directory build/src
	assert_output_lacks '-c -o'
}

testCompileBuildsObjectsButNoBinary()
{
	run_cheesemake compile

	assert_status 0
	assert_file build/src/greeting.o
	assert_file build/src/greeter.o
	assert_no_file build/bin/greeter
	assert_output_lacks 'build/test/greeting_test'
}

testTestPhaseCompilesLinksAndRunsTheTests()
{
	run_cheesemake test

	assert_status 0
	assert_file build/test/greeting_test.o
	assert_file build/test/greeting_test
	assert_output_contains 'build/test/greeting_test'
	assert_no_file build/bin/greeter
}

testTestExecutablesAreLinkedWithoutTheApplicationMain()
{
	run_cheesemake test

	assert_status 0
	assert_contains "$(output_line 'gcc -o build/test/greeting_test ')" 'build/src/greeting.o'
	assert_lacks "$(output_line 'gcc -o build/test/greeting_test ')" 'build/src/greeter.o'
}

testPackageCreatesTheExecutableAndCopiesHeaders()
{
	run_cheesemake package

	assert_status 0
	assert_file build/bin/greeter
	assert_file build/include/greeting.h
}

testVerifySucceedsWithoutPlugins()
{
	run_cheesemake verify

	assert_status 0
	assert_file build/bin/greeter
}

testRunExecutesTheBinaryWithTheRecipeArguments()
{
	run_cheesemake run

	assert_status 0
	assert_output_contains 'build/bin/greeter world'
	assert_output_contains 'hello world'
}

testRunWithoutArgumentsInTheRecipe()
{
	edit_recipe 'del(.args)'

	run_cheesemake run

	assert_status 0
	assert_output_contains 'hello'
	assert_output_lacks 'world'
}

testEveryPhaseRunsInOrderUpToTheOneRequested()
{
	run_cheesemake run

	assert_status 0
	assert_before 'Making greeter' 'src/greeting.c'
	assert_before 'src/greeting.c' 'test/greeting_test.c'
	assert_before 'test/greeting_test.c' 'gcc -o build/bin/greeter'
	assert_before 'gcc -o build/bin/greeter' 'hello world'
}

. "$SHUNIT2"
