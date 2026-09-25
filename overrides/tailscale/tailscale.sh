#!/bin/bash
# Tailscale SSH: let the rest of the tailnet reach this machine's shell.
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh. Nothing here is installed and
# nothing is written outside tailscaled's own prefs -- no sshd, no host keys,
# no authorized_keys, no firewall rule.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

PRIOR="$STATE/previous-tailscale-ssh"

# Read RunSSH out of the daemon's prefs as the string "true"/"false".
# NOT `.RunSSH // empty`: jq's // treats false as absent, which is exactly the
# value worth having here -- see CLAUDE.md's jq entry. Empty means "could not
# read it", which is a different thing from "false" and is handled as such.
read_runssh() {
  tailscale debug prefs 2>/dev/null \
    | jq -r 'if .RunSSH == null then "" else (.RunSSH | tostring) end' 2>/dev/null || true
}

# See README.md (1)
if ! command -v tailscale >/dev/null 2>&1; then
  skip "tailscale not installed — nothing on the tailnet can reach this shell"
  skip "  install it the supported way: omarchy-install-service-tailscale"
  exit 0
fi

# See README.md (2)
backend=$(tailscale status --json 2>/dev/null \
  | jq -r 'if .BackendState == null then "" else .BackendState end' 2>/dev/null || true)
case "$backend" in
  Running) ;;
  "")
    skip "could not read tailscaled's state — is the daemon up?"
    skip "  sudo systemctl enable --now tailscaled"
    exit 0 ;;
  *)
    skip "tailscale is $backend, not Running — left alone"
    skip "  log in first: omarchy-install-service-tailscale"
    exit 0 ;;
esac

# See README.md (3)
# $3 is EMPTY on purpose. Every other record_prior call here passes the value the
# step is about to write, so that recording our OWN setting cannot turn revert
# into a no-op -- but that guard is unreachable here, since record_prior writes
# once and never overwrites. What passing "true" would do instead is make a
# machine that ALREADY had SSH on record nothing, and an absent file also means
# "the prefs blob was unreadable" and "this step never ran". Empty keeps both
# true and false verbatim, so revert can tell them apart and say which it saw.
# See README.md (3).
runssh=$(read_runssh)
record_prior "$PRIOR" "$runssh" ""

# See README.md (4)
if [[ $runssh == true ]]; then
  skip "Tailscale SSH already enabled"
else
  say "Tailscale SSH -> on (tailnet identity; no sshd, no open port)"
  if tailscale set --ssh >/dev/null 2>&1; then
    skip "enabled with no sudo — you hold Tailscale's operator bit"
  elif sudo -n tailscale set --ssh >/dev/null 2>&1; then
    skip "enabled through passwordless sudo — you do not hold the operator bit"
    skip "  grant it once and this step never needs root again:"
    skip "    sudo tailscale set --operator=$USER"
  else
    # -n rather than a bare sudo: this step is NOT marked sudo in apply.sh's
    # table, and that table promises that skipping the four marked ones needs
    # no password at all. Prompting here would break that promise, so a machine
    # without the operator bit gets a line to run instead of a password prompt.
    skip "could not enable Tailscale SSH without root, and this step will not prompt"
    skip "  run either of these once, then re-run this step:"
    skip "    sudo tailscale set --operator=$USER"
    skip "    sudo tailscale set --ssh"
    exit 0
  fi
fi

# See README.md (5)
now=$(read_runssh)
if [[ $now != true ]]; then
  skip "RunSSH reads '${now:-unreadable}' after the write — the change did not stick"
  exit 0
fi

# See README.md (6)
# The daemon being willing is only half of it: the tailnet's policy decides who
# may connect, and a node with no matching rule accepts nothing while looking
# perfectly configured from here. tailscaled says so in its own log, but only
# at connection time; this reads the policy it was handed instead.
rules=$(tailscale debug netmap 2>/dev/null \
  | jq -r 'if .SSHPolicy.rules == null then 0 else (.SSHPolicy.rules | length) end' 2>/dev/null || true)
if [[ $rules == 0 ]]; then
  skip "WARNING: the daemon is willing, but your tailnet's policy allows nobody"
  skip "  add an ssh rule to the policy file: https://tailscale.com/s/ssh-policy"
elif [[ -n $rules ]]; then
  skip "tailnet policy carries $rules ssh rule(s), so at least one principal can connect"
fi

# See README.md (7)
node=$(tailscale status --json 2>/dev/null \
  | jq -r 'if .Self.HostName == null then "" else .Self.HostName end' 2>/dev/null || true)
[[ -n $node ]] || node=$(hostname)
skip "ufw untouched: no sshd, no host keys, no authorized_keys, no open port"
skip "  from another node: ssh $USER@$node"
skip "  first connect opens a browser to approve, then ~12h per the policy's check rule"
skip "  NOT verifiable from here — a node cannot Tailscale-SSH to itself (README.md (7))"
