#! /usr/bin/env bash

# The command line: usage, exit statuses, task dispatch and clean.

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

testNoArgumentsPrintsUsageAndSucceeds()
{
	run_cheesemake

	assert_status 0
	assert_output_contains 'usage: cheesemake [clean] <phase>'
	assert_output_contains ' validate'
	assert_output_contains ' compile'
	assert_output_contains ' test'
	assert_output_contains ' package'
	assert_output_contains ' verify'
	assert_output_contains ' run'
}

testUnknownPhasePrintsUsageAndFails()
{
	run_cheesemake sandwich

	assert_status 1
	assert_output_contains 'usage: cheesemake [clean] <phase>'
	assert_no_directory build
}

testUsageNamesTheScriptAsItWasInvoked()
{
	ln -s "$CHEESEMAKE" "$WORK/cmk"
	CHEESEMAKE_BIN="$WORK/cmk"

	run_cheesemake

	assert_status 0
	assert_output_contains 'usage: cmk [clean] <phase>'
}

testCleanRemovesTheBuildDirectory()
{
	run_cheesemake package
	assert_status 0
	assert_file build/bin/greeter

	run_cheesemake clean

	assert_status 0
	assert_no_directory build
}

testCleanOnAnUnbuiltProjectSucceeds()
{
	run_cheesemake clean

	assert_status 0
	assert_no_directory build
}

testSeveralTasksRunInTheOrderGiven()
{
	run_cheesemake package
	assert_file build/bin/greeter

	run_cheesemake clean compile

	assert_status 0
	assert_file build/src/greeting.o
	assert_no_file build/bin/greeter
}

testPhasesCanBeRunIndividually()
{
	local phase

	for phase in validate compile test package verify run; do
		run_cheesemake "$phase"
		assertEquals "phase $phase failed with:
$OUTPUT" 0 "$STATUS"
	done
}

. "$SHUNIT2"
