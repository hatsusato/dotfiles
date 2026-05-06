#!/usr/bin/env bash
# dtach-based bash session manager.
# Provides interactive menu for creating and attaching to persistent bash sessions.

# btash
# Interactive dtach session manager with menu-driven interface.
# Sessions are stored as socket files in $XDG_RUNTIME_DIR/btash/.
# Usage: btash
btash() {
	local socket_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/btash"

	# Check dtach availability
	if ! command -v dtach &>/dev/null; then
		echo "Error: dtach not installed. Install with: apt install dtach" >&2
		return 1
	fi

	# Validate runtime directory exists before trying to create socket dir
	local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
	if [[ ! -d "${runtime_dir}" ]]; then
		echo "Error: Runtime directory does not exist: ${runtime_dir}" >&2
		echo "Hint: Set XDG_RUNTIME_DIR or ensure /run/user exists" >&2
		return 1
	fi

	# Ensure socket directory exists
	mkdir -p "${socket_dir}" || {
		echo "Error: Failed to create socket directory: ${socket_dir}" >&2
		return 1
	}

	# List existing sessions using nullglob to handle empty directory safely
	local sessions=()
	local session_file
	shopt -s nullglob
	for session_file in "${socket_dir}"/*; do
		sessions+=("$(basename "${session_file}")")
	done
	shopt -u nullglob

	# Build menu options: new session first, then attach options
	local options=("Create new session")
	local session
	for session in "${sessions[@]}"; do
		options+=("Attach to: ${session}")
	done

	# Show interactive select menu; $choice holds the selected label
	local choice
	PS3="Select action: "
	select choice in "${options[@]}"; do
		case "${choice}" in
		"Create new session")
			# Create new session with auto-generated ID (PID + timestamp)
			local session_id
			session_id="btash-$$-$(date +%s)"
			dtach -c "${socket_dir}/${session_id}" bash
			;;
		Attach\ to:\ *)
			# Attach to existing session; strip the "Attach to: " prefix
			local selected="${choice#Attach to: }"
			dtach -a "${socket_dir}/${selected}" bash
			;;
		*)
			echo "Invalid selection" >&2
			;;
		esac
		break
	done
}
