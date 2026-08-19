#! /usr/bin/env bash

# Dependencies resolved through pkg-config, their scopes, and defines.
#
# The dependencies example depends on glib-2.0 for everything it builds and on
# check for its tests only, and defines DEBUG and OS.

. "$(dirname "$(readlink -f "$0")")/helpers.sh"

oneTimeSetUp()
{
	GLIB_INCLUDES="$(pkg-config --cflags-only-I glib-2.0)"
}

setUp()
{
	set_up_workspace
	copy_example dependencies
}

tearDown()
{
	tear_down_workspace
}

testPackageDependencyAddsIncludeAndLinkFlags()
{
	run_cheesemake run

	assert_status 0
	assert_contains "$(output_line 'src/counter.c')" "$GLIB_INCLUDES"
	assert_contains "$(output_line 'gcc -o build/bin/wordcount')" '-lglib-2.0'
	assert_output_contains '3 words'
}

testTestScopedDependencyIsUsedForTestsOnly()
{
	run_cheesemake package

	assert_status 0
	assert_contains "$(output_line 'gcc -o build/test/counter_test')" '-lcheck'
	assert_lacks "$(output_line 'gcc -o build/bin/wordcount')" '-lcheck'
}

# Only the exit status is left out of this test. The link line is what the
# scope decides, and it is checked; whether the link then succeeds depends on
# the host having static versions of libcheck and the C libraries it drags in.
testStaticScopedDependencyIsLinkedStatically()
{
	edit_recipe '.dependencies |= map(if .package == "check" then .scope = "test,static" else . end)'

	run_cheesemake package

	assert_contains "$(output_line 'gcc -o build/test/counter_test')" '-Wl,-Bstatic -lcheck'
}

testUnknownPackageFailsTheBuild()
{
	edit_recipe '.dependencies |= map(if .package == "glib-2.0" then .package = "nosuchpackage" else . end)'

	run_cheesemake package

	assert_status 1
	assert_no_file build/bin/wordcount
}

testDefinesArePassedToTheCompiler()
{
	run_cheesemake run

	assert_status 0
	assert_contains "$(output_line 'src/counter.c')" '-DDEBUG'
	assert_contains "$(output_line 'src/counter.c')" "-DOS=$(uname)"
	assert_output_contains "built for $(uname)"
}

testDefineWhoseCommandFailsIsOmitted()
{
	edit_recipe '.define.OS = "false"'

	run_cheesemake compile

	assert_status 0
	assert_contains "$(output_line 'src/counter.c')" '-DDEBUG'
	assert_lacks "$(output_line 'src/counter.c')" '-DOS'
}

. "$SHUNIT2"
