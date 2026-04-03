#!/usr/bin/env bash
set -euo pipefail

# Backup directory — overridable via TRASH_DIR environment variable (per D-01)
TRASH_DIR="${TRASH_DIR:-$HOME/.trash}"

# safe_delete FILE
#
# Moves FILE to $TRASH_DIR/{sha256hash} and records metadata.
# Returns 0 if FILE does not exist (no-op). (per BACK-02)
# Creates $TRASH_DIR automatically if absent. (per BACK-03)
#
# Usage: source lib/safe-delete.sh && safe_delete /path/to/file
safe_delete() {
    local file="$1"

    # BACK-02: no-op if file absent
    [[ -f "$file" ]] || return 0

    # BACK-03: ensure backup dir exists
    mkdir -p "$TRASH_DIR"

    # BACK-01: compute content hash and move file
    local hash
    hash=$(sha256sum "$file" | awk '{print $1}')

    mv "$file" "$TRASH_DIR/$hash"

    # Record metadata (JSON Lines, append-only)
    local date
    date=$(date -u '+%Y-%m-%dT%H:%M:%S')
    printf '{"hash":"%s","path":"%s","date":"%s"}\n' \
        "$hash" "$file" "$date" >>"$TRASH_DIR/metadata.jsonl"
}
