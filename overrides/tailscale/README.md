# Tailscale SSH

One preference — `RunSSH` — so the rest of the tailnet can reach this machine's
shell. No `sshd`, no host keys, no `authorized_keys`, no open port, and `ufw` is
not touched at all.

## 1. The third package this repo depends on, and it installs none of them

`keyd` and `ryzenadj` were the first two. Like them, `tailscale` has to be
present already: this step configures it or says why it cannot. Omarchy has its
own installer and it is the supported route, so that is what the skip line
names:

```
omarchy-install-service-tailscale
```

**Why Tailscale SSH rather than `sshd`.** The alternative was OpenSSH with a
`ufw` rule scoped to the `tailscale0` interface, and it was considered and
turned down. Tailscale SSH authenticates against *tailnet identity* through the
policy file rather than against a key file, so there is no `authorized_keys` to
distribute, rotate or lose; nothing listens on the LAN; and the machine grows no
new attack surface reachable from anywhere but the tailnet. The cost is that it
is Tailscale-specific — a client outside the tailnet has nothing to connect to,
which is the point — and that `check`-mode rules want a browser every ~12 hours.
Omarchy ships `omarchy-setup-security-sshd` for the OpenSSH route if that trade
ever stops being the right one; it opens `limit 22/tcp` on **every** interface,
LAN included, which is the specific thing this avoids.

## 2. The backend has to be `Running`, and `BackendState` is the only honest test

`tailscale set --ssh` against a daemon that is installed but logged out does not
configure anything useful, so the step reads `.BackendState` out of
`tailscale status --json` first and only proceeds on `Running`. The other values
that turn up are `NeedsLogin`, `Stopped` and `NoState`, and each gets its own
line rather than a generic failure.

`tailscale status`'s **exit code** is not a substitute: it is non-zero for more
than one reason and does not distinguish "not installed" from "not logged in"
from "logged in and stopped", which are three different things to tell someone.

## 3. `false` is the value worth recording, and jq's `//` drops exactly that

`record_prior` is called with an **empty** `$3`:

```bash
record_prior "$PRIOR" "$runssh" ""
```

`$3` is the value-to-refuse, and every other call in this repo passes the value
the step is about to write, so that recording our own setting cannot quietly turn
revert into a no-op. Here that would be `"true"` — and passing it gives the right
*outcome* for the wrong reason, which is why the empty string is deliberate
rather than sloppy. With `$3="true"` a machine that already had SSH on records
**nothing**, and revert then leaves the pref alone because there is no file. That
is the correct behaviour, reached by an absent file that also means "the prefs
blob was unreadable" and "this step never ran". Three states, one representation.

With `$3` empty, `true` and `false` are both written verbatim, so revert can tell
them apart and say which one it saw — and an absent file goes back to meaning
only what it should. Nothing is lost: the guard `$3` exists for is unreachable
here, because `record_prior` writes once and never overwrites, so a recorded
`true` can only have come from a machine that genuinely had SSH on before this
step first ran.

Reading the pref has the same shape of trap one level down. `.RunSSH // empty` is
the obvious jq and it is wrong, because `//` treats `false` as absent — see
`CLAUDE.md`'s jq entry, where this repo has already been bitten by it once over
`bar.transparent`. The read is:

```bash
jq -r 'if .RunSSH == null then "" else (.RunSSH | tostring) end'
```

so `""` means *could not read it* and `false` means `false`.

## 4. No sudo on Omarchy, and this step will not prompt

`omarchy-install-service-tailscale` line 14 is:

```bash
sudo tailscale set --operator="$USER"
```

So on any machine where Tailscale was installed the supported way, you already
hold Tailscale's operator bit and a plain unprivileged `tailscale set --ssh`
works. That is why this step is **not** among apply.sh's four sudo steps, and
why the counts in `../README.md` and `../apply.sh` did not change when it was
added.

The fallback is `sudo -n`, deliberately — non-interactive. apply.sh's step table
promises that skipping the four marked steps means the run needs no password at
all, and a prompt here would quietly break that promise. A machine without the
operator bit therefore gets two commands to run rather than a password prompt:

```bash
sudo tailscale set --operator=$USER   # once, and this step never needs root again
sudo tailscale set --ssh              # or just do the one thing
```

Measured on this machine: enabling takes 11ms, disabling 38ms, both rc=0 with no
prompt.

## 5. Read the pref back

`tailscale set` prints **nothing** on success — absence of output is the success
signal, which is not something to take on trust. The step re-reads `RunSSH` and
reports it if the write did not land. Same reasoning as `ghostty +validate-config`
being silent on success, elsewhere in this repo.

## 6. The daemon being willing is half of it; the tailnet policy is the other

A node with `RunSSH` on and no matching policy rule accepts nothing while looking
perfectly configured locally. The step reads the policy it was handed:

```bash
tailscale debug netmap | jq '.SSHPolicy.rules | length'
```

and warns when that is zero. A default Tailscale tailnet has a `check` rule
(`action.holdAndDelegate`) covering `autogroup:member` → `autogroup:self`, which
is what makes the first connection open a browser and then hold for ~12 hours;
satisfied checks show up alongside it as `accept` rules carrying a `ruleExpires`.
This node also needs the `https://tailscale.com/cap/ssh` capability, which is in
`SelfNode.CapMap` and comes from the same control-plane answer.

`tailscaled` does say so itself, but **only at connection time**, which is too
late to be a check. The two strings, so they are greppable:

```
Unable to enable local Tailscale SSH server; not enabled on Tailnet.
Tailscale SSH enabled, but access controls don't allow anyone to access this device.
```

Their *absence* from `journalctl -u tailscaled` after enabling is a real positive
signal. It is not used as the step's test because reading a unit's journal is a
group-membership question and this step has no business needing one.

## 7. A node cannot Tailscale-SSH to itself, so this step cannot prove it works

This is the one thing to know before debugging anything here. Measured:

| probe | result |
|---|---|
| `/dev/tcp/100.125.89.123/22` from this machine | `connection refused` |
| `tailscale ssh cllpse@omarchy` from this machine | `Dial("omarchy", 22): connect: connection refused` |
| `ss -ltnp` for port 22 | nothing listening |

None of those is a fault. `tailscaled` intercepts TCP port 22 for its own tailnet
address **inside its netstack, on traffic that arrived over the tunnel**, before
the packet is handed to the kernel. A connection originating on this machine to
its own tailnet IP never traverses the tunnel, so there is nothing to intercept
and nothing answers. The same mechanism is why there is no kernel listener and
therefore why `ufw` is irrelevant: the packet never reaches netfilter. If a
connection ever *is* blocked at the firewall, one rule settles it —
`sudo ufw allow in on tailscale0` — but nothing here needs it.

So the step reports what it can and says plainly that it cannot verify the rest.
End-to-end verification needs a second node on the tailnet.

**Two absences that look like failures and are not**, both chased once already:

- `Hostinfo.Services` does **not** grow a `tailscale-ssh` entry, and
  `SSH_HostKeys` stays at 0 in both `tailscale debug hostinfo` and the netmap's
  `SelfNode`. The SSH server is created lazily on the first incoming connection,
  and control trims what it echoes back in `SelfNode`, so neither reading is
  evidence either way.
- `tailscale debug daemon-goroutines` shows no SSH goroutines at idle, for the
  same reason.

What *does* confirm the daemon took it: `EditPrefs: MaskedPrefs{RunSSH=true}` in
`journalctl -u tailscaled`, and `tailscale.com/ssh/tailssh` being present in the
binary (`strings /usr/bin/tailscaled`), which rules out a build with SSH compiled
out.

## `tailscale up` with any flag stops being idempotent once this is on

Worth knowing because Omarchy's own installer walks into it. From
`tailscale up --help`: "If flags are specified, the flags must be the complete
set of desired settings. An error is returned if any setting would be changed as
a result of an unspecified flag's default value, unless the `--reset` flag is
also used."

`omarchy-install-service-tailscale` runs `sudo tailscale up --accept-routes`. With
`RunSSH` on and `--ssh` unspecified, that command now **fails** rather than
silently turning SSH off. Measured, and it prints the repair itself:

```
Error: changing settings via 'tailscale up' requires mentioning all
non-default flags. To proceed, either re-run your command with --reset or
use the command below to explicitly mention the current value of
all non-default settings:

	tailscale up --accept-routes --ssh

rc=1, prefs unchanged
```

The refusal is the safe direction and is why this needs no guard — but it does
mean re-running Omarchy's Tailscale installer stops at that line until you add
`--ssh` to it. `tailscale set` has no such rule: it changes only what you mention,
which is why this step and `revert.sh` both use `set` and never `up`.

## Reverting

`revert.sh` turns `RunSSH` back off **only** if the recorded prior is `false` —
i.e. only if this repo is what enabled it. A machine that already had Tailscale
SSH on keeps it.

It also refuses to do it when the revert is itself arriving over the tailnet,
detected from `SSH_CONNECTION`'s client address falling inside `100.64.0.0/10`:
turning SSH off there would cut the connection mid-script and leave every later
step unrun. In that case the recorded prior is **kept**, so running `revert.sh`
again from the machine itself finishes the job. Otherwise the disable passes
`--accept-risk=lose-ssh`, because `tailscale set` raises a confirmation for that
risk when it judges the change would drop your own session and the script has
nobody to answer it.

## From the step table

Tailscale SSH: one `RunSSH` pref so other nodes on the tailnet can reach this
machine's shell, with **no** `sshd`, host keys, `authorized_keys` or open port —
`ufw` stays default-deny and port 22 stays closed on every interface, because
`tailscaled` answers it inside its own netstack on tunnelled traffic only. Needs
no sudo: Omarchy's installer already granted this user Tailscale's operator bit,
and the `sudo -n` fallback never prompts. Authentication is tailnet identity via
the policy file, so the step also warns when that policy allows nobody. It
cannot verify itself end-to-end — a node cannot Tailscale-SSH to itself — which
is section 7 and the first thing to read here

Script: [`tailscale.sh`](tailscale.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.
