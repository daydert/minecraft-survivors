#!/bin/sh
set -eu
. "$HOME/.config/codex-cinematics/tools.env"
export DISABLE_TELEMETRY BLENDERMCP_NO_UPDATE_CHECK BLENDER_USER_CONFIG BLENDER_USER_SCRIPTS
exec "$BLENDER_PATH" "$@"
