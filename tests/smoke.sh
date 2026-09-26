#!/usr/bin/env bash
set -euo pipefail

# qs.Ui and qs.Commons resolve relative to the Quickshell configuration root.
# Stage links in a temporary root, leaving the installed shell untouched.
project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
shell_dir="${OMARCHY_PATH:-/usr/share/omarchy}/shell"
check_dir=$(mktemp -d /tmp/omamath-smoke.XXXXXX)
trap 'rm -rf -- "$check_dir"' EXIT
ln -s "$shell_dir/Ui" "$check_dir/Ui"
ln -s "$shell_dir/Commons" "$check_dir/Commons"
ln -s "$project_dir" "$check_dir/Plugin"
cp "$project_dir/tests/smoke.qml" "$check_dir/shell.qml"
if ! timeout 15s quickshell -p "$check_dir" --no-color > "$check_dir/output.log" 2>&1; then
    cat "$check_dir/output.log"
    exit 1
fi
cat "$check_dir/output.log"
grep -q 'OMAMATH_SMOKE_OK' "$check_dir/output.log"
if grep -Eq 'OMAMATH_SMOKE_FAILED|ERROR|ReferenceError|TypeError|Binding loop' "$check_dir/output.log"; then
    exit 1
fi
