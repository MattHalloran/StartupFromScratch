#!/bin/bash
# Runs all *.bats files in the scripts directory and subdirectories and provides a summary

# Determine this script directory and set up library path for BATS
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# Ensure BATS helper libraries are discoverable by bats_load_library
export BATS_LIB_PATH="${HERE}/helpers:${BATS_LIB_PATH-}"
source "${HERE}/../utils/index.sh"

SCRIPTS_DIR=$(dirname "${HERE}")

total_tests=0
total_failures=0

header "Running bats tests..."

# Run all tests in the scripts directory and subdirectories
while IFS= read -r test_file; do
    # Run bats with TAP output and capture it
    output=$(bats --tap "${test_file}")
    exit_code=$?

    # If the bats command failed, consider it a failure
    if [ $exit_code -ne 0 ] && ! echo "${output}" | grep -q "^not ok"; then
        error "Failed to run test: ${test_file}. Got exit code: ${exit_code}"
        total_failures=$((total_failures + 1))
        continue
    fi

    # Count tests and failures
    tests=$(echo "${output}" | grep -c "^ok\|^not ok")
    failures=$(echo "${output}" | grep -c "^not ok")

    # Add to totals
    total_tests=$((total_tests + tests))
    total_failures=$((total_failures + failures))

    # Print the original output
    echo "${output}"
done < <(find "${SCRIPTS_DIR}" -path "${SCRIPTS_DIR}/__tests/helpers" -prune -o -type f -name '*.bats' -print)

# Print summary
echo ""
info "Total tests run: ${total_tests}"
if [ ${total_failures} -eq 0 ]; then
    success "All tests passed successfully!"
else
    error "Total failures: ${total_failures}"
fi

# Exit with appropriate code
if [ ${total_failures} -eq 0 ]; then
    exit 0
else
    exit 1
fi
