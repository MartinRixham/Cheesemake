#! /usr/bin/env bash

# The packaging options, the artefacts they produce and the linker used.
#
# There is an example for each packaging: executable, shared-library and
# static-library. The innermost module of the modules example is packaged
# both ways at once.

. "$(dirname "$(readlink -f "$0")")/helpers.sh"

setUp()
{
	set_up_workspace
}

tearDown()
{
	tear_down_workspace
}

testExecutablePackagingCreatesABinary()
{
	copy_example executable

	run_cheesemake package

	assert_status 0
	assert_file build/bin/greeter
	assert_no_file build/lib/libgreeter.so
	assert_output_lacks '-fPIC'
}

testSharedPackagingCreatesASharedObjectCompiledPositionIndependent()
{
	copy_example shared-library

	run_cheesemake package

	assert_status 0
	assert_file build/lib/libgeometry.so
	assert_no_file build/bin/geometry
	assert_contains "$(output_line 'src/area.c')" '-fPIC'
	assert_contains "$(output_line 'build/lib/libgeometry.so')" '-shared'
}

testArchivePackagingCreatesAStaticLibrary()
{
	copy_example static-library

	run_cheesemake package

	assert_status 0
	assert_file build/lib/libchecksum.a
	assert_output_contains 'ar rcs build/lib/libchecksum.a'
	assert_no_file build/lib/libchecksum.so
}

testSharedAndArchivePackagingCreatesBoth()
{
	copy_example modules/middle/bottom

	run_cheesemake package

	assert_status 0
	assert_file build/lib/libbottom.so
	assert_file build/lib/libbottom.a
}

testHeadersAreCopiedPreservingSubdirectories()
{
	copy_example shared-library

	run_cheesemake package

	assert_status 0
	assert_file build/include/area.h
	assert_file build/include/shape/circle.h
}

testRunningASharedLibraryFails()
{
	copy_example shared-library

	run_cheesemake run

	assert_status 1
	assert_output_contains 'Library build/lib/libgeometry.so is not executable.'
}

testRunningAnArchiveFails()
{
	copy_example static-library

	run_cheesemake run

	assert_status 1
	assert_output_contains 'Library build/lib/libchecksum.a is not executable.'
}

testTheRecipeLinkerIsUsedInsteadOfTheCompiler()
{
	copy_example executable

	write "$WORK/bin/mylinker" <<'EOF'
#! /usr/bin/env bash

exec gcc "$@"
EOF
	chmod +x "$WORK/bin/mylinker"

	edit_recipe ".linker = \"$WORK/bin/mylinker\""

	run_cheesemake package

	assert_status 0
	assert_file build/bin/greeter
	assert_output_contains "$WORK/bin/mylinker -o build/bin/greeter"
	assert_contains "$(output_line 'src/greeting.c')" 'gcc -g -Wall'
}

testTheCompilerLinksWhenNoLinkerIsGiven()
{
	copy_example executable

	run_cheesemake package

	assert_status 0
	assert_output_contains 'gcc -o build/bin/greeter'
}

. "$SHUNIT2"
