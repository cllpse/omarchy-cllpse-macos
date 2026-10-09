# Pi Agent Overrides

## What this does

Sets the `pi` coding agent's model routing to use **OpenRouter's auto-router**, which dynamically selects the most cost-effective model per request without sacrificing quality.

## Files touched

- `~/.pi/agent/settings.json` — sets `defaultProvider` and `defaultModel`

## Why OpenRouter auto-router

The auto-router (`openrouter/auto`) balances cost and quality by routing each prompt to the cheapest model OpenRouter believes can handle it. This eliminates the need to manually manage quotas across multiple provider subscriptions.

## What changes

Keys updated in `~/.pi/agent/settings.json`:
- `defaultProvider` → `"openrouter"`
- `defaultModel` → `"openrouter/auto"`
- Any stale `modelThinkingLevels` from previous providers is removed

All other settings (theme, TUI mode, etc.) are preserved.

## 1. Guarded, so it cannot stop a run

The merge needs `jq`. Missing `jq`, or a `settings.json` that is not a JSON
object `jq` can read (a hand edit with a comment in it), skips the step with a
line saying which, instead of aborting `apply.sh` under `set -e` — which is
what the unguarded call did until 2026-10-09. A file that already routes
through `openrouter/auto` with no `modelThinkingLevels` is left untouched, and
the rewrite goes through the existing file rather than `mv`, so its mode and
inode survive.

## 2. What `revert.sh` puts back

The three keys this step owns, and nothing else: `defaultProvider`,
`defaultModel` and `modelThinkingLevels`, as they were before the first apply,
recorded in `$STATE/previous-pi-routing` (a key that was absent is recorded as
`null` and deleted again). Restoring the `.pre-cllpse` backup wholesale would
also roll back whatever pi itself wrote since — the theme, the TUI mode — so it
is kept only as a fallback, the same rule `shell.json` follows. Where a backup
exists it *is* the pre-apply state, so the record is taken from it rather than
from the live file, which an earlier apply may already have rewritten. Nothing
recorded means the file already matched, and revert leaves it alone.
