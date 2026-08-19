#! /usr/bin/env bash

# Modules: build order, propagation of binaries, rebuilding and failure.
#
# The modules example is top, which is built from middle, which is built from
# bottom.

. "$(dirname "$(readlink -f "$0")")/helpers.sh"

setUp()
{
	set_up_workspace
	copy_example modules
}

tearDown()
{
	tear_down_workspace
}

testModuleIsBuiltBeforeTheProjectThatUsesIt()
{
	run_cheesemake run

	assert_status 0
	assert_before 'Making middle' 'Making top'
	assert_file middle/build/lib/libmiddle.so
	assert_file build/lib/libmiddle.so
	assert_file build/include/middle.h
	assert_output_contains 'modules 11 1'
}

testNestedModulesAreBuiltFromTheBottomUp()
{
	run_cheesemake run

	assert_status 0
	assert_before 'Making bottom' 'Making middle'
	assert_before 'Making middle' 'Making top'
	assert_file build/lib/libbottom.so
	assert_file build/include/bottom.h
	assert_output_contains 'modules 11 1'
}

testProjectLinksAgainstItsModules()
{
	run_cheesemake package

	assert_status 0
	assert_contains "$(output_line 'gcc -o build/bin/top')" '-lmiddle'
	assert_contains "$(output_line 'gcc -o build/bin/top')" '-lbottom'
	assert_contains "$(output_line 'gcc -o build/bin/top')" '-Lbuild/lib'
}

testModuleScopedDependencyIsNotLookedUpWithPkgConfig()
{
	# Neither middle nor bottom is a pkg-config package; the build only works
	# because module scoped dependencies are turned straight into -l flags.
	run_cheesemake package

	assert_status 0
	assert_output_lacks 'No package'
	assert_file build/bin/top
}

testUnchangedModuleIsNotRebuilt()
{
	run_cheesemake package
	assert_status 0

	run_cheesemake package

	assert_status 0
	assert_output_lacks 'Making middle'
	assert_output_lacks 'src/middle.c'
}

testChangedModuleSourceRebuildsTheModule()
{
	run_cheesemake run
	assert_status 0

	change_source middle/src/middle.c

	run_cheesemake run

	assert_status 0
	assert_output_contains 'Making middle'
	assert_output_contains '-o build/src/middle.o'
	assert_output_lacks 'Making bottom'
	assert_output_contains 'modules 11 1'
}

testMissingModuleLibraryIsRebuilt()
{
	run_cheesemake package
	assert_status 0

	rm "$PROJECT/build/lib/libmiddle.so"

	run_cheesemake package

	assert_status 0
	assert_output_contains 'Making middle'
	assert_file build/lib/libmiddle.so
	assert_file middle/build/lib/libmiddle.so
}

testDeletingTheModulesOwnLibraryIsNoticed()
{
	run_cheesemake package
	assert_status 0

	rm "$PROJECT/middle/build/lib/libmiddle.so"

	run_cheesemake package

	assert_status 0
	assert_output_contains 'Making middle'
	assert_output_lacks 'src/middle.c'
	assert_file middle/build/lib/libmiddle.so
	assert_file build/lib/libmiddle.so
}

testFailureInAModuleStopsTheProject()
{
	break_source middle/src/middle.c

	run_cheesemake package

	assert_status 1
	assert_no_file build/bin/top
	assert_no_file middle/build/lib/libmiddle.so
}

testCleanAlsoCleansModules()
{
	run_cheesemake package
	assert_status 0
	assert_directory middle/build
	assert_directory middle/bottom/build

	run_cheesemake clean

	assert_status 0
	assert_no_directory build
	assert_no_directory middle/build
	assert_no_directory middle/bottom/build
}

testModuleUsesAPluginFromTheDirectoryTheBuildWasStartedIn()
{
	install_cheesemake_copy
	cp "$EXAMPLE/plugins/lines.chevre" "$PROJECT/lines.chevre"
	edit_recipe '.plugins = [{ "name": "lines", "phase": "validate" }]' "$PROJECT/middle"

	run_cheesemake package

	assert_status 0
	assert_output_contains 'lines of source in middle'
}

testPluginInTheModuleDirectoryTakesPrecedenceOverTheRunDirectory()
{
	install_cheesemake_copy
	cp "$EXAMPLE/plugins/lines.chevre" "$PROJECT/middle/lines.chevre"
	{
		cat "$EXAMPLE/plugins/lines.chevre"
		echo 'echo "counted from the run directory"'
	} > "$PROJECT/lines.chevre"
	edit_recipe '.plugins = [{ "name": "lines", "phase": "validate" }]' "$PROJECT/middle"

	run_cheesemake package

	assert_status 0
	assert_output_contains 'lines of source in middle'
	assert_output_lacks 'counted from the run directory'
}

. "$SHUNIT2"
