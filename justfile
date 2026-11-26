# ==============================================================================
# Meta and Defaults
# ==============================================================================

set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

# Display available recipes.
[group("meta")]
default:
    @just --list

# Inspect tools without installing or updating.
[group("meta")]
doctor:
    @command -v forge
    @forge --version
    @forge config --json | jq "{solc, evm_version, optimizer, optimizer_runs}"
    @just --version

# Generate API docs from NatSpec into docs/ (gitignored); nothing is installed.
[group("meta")]
doc:
    forge doc

# ==============================================================================
# Formatting
# ==============================================================================

# Format project Solidity files; libraries are excluded.
[group("format")]
fmt:
    forge fmt

# Check formatting without changing files.
[group("format")]
fmt-check:
    forge fmt --check

# ==============================================================================
# Checks
# ==============================================================================

# Compile with the pinned Solidity version and report contract sizes.
[group("check")]
build:
    forge build --sizes

# Run the linter over the contracts and tests.
[group("check")]
lint:
    forge lint src test

# ==============================================================================
# Tests
# ==============================================================================

# Run every suite except the symbolic checks.
[group("test")]
test:
    forge test

# Run unit suites, including their parameter fuzz properties.
[group("test")]
test-unit:
    forge test --match-path "test/unit/**"

# Run the parameter fuzz properties.
[group("test")]
test-fuzz:
    forge test --match-test "^testFuzz_"

# Run the stateful handler campaigns.
[group("test")]
test-invariant:
    forge test --match-path "test/invariant/**"

# Run the cross-contract comparisons.
[group("test")]
test-differential:
    forge test --match-path "test/differential/**"

# Run the larger campaigns configured in the CI profile.
[group("test")]
test-ci:
    forge test --profile ci

# Run named tests, e.g. just test-match "test_Stake.*".
[group("test")]
test-match pattern:
    forge test --match-test {{ quote(pattern) }} -vv

# Print a gas report for the three contracts.
[group("test")]
test-gas:
    forge test --gas-report

# ==============================================================================
# Coverage
# ==============================================================================

# Reports go to .local/, next to the analysis reports. Not cache/, because
# `forge clean` (which Slither runs) deletes it.

coverage_dir := ".local/coverage"
lcov_path := ".local/lcov.info"

# Regenerate coverage and open its HTML report.
[group("coverage")]
coverage: coverage-clean coverage-run coverage-html coverage-open

# Remove generated HTML and LCOV coverage data.
[group("coverage")]
coverage-clean:
    rm -rf -- {{ quote(coverage_dir) }} {{ quote(lcov_path) }}

# Print a summary and write LCOV for src/ only.
[group("coverage")]
coverage-run:
    forge coverage --exclude-tests --no-match-coverage "^(lib|test)/" --report summary --report lcov --report-file {{ quote(lcov_path) }}

# Generate HTML, retaining warnings for Forge's branch-data inconsistencies.
[group("coverage")]
coverage-html:
    mkdir -p {{ quote(coverage_dir) }}
    genhtml {{ quote(lcov_path) }} --branch-coverage --ignore-errors inconsistent --output-directory {{ quote(coverage_dir) }}

# Open the HTML coverage report.
[group("coverage")]
[macos]
coverage-open:
    open {{ quote(coverage_dir + "/index.html") }}

# Open the HTML coverage report.
[group("coverage")]
[linux]
coverage-open:
    xdg-open {{ quote(coverage_dir + "/index.html") }}

# ==============================================================================
# Symbolic Checks
# ==============================================================================

# Native Forge symbolic execution over test/symbolic/. Needs z3 on PATH; the
# Nix dev shell provides it.

# Run native symbolic checks; fails visibly if the solver is unavailable or incomplete.
[group("symbolic")]
symbolic:
    forge test --profile symbolic --symbolic

# Turn confirmed symbolic counterexamples into concrete regression test sources.
[group("symbolic")]
symbolic-regressions:
    forge test --profile symbolic --symbolic --emit-regression

# Replay a symbolic counterexample artifact concretely.
[group("symbolic")]
symbolic-replay artifact:
    forge test --replay-symbolic-artifact {{ quote(artifact) }}

# ==============================================================================
# Mutation Testing
# ==============================================================================

# Advisory only: not part of `just qc` or CI.

mutate_dir := ".local/mutation"

# Forge 1.10 matches `--mutate-path` against absolute paths, so the pattern is
# anchored at the project root; a relative `src/**/*.sol` matches nothing.
sources := justfile_directory() / "src/**/*.sol"

# Mutate every source file and report surviving mutants.
[group("mutate")]
mutate:
    forge test --mutate --mutate-path {{ quote(sources) }}

# Mutate the contracts matching a regex, e.g. just mutate-contract "StakingRewardsMulti".
[group("mutate")]
mutate-contract pattern:
    forge test --mutate --mutate-contract {{ quote(pattern) }}

# Mutate every source file and write the JSON report to .local/mutation/.
[group("mutate")]
mutate-json:
    mkdir -p {{ quote(mutate_dir) }}
    forge test --mutate --mutate-path {{ quote(sources) }} --json > {{ quote(mutate_dir + "/report.json") }}

# ==============================================================================
# Static Analysis
# ==============================================================================

# Advisory only: not part of `just qc` or CI. Reports go to an untracked
# directory for triage.

slither_dir := ".local/slither"

# Run every advisory analysis.
[group("analysis")]
analysis: slither slither-json

# Write Slither findings as a Markdown checklist for triage.
[group("analysis")]
slither:
    mkdir -p {{ quote(slither_dir) }}
    slither . --filter-paths "lib/|test/" --exclude-dependencies --fail-none --checklist > {{ quote(slither_dir + "/slither.md") }}

# Write Slither findings as JSON with detector, severity, and source locations.
[group("analysis")]
slither-json:
    mkdir -p {{ quote(slither_dir) }}
    rm -f -- {{ quote(slither_dir + "/slither.json") }}
    slither . --filter-paths "lib/|test/" --exclude-dependencies --fail-none --json {{ quote(slither_dir + "/slither.json") }}

# ==============================================================================
# Quality
# ==============================================================================

# Standard local gate.
[group("quality")]
qc: fmt-check build lint test
