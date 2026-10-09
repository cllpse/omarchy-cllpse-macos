#!/bin/bash
# Pi agent overrides: model routing -> OpenRouter auto-router
#
# Sets the pi agent to use OpenRouter's auto-router for cost-efficient
# model selection, replacing any previous provider-specific config.
#
# See README.md in this directory for what this does and why.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

pi_dir=~/.pi/agent
pi_settings="$pi_dir/settings.json"
# The three keys this step owns, as revert.sh reads them back. An absent key is
# recorded as null, which revert turns back into an absent key.
OWNED='{defaultProvider, defaultModel, modelThinkingLevels}'
OURS='{"defaultProvider":"openrouter","defaultModel":"openrouter/auto","modelThinkingLevels":null}'

if [[ ! -d $pi_dir ]]; then
  skip "~/.pi/agent not found — pi not installed or configured differently"
  exit 0
fi

# See README.md (1)
if ! command -v jq >/dev/null 2>&1; then
  skip "jq not installed — pi's routing left alone (pacman -S jq)"
  exit 0
fi
if [[ -s $pi_settings ]] && ! jq -e 'type == "object"' "$pi_settings" >/dev/null 2>&1; then
  skip "$pi_settings is not a JSON object jq can read — left alone; merge by hand:"
  skip "  defaultProvider \"openrouter\", defaultModel \"openrouter/auto\", no modelThinkingLevels"
  exit 0
fi

# See README.md (2)
# What the keys held before the FIRST apply. A .pre-cllpse backup is that state
# when it exists -- it predates this record, which was added later -- so it wins
# over the live file, which may already be ours.
_prior_src=$pi_settings
[[ -s $pi_settings.pre-cllpse ]] && _prior_src=$pi_settings.pre-cllpse
if [[ -s $_prior_src ]]; then
  _prior=$(jq -c "$OWNED" "$_prior_src" 2>/dev/null || true)
else
  _prior=$(jq -nc "{} | $OWNED")
fi
record_prior "$STATE/previous-pi-routing" "$_prior" "$OURS"

if [[ -s $pi_settings && "$(jq -c "$OWNED" "$pi_settings")" == "$OURS" ]]; then
  skip "pi agent already routed through OpenRouter's auto-router"
  exit 0
fi

backup "$pi_settings"

# Merge OpenRouter settings into the existing config, preserving everything
# else (theme, tuiMode, etc.). Drop provider-specific keys that conflict.
if [[ -s $pi_settings ]]; then
  _tmp=$(mktemp)
  jq '
    .defaultProvider = "openrouter" |
    .defaultModel = "openrouter/auto" |
    del(.modelThinkingLevels)
  ' "$pi_settings" >"$_tmp"
  # Through the original file, not mv, to keep its mode and inode -- the same
  # rule sync_fenced follows.
  [[ -s $_tmp ]] && cat "$_tmp" >"$pi_settings"
  rm -f "$_tmp"
else
  # No existing settings — write a minimal one
  cat >"$pi_settings" <<'JSON'
{
  "defaultProvider": "openrouter",
  "defaultModel": "openrouter/auto"
}
JSON
fi

say "pi agent: routed through OpenRouter auto-router"
