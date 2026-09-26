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
