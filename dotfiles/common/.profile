#!/usr/bin/env bash

# ~/.profile: Login shell entry point. Sources skel files with local override support.
# Implements three-tier skel sourcing:
# Tier 1: User local override (~/.local/share/etc/skel/.profile)
# Tier 2: System skel (/etc/skel/.profile)
# Tier 3: Fallback to ~/.bashrc if no skel files exist

# Tier 1: Check for local skel override
if [[ -f "${SKEL_LOCAL_PROFILE:-${HOME}/.local/share/etc/skel/.profile}" ]]; then
	# shellcheck source=/etc/skel/.profile
	source "${SKEL_LOCAL_PROFILE:-${HOME}/.local/share/etc/skel/.profile}" || true
# Tier 2: Check for system skel
elif [[ -f "${SKEL_SYSTEM_PROFILE:-/etc/skel/.profile}" ]]; then
	# shellcheck source=/etc/skel/.profile
	source "${SKEL_SYSTEM_PROFILE:-/etc/skel/.profile}" || true
# Tier 3: Fallback to .bashrc
elif [[ -f "${HOME}/.bashrc" ]]; then
	# shellcheck source=.bashrc
	source "${HOME}/.bashrc" || true
fi
