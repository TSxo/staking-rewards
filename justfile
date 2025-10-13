# Runs just --list.
default:
  just --list

# Builds all contracts.
build:
  forge build

# Run all the tests.
test:
    forge test -vvv

# Run all the tests and produce a gas report.
test-gas:
    forge test -vvv --gas-report

# Runs coverage, printing a summary to stdout.
coverage-summary:
    forge coverage --no-match-coverage "(script|mocks|test)" --report summary

# Runs coverage, producing an lcov report.
coverage-lcov:
    forge coverage --no-match-coverage "(script|mocks|test)" --report lcov --lcov-version 2.3

# Generates an HTML coverage report from an lcov.info file.
coverage-genhtml:
    mkdir -p coverage && genhtml lcov.info --branch-coverage --output-dir coverage

# Removes all coverage data.
coverage-clean:
    rm -rf coverage lcov.info

# Opens the HTML coverage report.
coverage-open:
    open ./coverage/index.html

# Runs coverage, generates an HTML report, and opens the report.
coverage: coverage-clean coverage-lcov coverage-genhtml coverage-open
