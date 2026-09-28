# dotfiles

| Platform | Contents |
|---|---|
| Linux | `.zshrc*`, Barrier KVM service (`barrier.service`, `barrier-start.sh`, `setup.sh`) |
| Windows 11 | [`windows/`](windows/README.md): Git for Windows, Git Bash dotfiles, and one shared ssh-agent for Git Bash, PowerShell and VS Code |

## Windows 11 quick start

From Windows PowerShell on a fresh machine:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/ebgenius/dotfiles/main/windows/install.ps1)))
```

See [windows/README.md](windows/README.md) for details, troubleshooting and uninstalling.
