#! /usr/bin/env bash

# Rebuilding: what the hashes in build/hashes cause to be compiled again.

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

testEverythingIsCompiledOnTheFirstBuild()
{
	run_cheesemake package

	assert_status 0
	assert_output_contains '-c -o build/src/greeting.o'
	assert_output_contains '-c -o build/src/greeter.o'
	assert_output_contains '-c -o build/test/greeting_test.o'
	assert_file build/hashes
}

testNothingIsCompiledOnTheSecondBuild()
{
	run_cheesemake package
	assert_status 0

	run_cheesemake package

	assert_status 0
	assert_output_lacks '-c -o'
}

testTouchingASourceDoesNotRecompileIt()
{
	run_cheesemake package
	assert_status 0

	touch "$PROJECT/src/greeting.c"

	run_cheesemake package

	assert_status 0
	assert_output_lacks '-c -o'
}

testChangingASourceRecompilesOnlyThatSource()
{
	run_cheesemake package
	assert_status 0

	change_source src/greeting.c

	run_cheesemake package

	assert_status 0
	assert_output_contains '-c -o build/src/greeting.o'
	assert_output_lacks '-c -o build/src/greeter.o'
	assert_output_lacks '-c -o build/test/greeting_test.o'
}

testChangingAHeaderRecompilesEverySourceThatIncludesIt()
{
	run_cheesemake package
	assert_status 0

	change_source src/greeting.h

	run_cheesemake package

	assert_status 0
	assert_output_contains '-c -o build/src/greeting.o'
	assert_output_contains '-c -o build/src/greeter.o'
	assert_output_contains '-c -o build/test/greeting_test.o'
}

testChangingATestRecompilesOnlyTheTest()
{
	run_cheesemake test
	assert_status 0

	change_source test/greeting_test.c

	run_cheesemake test

	assert_status 0
	assert_output_contains '-c -o build/test/greeting_test.o'
	assert_output_lacks '-c -o build/src/'
}

testDeletingAnObjectFileMakesItBuildAgain()
{
	run_cheesemake package
	assert_status 0

	rm "$PROJECT/build/src/greeting.o"

	run_cheesemake package

	assert_status 0
	assert_output_contains '-c -o build/src/greeting.o'
	assert_output_lacks '-c -o build/src/greeter.o'
	assert_file build/src/greeting.o
}

# A library is the case where a source can go away and leave something that
# still builds, so this one is about the shared library example.
testRemovingASourceLeavesAWorkingBuild()
{
	copy_example shared-library

	run_cheesemake package
	assert_status 0
	assert_file build/src/perimeter.o

	rm "$PROJECT/src/perimeter.c" "$PROJECT/src/perimeter.h"
	rm "$PROJECT/test/perimeter_test.c"

	run_cheesemake package

	assert_status 0
	assert_lacks "$(output_line 'gcc -shared -o build/lib/libgeometry.so')" 'build/src/perimeter.o'
	assert_file build/lib/libgeometry.so
}

testAFailedCompilationIsAttemptedAgainOnTheNextBuild()
{
	break_source src/greeting.c

	run_cheesemake package
	assert_status 1
	assert_no_file build/bin/greeter

	restore_example_file src/greeting.c

	run_cheesemake package

	assert_status 0
	assert_output_contains '-c -o build/src/greeting.o'
	assert_file build/bin/greeter
}

testTheExecutableIsLinkedAgainEvenWhenNothingChanged()
{
	run_cheesemake package
	assert_status 0

	run_cheesemake package

	assert_status 0
	assert_output_contains 'gcc -o build/bin/greeter'
}

. "$SHUNIT2"
