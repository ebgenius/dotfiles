# Ensures one Git-for-Windows ssh-agent is listening on a fixed socket, with keys loaded.
# Shared by Git Bash (~/.bash_profile_dev), the PowerShell profile, VS Code and the logon task.
# Compatible with Windows PowerShell 5.1 and PowerShell 7.
$gitBin = @(
    "$env:LOCALAPPDATA\Programs\Git\usr\bin",
    "$env:ProgramFiles\Git\usr\bin"
) | Where-Object { Test-Path "$_\ssh-agent.exe" } | Select-Object -First 1
if (-not $gitBin) { Write-Warning 'Git for Windows ssh-agent not found'; return }

$sock = "$HOME/.ssh/agent.sock" -replace '\\', '/'
$keys = Get-ChildItem "$HOME\.ssh\id_*" -File -ErrorAction SilentlyContinue |
    Where-Object Extension -ne '.pub' | ForEach-Object FullName

$env:SSH_AUTH_SOCK = $sock
# Windows' built-in OpenSSH (System32\OpenSSH) can't talk to this socket; make Git's ssh win.
if (($env:Path -split ';')[0] -ne $gitBin) { $env:Path = "$gitBin;$env:Path" }

& "$gitBin\ssh-add.exe" -l *> $null
$rc = $LASTEXITCODE  # 0 = agent up with keys, 1 = agent up but empty, 2 = no agent
if ($rc -eq 2) {
    Remove-Item -Force -ErrorAction SilentlyContinue $sock  # stale socket from a dead agent
    & "$gitBin\ssh-agent.exe" -a $sock *> $null
}
if ($rc -ne 0 -and $keys) {
    & "$gitBin\ssh-add.exe" @keys 2> $null
}
