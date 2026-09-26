#!/bin/bash
# Pi agent overrides: model routing -> OpenRouter auto-router
#
# Sets the pi agent to use OpenRouter's auto-router for cost-efficient
# model selection, replacing any previous provider-specific config.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
HERE="$OVERRIDES"

pi_dir=~/.pi/agent
pi_settings="$pi_dir/settings.json"

if [[ ! -d $pi_dir ]]; then
  skip "~/.pi/agent not found — pi not installed or configured differently"
  exit 0
fi

mkdir -p "$pi_dir"
backup "$pi_settings"

# Merge OpenRouter settings into the existing config, preserving everything
# else (theme, tuiMode, etc.). Drop provider-specific keys that conflict.
if [[ -s $pi_settings ]]; then
  _tmp=$(mktemp)
  jq '
    .defaultProvider = "openrouter" |
    .defaultModel = "openrouter/auto" |
    del(.modelThinkingLevels)
  ' "$pi_settings" > "$_tmp"
  mv "$_tmp" "$pi_settings"
else
  # No existing settings — write a minimal one
  cat > "$pi_settings" <<'JSON'
{
  "defaultProvider": "openrouter",
  "defaultModel": "openrouter/auto"
}
JSON
fi

say "pi agent: routed through OpenRouter auto-router"
