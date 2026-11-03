#! /usr/bin/env bash

# Interrupts: what SIGINT and SIGTERM do to a build that is under way.
#
# The executable example is built with a compiler that, when it is asked to
# compile and for as long as $WORK/slow exists, starts a sleep of its own and
# waits for it before handing over to gcc, so that a test can interrupt the
# build while both sources of the example are compiling at once and see
# whether anything it started is left behind.

. "$(dirname "$(readlink -f "$0")")/helpers.sh"

# How long a test waits for something to happen before giving up on it.
PATIENCE=30

setUp()
{
	set_up_workspace
	copy_example executable
	CHEESEMAKE_PID=''
	SOURCES_COMPILING="$(find "$PROJECT/src" -name '*.c' | wc -l)"

	write "$WORK/slow-gcc" <<EOF
#! /usr/bin/env bash

if [[ -f "$WORK/slow" && " \$* " == *" -c "* ]]; then
	(echo "\$\$ \$BASHPID" >> "$WORK/compiling"; exec sleep 1000)
fi

exec gcc "\$@"
EOF
	chmod +x "$WORK/slow-gcc"
	touch "$WORK/slow"
	edit_recipe ".compiler = \"$WORK/slow-gcc -g -Wall\""
}

tearDown()
{
	if [[ -n "$CHEESEMAKE_PID" ]]; then
		kill -KILL -- "-$CHEESEMAKE_PID" 2> /dev/null
	fi

	if [[ -f "$WORK/compiling" ]]; then
		kill -KILL $(cat "$WORK/compiling") 2> /dev/null
	fi

	tear_down_workspace
}

# Starts cheesemake in the background as a terminal would start it in the
# foreground, in a process group of its own and not ignoring SIGINT, which a
# shell without job control would have its background commands do.
start_cheesemake()
{
	set -m
	(cd "$PROJECT" && exec "$CHEESEMAKE_BIN" "$@" > "$WORK/output" 2>&1) &
	CHEESEMAKE_PID=$!
	set +m
}

# Waits for every source of the example to be compiling.
wait_for_compiles()
{
	local i

	for ((i = 0; i < PATIENCE * 10; i++)); do
		if [[ -f "$WORK/compiling" ]] && [[ "$(wc -l < "$WORK/compiling")" -ge "$SOURCES_COMPILING" ]]; then
			return 0
		fi

		sleep 0.1
	done

	fail "the sources never started compiling, output was:
$(cat "$WORK/output")"
	return 1
}

# Waits for cheesemake to exit, then sets STATUS and OUTPUT as run_cheesemake
# would have.
wait_for_cheesemake()
{
	local i

	for ((i = 0; i < PATIENCE * 10; i++)); do
		if ! kill -0 "$CHEESEMAKE_PID" 2> /dev/null; then
			break
		fi

		sleep 0.1
	done

	if kill -0 "$CHEESEMAKE_PID" 2> /dev/null; then
		kill -KILL -- "-$CHEESEMAKE_PID" 2> /dev/null
		fail "cheesemake did not exit after it was interrupted"
	fi

	wait "$CHEESEMAKE_PID"
	STATUS=$?
	CHEESEMAKE_PID=''
	OUTPUT="$(cat "$WORK/output")"
}

# Whether a process is still running. A process that has been killed but not
# yet reaped, by init once whatever started it has gone, counts as gone.
is_running()
{
	local state

	state="$(cut -d ')' -f 2 "/proc/$1/stat" 2> /dev/null)" || return 1
	[[ -n "$state" && "$state" != ' Z '* ]]
}

# Every compiler that was started, and the sleep each one started, is gone,
# or going: the signals are sent before cheesemake exits, but nothing waits for
# them to be delivered.
assert_nothing_left_running()
{
	local pid
	local i

	for pid in $(cat "$WORK/compiling"); do
		for ((i = 0; i < 50; i++)); do
			is_running "$pid" || break
			sleep 0.1
		done

		assertFalse "process $pid was left running, output was:
$OUTPUT" "is_running $pid"
	done
}

# interrupt_compiles <signal> [group]
#
# Builds the example and, once both of its sources are compiling, sends the
# signal to cheesemake, or with group to its whole process group as pressing
# Ctrl-C at a terminal would.
interrupt_compiles()
{
	local target

	start_cheesemake package
	wait_for_compiles || return 1

	target="$CHEESEMAKE_PID"

	if [[ "${2:-}" == group ]]; then
		target="-$CHEESEMAKE_PID"
	fi

	kill -"$1" -- "$target"
	wait_for_cheesemake
}

testInterruptExitsAsInterrupted()
{
	interrupt_compiles INT || return

	assert_status 130
	assert_output_contains 'cheesemake: interrupted'
}

testInterruptStopsEveryCompileAndWhatItStarted()
{
	interrupt_compiles INT || return

	assert_nothing_left_running
}

testInterruptFromTheTerminalStopsEverything()
{
	interrupt_compiles INT group || return

	assert_status 130
	assert_output_contains 'cheesemake: interrupted'
	assert_nothing_left_running
}

testTerminationExitsAsTerminated()
{
	interrupt_compiles TERM || return

	assert_status 143
	assert_output_contains 'cheesemake: interrupted'
	assert_nothing_left_running
}

testInterruptedBuildGoesNoFurther()
{
	interrupt_compiles INT || return

	assert_no_file build/src/greeter.o
	assert_no_file build/src/greeting.o
	assert_no_file build/bin/greeter
	assert_lacks "$(cat "$PROJECT/build/hashes" 2> /dev/null)" 'src/'
}

testBuildAfterAnInterruptCompilesEverything()
{
	interrupt_compiles INT || return
	restore_example_file recipe.json

	run_cheesemake run

	assert_status 0
	assert_output_contains 'hello world'
	assert_file build/bin/greeter
}

testBuildThatIsNotInterruptedIsUnaffected()
{
	start_cheesemake run
	wait_for_compiles || return
	rm "$WORK/slow"
	kill -KILL $(cut -d ' ' -f 2 "$WORK/compiling")

	wait_for_cheesemake

	assert_status 0
	assert_output_contains 'hello world'
	assert_output_lacks 'interrupted'
}

. "$SHUNIT2"
