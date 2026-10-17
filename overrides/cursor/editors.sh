# shellcheck shell=bash
# The editors the cursor/ overrides apply to, in one place. cursor.sh, the
# theme-set hook (hooks/theme-set.d/cursor-chrome.sh) and revert.sh all read
# this table, so adding an editor is one more case below and one more apply.sh
# step (`run:cursor <id>`). Settings only that editor takes go in
# settings.<id>.json beside settings.json; cursor.sh merges it on top.
#
# VS Code is Microsoft's build, visual-studio-code-bin, which is what
# omarchy-install-editor-vscode installs. Code - OSS (`code`) and VSCodium keep
# their profiles in `Code - OSS` / `VSCodium` and extensions in ~/.vscode-oss,
# so they would each be a case of their own.
#
#   EDITOR_ID    apply.sh's step id, and cursor.sh's argument
#   EDITOR_NAME  for messages
#   EDITOR_BIN   the launcher its package installs
#   EDITOR_USER  the profile's User dir: settings.json, globalStorage/
#   EDITOR_EXT   where its marketplace extensions unpack (Bearded's theme JSON)
#   EDITOR_HOOK  the name its link gets in ~/.config/omarchy/hooks/theme-set.d/

EDITORS=(cursor vscode)

editor_spec() { # $1 id
  case $1 in
    cursor)
      EDITOR_NAME=Cursor
      EDITOR_BIN=/usr/bin/cursor
      EDITOR_USER="$HOME/.config/Cursor/User"
      EDITOR_EXT="$HOME/.cursor/extensions"
      EDITOR_HOOK=cursor-chrome.sh ;;
    vscode)
      EDITOR_NAME="VS Code"
      EDITOR_BIN=/usr/bin/code
      EDITOR_USER="$HOME/.config/Code/User"
      EDITOR_EXT="$HOME/.vscode/extensions"
      EDITOR_HOOK=vscode-chrome.sh ;;
    *) return 1 ;;
  esac
  EDITOR_ID=$1
}

# The editor a theme-set hook link belongs to, by the link's name.
editor_by_hook() { # $1 link name
  local id
  for id in "${EDITORS[@]}"; do
    editor_spec "$id" && [[ $EDITOR_HOOK == "$1" ]] && return 0
  done
  return 1
}
