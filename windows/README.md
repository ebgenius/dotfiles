# Windows 11 setup

Installs Git for Windows (incl. Git Bash) and sets up one shared `ssh-agent` on a fixed
socket, `~/.ssh/agent.sock`, used by Git Bash, PowerShell and VS Code (Source Control works
without opening a terminal first).

## Install

Fresh machine, from **Windows PowerShell** (no git needed; clones this repo to `~\workspaces\dotfiles`):

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/ebgenius/dotfiles/main/windows/install.ps1)))
```

From a clone:

```powershell
powershell -ExecutionPolicy Bypass -File windows\install.ps1          # Git for current user
powershell -ExecutionPolicy Bypass -File windows\install.ps1 -Machine # Git for all users (admin)
```

Then copy your SSH keys to `~\.ssh\` (any `id_*` private key is loaded) and restart VS Code.

Re-running is safe and is how you apply changes after a `git pull`. Existing home files
that differ are backed up to `<file>.bak`.

## What it does

| Piece | Purpose |
|---|---|
| `winget install Git.Git` | Git, Git Bash, and Git's OpenSSH (`ssh-agent`, `ssh-add`) |
| `home/.bashrc`, `home/.bash_profile_dev` | Aliases; start the agent on the socket if none is running, add keys if none are loaded |
| `home/.ssh/ensure-agent.ps1` | Same logic for PowerShell; also puts Git's `ssh` ahead of Windows' built-in OpenSSH |
| PowerShell profiles (5.1 and 7) | Run `ensure-agent.ps1` on startup |
| `SSH_AUTH_SOCK` user env var | Lets VS Code and any `git.exe` find the agent |
| Scheduled task `SSH Agent (Git socket)` | Starts the agent and loads keys at logon |

Keys with a passphrase can't be loaded by the logon task; the first shell you open will prompt once.

## Useful

- `pdev` (Git Bash): re-run the agent check and test GitHub/GitLab auth (`ssh_test`)
- `ssh-add -l`: list loaded keys
