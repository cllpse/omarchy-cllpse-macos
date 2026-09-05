# fzf: inherit the terminal's ANSI palette (themed by Omarchy from the active
# theme's colors.toml); tint accents blue to match cllpse-macos. fzf --color
# takes -1 (terminal default) or a colour NUMBER: 4=blue, 2=green, 8=bright-black.
# Appended to ~/.bashrc by overrides/apply.sh.
export FZF_DEFAULT_OPTS='--color=fg:-1,bg:-1,fg+:-1,bg+:-1,hl:4,hl+:4,info:4,prompt:4,pointer:4,spinner:4,header:4,marker:2,border:8'
