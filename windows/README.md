# Windows 11 setup

One script that turns a fresh Windows 11 machine into a working dev box:

- installs **Git for Windows** (which includes **Git Bash** and Git's own OpenSSH tools)
- installs the shell dotfiles (`.bashrc`, `.bash_profile_dev`)
- runs **one shared `ssh-agent`** on a fixed socket, `~/.ssh/agent.sock`, used by
  **Git Bash, PowerShell and VS Code**

The end result: SSH keys are loaded once at logon, every terminal reuses the same agent
instead of starting a new one, and VS Code's **Source Control panel can push/pull/fetch
over SSH without you ever opening a terminal**.

---

## Contents

- [Quick start](#quick-start)
- [After installing](#after-installing)
- [How it works](#how-it-works)
- [What the installer does, step by step](#what-the-installer-does-step-by-step)
- [Files in this folder](#files-in-this-folder)
- [Everyday commands](#everyday-commands)
- [Design decisions and Windows quirks](#design-decisions-and-windows-quirks)
- [Troubleshooting](#troubleshooting)
- [Updating](#updating)
- [Uninstalling](#uninstalling)
- [Not included](#not-included)

---

## Quick start

### Fresh machine (no git installed yet)

Open **Windows PowerShell** (the built-in one is fine; PowerShell 7 is not required) and run:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/ebgenius/dotfiles/main/windows/install.ps1)))
```

This downloads `install.ps1`, installs Git, clones this repo to `~\workspaces\dotfiles`
over HTTPS, and then sets everything up from that clone.

> The `[scriptblock]::Create(...)` form (instead of `irm ... | iex`) runs the script in its
> own scope, so its variables and error settings don't leak into your shell.

### From an existing clone

```powershell
cd ~\workspaces\dotfiles
powershell -ExecutionPolicy Bypass -File windows\install.ps1            # Git for current user only
powershell -ExecutionPolicy Bypass -File windows\install.ps1 -Machine   # Git for all users (needs admin)
```

### Parameters

| Parameter | Default | Meaning |
|---|---|---|
| `-Machine` | off | Install Git machine-wide (`C:\Program Files\Git`) instead of per-user (`%LOCALAPPDATA%\Programs\Git`). Needs an elevated shell. |
| `-RepoDir` | `~\workspaces\dotfiles` | Where to clone the repo when run from the one-liner. Ignored when run from a clone. |

---

## After installing

1. **Copy your SSH keys** into `~\.ssh\`. Every private key named `id_*` (not `*.pub`) is
   loaded automatically; there is no list of key names to maintain. Keys are deliberately
   **not** stored in this repo.
2. **Open a new terminal**, or run `~\.ssh\ensure-agent.ps1`, to load the keys now.
3. **Fully restart VS Code** (close every window). It only reads environment variables at
   startup, so it needs a restart to see `SSH_AUTH_SOCK`.
4. Check it worked:

   ```bash
   ssh-add -l      # lists your keys
   pdev            # Git Bash: tests auth to GitHub and TU Delft GitLab
   ```

From the next logon on, you don't need to do anything.

---

## How it works

```
                      ~/.ssh/agent.sock   (fixed path, one agent)
                               ▲
      ┌───────────────┬────────┴────────┬─────────────────────────┐
      │               │                 │                         │
  logon task      Git Bash          PowerShell                 VS Code
  (at sign-in)    (.bashrc →        (profile →                 (git.exe → Git's ssh,
  starts agent,    .bash_profile_dev) ensure-agent.ps1)          finds the socket via
  loads keys      reuse or start    reuse or start              SSH_AUTH_SOCK user env var)
```

**The problem it solves:** `eval $(ssh-agent -s)` starts a *new* agent on a *random*
socket every time it runs, and only that shell knows where it is. Open three terminals and
you have three agents; VS Code knows about none of them, so Source Control fails with
`Permission denied (publickey)`.

**The fix:**

1. **A fixed socket path.** The agent is always started with `ssh-agent -a ~/.ssh/agent.sock`,
   so every program can find it without asking the shell that started it.
2. **A user environment variable.** `SSH_AUTH_SOCK=C:/Users/<you>/.ssh/agent.sock` is set in
   the Windows user environment, so *every* newly started process inherits it, including
   VS Code and the `git.exe` it runs.
3. **Reuse before starting.** Before doing anything, both the bash and PowerShell scripts ask
   the socket `ssh-add -l` and act on the exit code:

   | `ssh-add -l` exit code | Meaning | Action |
   |---|---|---|
   | `0` | Agent running, keys loaded | Nothing |
   | `1` | Agent running, no keys | Add keys |
   | `2` | No agent answering | Delete the leftover socket file (from a dead agent), start a new agent, add keys |

4. **Started at logon.** A scheduled task runs the same PowerShell script when you sign in,
   so the agent and keys are ready before VS Code or any terminal is opened.

Git Bash and PowerShell use **the same Git for Windows `ssh-agent.exe`**, so the socket
file is understood by both. Bash sees the path as `/c/Users/<you>/.ssh/agent.sock`,
Windows programs as `C:/Users/<you>/.ssh/agent.sock`; it's the same file.

---

## What the installer does, step by step

`install.ps1` works in both Windows PowerShell 5.1 (ships with Windows) and PowerShell 7.
Every step checks the current state first, so **running it again is safe**.

1. **Git for Windows.** Skipped if `git` is already on PATH. Otherwise runs
   `winget install --id Git.Git --scope user` (or `--scope machine` with `-Machine`), then
   reloads PATH in the current session. Fails clearly if `winget` is missing (install
   *App Installer* from the Microsoft Store).
2. **Clone the repo.** Only when run from the one-liner (there's no script folder to copy
   from). Clones `https://github.com/ebgenius/dotfiles.git` to `-RepoDir`, or reuses an
   existing clone.
3. **Copy home files.** Everything under `windows/home/` is copied to the same relative path
   under `~`. For each file:
   - identical → left alone (`unchanged`)
   - different → old version saved as `<file>.bak`, then overwritten (`updated`)
   - missing → copied (`created`)
4. **Create `~/.bash_profile` if missing.** Git Bash only reads `~/.bashrc` through
   `~/.bash_profile`. Git normally generates it on first launch, but the installer creates the
   same file up front so the very first Git Bash window already has the agent.
5. **PowerShell profiles.** Appends `& "$HOME\.ssh\ensure-agent.ps1"` to both:
   - `Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1` (5.1)
   - `Documents\PowerShell\Microsoft.PowerShell_profile.ps1` (7)

   `Documents` is resolved via Windows, so OneDrive-redirected folders work. The line is only
   added once.
6. **Execution policy.** If the CurrentUser policy is `Undefined`/`Restricted`, sets it to
   `RemoteSigned` so profiles are allowed to run (Windows' default for 5.1 blocks them). See
   [the 5.1 quirk](#execution-policy-security-error) for why the result is checked afterwards.
7. **`SSH_AUTH_SOCK`.** Sets the user environment variable to `C:/Users/<you>/.ssh/agent.sock`.
8. **Logon task.** Registers (or replaces) the scheduled task **`SSH Agent (Git socket)`**:
   runs `ensure-agent.ps1` hidden at your logon with `pwsh` if installed, otherwise
   `powershell.exe`; runs on battery; times out after 2 minutes. No admin rights needed.
9. **Start the agent now** and list the loaded keys, or warn if `~\.ssh` has no `id_*` keys.

---

## Files in this folder

| Path in repo | Installed to | Purpose |
|---|---|---|
| `windows/install.ps1` | — | The installer described above |
| `windows/home/.bashrc` | `~/.bashrc` | Git/Python aliases; sources `.bash_profile_dev` on every Git Bash start |
| `windows/home/.bash_profile_dev` | `~/.bash_profile_dev` | Bash agent logic (`ssh_agent_ensure`) and `ssh_test` |
| `windows/home/.ssh/ensure-agent.ps1` | `~/.ssh/ensure-agent.ps1` | PowerShell agent logic; used by the profiles and the logon task |
| `.gitattributes` (repo root) | — | Keeps bash files LF, `.ps1` files CRLF (see [line endings](#line-endings)) |

Things the installer creates outside those files:

| What | Where |
|---|---|
| Agent socket | `~/.ssh/agent.sock` (created by `ssh-agent` at runtime) |
| User env var | `SSH_AUTH_SOCK` |
| Scheduled task | `SSH Agent (Git socket)` in Task Scheduler |
| Profile line | both PowerShell profiles |
| Backups | `<file>.bak` next to any home file that was replaced |

---

## Everyday commands

| Command | Shell | What it does |
|---|---|---|
| `ssh-add -l` | any | List keys loaded in the shared agent |
| `pdev` | Git Bash | Re-run the agent check, then `ssh_test` |
| `ssh_test` | Git Bash | `ssh -T` to `git@github.com` and `git@gitlab.tudelft.nl` |
| `ssh_agent_ensure` | Git Bash | Start/reuse the agent and load keys |
| `& ~\.ssh\ensure-agent.ps1` | PowerShell | Same, from PowerShell |
| `Start-ScheduledTask 'SSH Agent (Git socket)'` | PowerShell | Run the logon task manually |
| `ga`, `gaa`, `gaaa` | Git Bash | `git add`, `git add .`, `git add --all` |
| `venv` | Git Bash | Activate `.venv` in the current folder |

---

## Design decisions and Windows quirks

### Why Git's ssh-agent and not the Windows OpenSSH service

Windows ships its own OpenSSH with an `ssh-agent` *service* that uses a named pipe, not a
socket file. Git for Windows' `git.exe` (and therefore VS Code) uses **Git's bundled `ssh`**
by default, which talks to socket files. Using Git's agent everywhere means no `core.sshCommand`
tweaks and a single agent for bash, PowerShell and VS Code. The Windows `ssh-agent` service is
left alone (it's disabled by default).

### PATH order in PowerShell

On a fresh Windows 11, `C:\Windows\System32\OpenSSH` (machine PATH) comes **before** Git's
tools, so typing `ssh` in PowerShell would run Windows' ssh, which can't use the socket.
`ensure-agent.ps1` prepends Git's `usr\bin` to `PATH` for the PowerShell session, so `ssh`,
`ssh-add` and `ssh-keygen` are Git's. (The user PATH can't fix this, because Windows always
puts the machine PATH first.)

### Line endings

With `core.autocrlf=true` (Git for Windows' default), bash files would be checked out with
CRLF, and bash then fails with `$'\r': command not found`. `.gitattributes` forces `eol=lf`
for `.bash*`, `*.sh`, `.zshrc*` and `*.service`, and `eol=crlf` for `*.ps1`.

### Execution policy "Security error"

Windows PowerShell 5.1 can throw `Security error.` from `Set-ExecutionPolicy -Scope CurrentUser`
even though the setting **was** saved (this happens, for example, when the process was started
with `-ExecutionPolicy Bypass`). The installer therefore ignores the exception and checks the
resulting policy, and only warns if it really isn't `RemoteSigned`. If Group Policy enforces
a stricter policy (`Get-ExecutionPolicy -List` shows it under `MachinePolicy`/`UserPolicy`),
it overrides everything, including the logon task's `-ExecutionPolicy Bypass`. In that case
the PowerShell side won't run, but Git Bash still starts the agent on the shared socket, so
opening one Git Bash window after logon makes VS Code work.

### Keys with a passphrase

The logon task runs hidden, so it can't ask for a passphrase. Keys without one load at
logon; keys with one are loaded the first time you open Git Bash or PowerShell (you'll be
prompted once per logon). Until then VS Code can only use the passphrase-less keys.

### Why copies instead of symlinks

Windows symlinks need admin rights or Developer Mode. Copying works everywhere; re-run the
installer after a `git pull` to apply changes.

---

## Troubleshooting

**`Permission denied (publickey)` in a terminal or VS Code**

1. `ssh-add -l`:
   - lists keys → the agent is fine; check that the key is registered on GitHub/GitLab.
   - `The agent has no identities` → run `ssh_agent_ensure` (bash) or `& ~\.ssh\ensure-agent.ps1`.
   - `Could not open a connection to your authentication agent` → see the next item.
2. `echo $SSH_AUTH_SOCK` (bash) / `$env:SSH_AUTH_SOCK` (PowerShell) must print the socket path.
   If it's empty, the program was started **before** the variable was set (typical right
   after the first install): restart it. For VS Code, close *all* windows. If in doubt, sign
   out and back in.
3. Check the agent process exists: `Get-Process ssh-agent`.

**VS Code still fails after restarting**

- Make sure VS Code is using Git for Windows: `git.path` unset or pointing to Git's `git.exe`.
- Don't set `core.sshCommand` or `GIT_SSH` to `C:\Windows\System32\OpenSSH\ssh.exe`, since
  that ssh can't use the socket.

**Several `ssh-agent` processes running**

Harmless: agents started before this setup (on random `/tmp/ssh-*` or `~/.ssh/agent/*`
sockets) stay until logout. Only the one on `agent.sock` is used. To clean up:
`Get-Process ssh-agent | Stop-Process`, then `& ~\.ssh\ensure-agent.ps1`.

**`bind: Address already in use` when starting the agent**

A leftover socket file with no agent behind it. The scripts delete it automatically; to
do it by hand: `Remove-Item ~\.ssh\agent.sock`, then rerun the ensure script.

**Logon task didn't run**

```powershell
Get-ScheduledTaskInfo 'SSH Agent (Git socket)'   # LastTaskResult 0 = success
Start-ScheduledTask   'SSH Agent (Git socket)'
```

**`ssh` in PowerShell is Windows' ssh**

`(Get-Command ssh).Source` should point into `...\Git\usr\bin`. If it doesn't, the profile
didn't run: check `Get-ExecutionPolicy -List`.

---

## Updating

```powershell
cd ~\workspaces\dotfiles
git pull
powershell -ExecutionPolicy Bypass -File windows\install.ps1
```

Changed files are replaced and the old versions are kept as `.bak`.

---

## Uninstalling

```powershell
Unregister-ScheduledTask -TaskName 'SSH Agent (Git socket)' -Confirm:$false
[Environment]::SetEnvironmentVariable('SSH_AUTH_SOCK', $null, 'User')
Get-Process ssh-agent -ErrorAction SilentlyContinue | Stop-Process
Remove-Item ~\.ssh\ensure-agent.ps1, ~\.ssh\agent.sock -ErrorAction SilentlyContinue
```

Then remove the `& "$HOME\.ssh\ensure-agent.ps1"` line from both PowerShell profiles
(`notepad $PROFILE`), and restore `~/.bashrc` / `~/.bash_profile_dev` from their `.bak`
files if you want the old versions back. Git itself: `winget uninstall Git.Git`.

---

## Not included

- **SSH keys:** copy them manually; never commit them.
- **`~/.bash_profile_nvm` and `~/.bash_profile_simplebot`:** machine-specific. The `pnvm`
  and `pbot` aliases in `.bashrc` expect them and simply do nothing useful until those files
  exist.
- **VS Code, Node, Python:** not installed by this script.
