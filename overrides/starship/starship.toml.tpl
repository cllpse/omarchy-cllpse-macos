add_newline = true
command_timeout = 200
format = "[$directory${custom.git_branch}$git_status]($style)$character"

[character]
error_symbol = "[✗](bold {{ accent }})"
success_symbol = "[❯](bold {{ accent }})"

[directory]
style = "bold {{ accent }}"
truncation_length = 0
truncation_symbol = "…/"
truncate_to_repo = false
repo_root_format = "[$path]($style)[$read_only]($read_only_style) "

# Replaces the built-in [git_branch] module, which is otherwise identical in
# format and style. The built-in truncates from the head only
# (`truncation_length` keeps a prefix and appends `truncation_symbol`), so a
# branch like chromium-scale-and-ghostty-fixes becomes chromium-scale-and-ghost…
# -- the end, which is usually the part that distinguishes one branch from its
# neighbours, is what gets thrown away. Starship has no middle-truncation
# option, so this does it in a custom module instead.
#
# 24 characters total, ellipsis included: 11 head + `…` + 12 tail. Anything
# shorter is printed whole.
#
# `when = true` is the boolean, not a shell command -- it costs no process.
# The conditional group in `format` (the outer parentheses) is what keeps the
# trailing space from surviving into a non-repo prompt: Starship renders a
# `(...)` group only when the variables inside it are non-empty, and a bare
# `[$output]($style) ` would leave a stray space in every directory that isn't
# a git repo. It also strips trailing whitespace from command output, so the
# space cannot be smuggled out of the command either.
#
# Verified against the built-in in all four states -- on a branch, detached
# (both print HEAD), in a repo with no commits yet (both print the unborn
# branch name), and outside a repo (both print nothing at all).
[custom.git_branch]
when = true
shell = ["bash", "--noprofile", "--norc"]
# One git call on the common path. `symbolic-ref` is what covers a repo with
# no commits yet -- `rev-parse --abbrev-ref HEAD` fails there, and is only
# reached when HEAD is detached (it prints the literal "HEAD", matching the
# built-in) or when there is no repo at all, where it fails too and the module
# prints nothing.
command = '''
branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) \
  || branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) \
  || exit 0
if [ ${#branch} -gt 24 ]; then branch="${branch:0:11}…${branch: -12}"; fi
printf '%s' "$branch"
'''
format = "([$output]($style) )"
style = "italic {{ accent }}"

[git_status]
format     = '[$all_status]($style)'
style      = "{{ accent }}"
ahead      = "⇡${count} "
diverged   = "⇕⇡${ahead_count}⇣${behind_count} "
behind     = "⇣${count} "
conflicted = " "
up_to_date = " "
untracked  = "? "
modified   = "m "
stashed    = ""
staged     = ""
renamed    = ""
deleted    = "✗ "
