#! /usr/bin/env bash

# Runs the whole suite, or the scripts named on the command line.
#
#	./test/run_tests.sh
#	./test/run_tests.sh module_test.sh
#
# Set SHUNIT2 if shunit2 is not in one of the usual places.

set -u

cd "$(dirname "$(readlink -f "$0")")"

scripts=("$@")

if [[ ${#scripts[@]} -eq 0 ]]; then
	scripts=(*_test.sh)
fi

status=0
failed=()

for script in "${scripts[@]}"; do
	echo "-------------------------------------------------------
    $script
-------------------------------------------------------"

	if ! bash "$script"; then
		status=1
		failed+=("$script")
	fi
done

if [[ ${#failed[@]} -gt 0 ]]; then
	echo "failed: ${failed[*]}"
fi

exit $status
