# themed/

Data, not a step — the one directory here with **no `themed.sh`**, because
nothing in it is installed by a script of its own.

`ytm-player.toml.tpl` is an Omarchy *template*. Omarchy's own renderer
(`omarchy-theme-set-templates`) walks `~/.config/omarchy/themed/*.tpl` on every
theme-set, resolves `{{ … }}` against the active `colors.toml` — including
`{{ mix }}` and every derived key — and writes the result into the generated
theme directory. Putting a template there is how an app gets a per-theme config
without anyone writing a hook to bake one.

It is [`ytm/ytm.sh`](../ytm/README.md) that symlinks this file into
`~/.config/omarchy/themed/`, which is why the override lives under `ytm/` and
only the template lives here. See [`../ytm/README.md`](../ytm/README.md) for why
ytm-player needs a baked palette at all rather than reading the terminal's.

Adding a `.tpl` here does nothing on its own: something has to link it into
`~/.config/omarchy/themed/` for the renderer to see it.
