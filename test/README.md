# Cheesemake tests

Tests for the `cheesemake` script itself, written with
[shunit2](https://github.com/kward/shunit2). The fixtures are the
[examples](../example): each of them is about one thing, so a test copies the
example that is about the thing it is testing into a temporary directory and
runs the script there. Nothing a test does touches the examples themselves.

A test edits the recipe or a source it has copied only where that variation is
what is being tested, an unknown package or a plugin that fails. Anything a
test would want for its own convenience belongs in an example of its own
instead.

### Dependencies

Whatever cheesemake needs (Bash, jq, pkg-config, OpenSSL, gcc, binutils),
whatever the examples need (glib-2.0 and check for `dependencies`, check and
cppcheck and valgrind and gcovr and gprof for `plugins`) plus shunit2. If
shunit2 is not in one of the usual places, set `SHUNIT2` to the path of the
script.

### Run

	./test/run_tests.sh                 # everything
	./test/run_tests.sh module_test.sh  # one script

### The scripts

| Script | Covers | Example |
| --- | --- | --- |
| `cli_test.sh` | usage, exit statuses, task dispatch, several tasks at once, clean | `executable` |
| `phase_test.sh` | what each phase does and that a phase implies the earlier ones | `executable` |
| `packaging_test.sh` | executable, shared and archive packaging, headers, the recipe linker | `executable`, `shared-library`, `static-library`, `modules` |
| `dependency_test.sh` | pkg-config dependencies, their scopes and defines | `dependencies` |
| `plugin_test.sh` | where plugins are found, what they are passed, what their failure does | `plugins` |
| `module_test.sh` | module build order, propagation of binaries, rebuilding, failure | `modules` |
| `incremental_test.sh` | what the hashes in `build/hashes` cause to be compiled again | `executable`, `shared-library` |
| `failure_test.sh` | compilation, test, link and recipe failures | `executable` |
