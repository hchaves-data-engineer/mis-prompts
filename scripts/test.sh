#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
mkdir -p .build
test_dir="$(mktemp -d "$project_dir/.build/tests.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
swiftc -parse-as-library Sources/Core.swift Tests/Tests.swift -o "$test_dir/tests"
"$test_dir/tests" "$test_dir/data" Resources/Seed.json
