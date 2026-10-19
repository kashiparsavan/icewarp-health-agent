# Automatic Updates

Starting with **v0.5.0**, the agent checks the configured Git branch before
every execution and fast-forwards itself when a newer revision is available.
The update happens before `agent.sh` loads the rest of its libraries, and the
agent re-executes itself after a successful update so the current run uses the
new code.

The updater is intentionally conservative. It will **never** merge, rebase,
force-push, or overwrite staged/code changes. Unstaged per-server edits under
`config/*.conf` are preserved; a same-file upstream change aborts the update.

## First-time activation

Auto-update cannot bootstrap itself into a checkout that does not already have
this code. On an existing installation, pull this release once manually:

```bash
cd /root/iceauto
git pull --ff-only origin main
```

After that, every invocation checks `origin/main` automatically. No cron or
systemd change is needed if the agent is already scheduled; the updater runs at
the start of each scheduled invocation.

### Upgrading an existing customized checkout

If `git pull --ff-only origin main` refuses because `config/agent.conf` or
`config/icewarp.conf` has local edits, back up the files and preserve the edits:

```bash
cd /root/iceauto
git status
cp config/agent.conf  /root/agent.conf.bak
cp config/icewarp.conf /root/icewarp.conf.bak

# Option A: stash only the local config edits, then pull and reapply.
git stash push -m "server config" -- config/agent.conf config/icewarp.conf
git pull --ff-only origin main
git stash pop

# Option B: if you prefer a clean checkout, restore the tracked config files,
# pull, then reapply MONITOR_URL/SEND_DATA/COMPANY_NAME/paths from the backups.
# git checkout -- config/agent.conf config/icewarp.conf
# git pull --ff-only origin main
```

Check for conflicts after `git stash pop` and verify the result:

```bash
./agent.sh --check-update
./agent.sh --config          # dry-run: confirm recommended settings still read correctly
```

After this one-time upgrade, future updates preserve unstaged `config/*.conf`
edits automatically.

## Requirements

- The project must be a Git clone, not a downloaded ZIP or copied directory.
- `git` must be installed on the server.
- The checkout must have no staged changes and no unstaged code changes.
  Unstaged per-server edits under `config/*.conf` are allowed; Git still
  aborts the fast-forward if an incoming commit touches the same config file.
- The configured remote and branch must exist.
- The checked-out local branch must be `AUTO_UPDATE_BRANCH` (`main` by default).
- The remote URL must match `AUTO_UPDATE_EXPECTED_ORIGIN`.

If any requirement is not met, the agent logs the reason and continues with the
current code. Auto-update failures are never fatal.

## Update sequence

1. Normal runs first acquire `.agent.lock`; `--check-update` skips the run
   lock. The updater then acquires `.agent.update.lock` so two update checks
   cannot overlap.
2. Verify `PROJECT_ROOT` is a Git work tree and the checked-out branch is
   `AUTO_UPDATE_BRANCH`.
3. Verify `origin` matches `AUTO_UPDATE_EXPECTED_ORIGIN`.
4. Refuse to continue if there are staged changes or unstaged changes outside
   `config/*.conf`. Unstaged per-server config edits are preserved.
5. `git fetch --prune <remote> <branch>` with a timeout.
6. Compare local `HEAD` with `<remote>/<branch>`.
7. If the remote is a descendant, run `git merge --ff-only <remote-sha>`.
8. Run `bash -n` on `agent.sh` and all `*.sh` files. If validation fails,
   hard-reset back to the previous commit, restore the saved local config
   edits, and log `reverted`.
9. Log `updated` and re-execute `agent.sh` with the original arguments.

The re-exec is guarded by `AGENT_UPDATE_REEXEC=1`, so it cannot loop. It keeps
the same PID, and `acquire_lock()` recognizes the existing `.agent.lock` as its
own. This means an update can never rewrite files underneath an active
collector run, and a second scheduled run aborts before updating.

## Command-line options

| Option | Behavior |
|---|---|
| `--check-update` | Fetch and report whether an update is available, then exit without changing files |
| `--no-auto-update` | Skip the update check for this run only |
| `--auto-update` | Force a check even when disabled in config |
| `--no-update` | Deprecated no-op, kept for backward compatibility |

## Configuration

Settings live in `config/agent.conf`:

| Setting | Default | Purpose |
|---|---|---|
| `AUTO_UPDATE_ENABLED` | `1` | Global on/off switch |
| `AUTO_UPDATE_REMOTE` | `origin` | Git remote to fetch |
| `AUTO_UPDATE_BRANCH` | `main` | Branch to follow |
| `AUTO_UPDATE_TIMEOUT` | `60` | Timeout in seconds for each Git command |
| `AUTO_UPDATE_EXPECTED_ORIGIN` | `kashiparsavan/icewarp-health-agent` | Required remote repository; matching supports HTTPS and SSH GitHub URLs. Set empty to disable the check. |
| `AUTO_UPDATE_REEXEC` | `1` | Re-execute after a successful update |
| `AUTO_UPDATE_VALIDATE` | `1` | Run `bash -n` and roll back on failure |
| `AUTO_UPDATE_LOG` | `${PROJECT_ROOT}/logs/auto_update.log` | Append-only activity log |
| `AUTO_UPDATE_LOG_MAX_BYTES` | `5242880` | Rotate to `.1` above this size |

## Activity log

Every check is recorded in `logs/auto_update.log` (gitignored). The format is
pipe-delimited:

```text
timestamp|status|old=<sha>|new=<sha>|branch=<branch>|detail
```

Example:

```text
2026-10-19T15:11:40Z|updated|old=9e7b833a1cbb...|new=2d5deaa44098...|branch=main|Fast-forwarded: fix(configurator): use canonical IceWarp API keys
2026-10-19T15:12:05Z|up_to_date|old=2d5deaa44098...|new=2d5deaa44098...|branch=main|No update available
2026-10-19T15:15:00Z|fetch_failed|old=2d5deaa44098...|new=none|branch=main|Could not resolve host: github.com
```

Possible statuses:

| Status | Meaning |
|---|---|
| `up_to_date` | Local HEAD already matches the remote branch |
| `updated` | Fast-forward completed |
| `check_up_to_date` | `--check-update` found no update |
| `check_available` | `--check-update` found an update |
| `disabled` | Auto-update disabled by config or `--no-auto-update` |
| `not_git` | `PROJECT_ROOT` is not a Git checkout |
| `git_missing` | `git` is not installed |
| `locked` | Another update check is running |
| `origin_mismatch` | Remote URL is not the expected repository |
| `wrong_branch` | Checked-out branch is not `AUTO_UPDATE_BRANCH` |
| `dirty_tree` | Staged changes or unstaged code changes are present |
| `fetch_failed` | Network, authentication, or timeout failure |
| `ahead` | Local branch is ahead of the remote |
| `diverged` | Local and remote histories have diverged |
| `merge_failed` | Fast-forward could not be completed |
| `reverted` | New revision failed shell syntax validation and was rolled back; local config edits are restored when possible |
| `reexec_complete` | Agent restarted after an update |
| `error` | Unexpected Git or filesystem error |

Credentials embedded in URLs are redacted before details are written.

## Manual checks and recovery

Check without changing anything:

```bash
./agent.sh --check-update
```

If the log reports `dirty_tree`, inspect and resolve local code or staged
changes:

```bash
git status
git stash        # or commit the intended changes
```

Unstaged edits to `config/*.conf` do not trigger `dirty_tree`. If a config file
changed both locally and upstream, the fast-forward fails with
`merge_failed`; resolve the config conflict manually, then the next run will
update again.

If it reports `diverged`, a manual decision is required:

```bash
git fetch origin
git log --oneline --left-right HEAD...origin/main
# then merge, rebase, or reset manually
```

If an update is pulled but later found to be bad, use normal Git history to
roll back. The updater only automatically reverts revisions that fail the
shell syntax check.

## Scheduling

Auto-update runs whenever `agent.sh` is invoked. To run the agent periodically,
use the scheduler already available on the server, for example:

```cron
*/30 * * * * root cd /root/iceauto && ./agent.sh --report >> logs/agent.log 2>&1
```

The updater's own lock plus the agent's `.agent.lock` prevent overlapping
updates and overlapping report runs.

## Security notes

The updater executes code from the configured branch as the user running the
agent, normally `root`. Anyone who can push to that branch can execute code on
the mail server. Before enabling automatic updates in production:

- Protect the branch and require review for changes.
- Keep `AUTO_UPDATE_EXPECTED_ORIGIN` set to the intended repository.
- Do not commit credentials or local changes to the checkout.
- Consider following a release tag or protected branch instead of a shared
  development branch.

The clean-tree requirement, fast-forward-only merge, origin check, syntax
validation, and audit log reduce accidental damage; they do not replace branch
protection.
