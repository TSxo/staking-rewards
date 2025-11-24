# ------------------------------------------------------------------------------
# Variables

SECURITY_TOOLS_IMAGE := "ghcr.io/tsxo/evm-security-tools:latest"

# ------------------------------------------------------------------------------
# General

# Runs just --list.
default:
  just --list

# Pulls all Docker images.
docker:
    docker pull {{SECURITY_TOOLS_IMAGE}}

# Runs the EVM Security Tools container.
security-tools:
    docker run -it --rm --platform=linux/amd64 -v $(pwd):/workspace {{SECURITY_TOOLS_IMAGE}}

# Builds all contracts.
build:
  forge build

# ------------------------------------------------------------------------------
# Test

# Run all the tests.
test:
    forge test

# Run all the tests with verbose logging.
test-v:
    forge test -vvv

# Run only unit and fuzz tests.
test-unit:
    forge test --match-path "test/unit/**/*.t.sol"

# Run only unit and fuzz tests with verbose logging.
test-unit-v:
    forge test --match-path "test/unit/**/*.t.sol" -vvv

# Run only the invariant tests.
test-invariant:
    forge test --match-path "test/invariant/**/*.t.sol"

# Run only the invariant tests with verbose logging.
test-invariant-v:
    forge test --match-path "test/invariant/**/*.t.sol" -vvv

# Run only the HEVM formal verification tests.
test-formal:
    hevm test

# Run all the tests and produce a gas report.
test-gas:
    forge test --gas-report

# ------------------------------------------------------------------------------
# Coverage

# Removes all coverage data.
coverage-clean:
    rm -rf coverage lcov.info

# Runs coverage, printing a summary to stdout.
coverage-summary:
    forge coverage --no-match-coverage "(script|mocks|test)" --report summary

# Runs coverage, producing an lcov report.
coverage-lcov:
    forge coverage --no-match-coverage "(script|mocks|test)" --report lcov --lcov-version 2.3

# Generates an HTML coverage report from an lcov.info file.
coverage-genhtml:
    mkdir -p coverage && genhtml lcov.info --branch-coverage --output-dir coverage

# Opens the HTML coverage report.
coverage-open:
    open ./coverage/index.html

# Runs coverage, generates an HTML report, and opens the report.
coverage: coverage-clean coverage-lcov coverage-genhtml coverage-open
