# Stop hook: reminds when today's code commits are missing from .project-docs/log/YYYY-MM-DD.md. Read-only; always exits 0.
function Emit([string]$msg) { Write-Output (@{ systemMessage = $msg } | ConvertTo-Json -Compress) }

try {
  $root = git -C $PSScriptRoot rev-parse --show-toplevel 2>$null
  if ($LASTEXITCODE -ne 0 -or -not $root) { Emit "Log hook error: not a git repository"; exit 0 }
  Set-Location $root
  git rev-parse --verify -q HEAD *> $null
  if ($LASTEXITCODE -ne 0) { exit 0 }  # repo has no commits yet
  $hashes = @(git log --since=midnight --no-merges --format=%h 2>$null)
  if ($LASTEXITCODE -ne 0) { Emit "Log hook error: git log failed"; exit 0 }
  $logFile = Join-Path $root (".project-docs/log/{0}.md" -f (Get-Date -Format 'yyyy-MM-dd'))
  $log = if (Test-Path $logFile) { Get-Content $logFile -Raw } else { '' }
  $unlogged = 0
  foreach ($h in $hashes | Where-Object { $_ }) {
    $files = @(git show --name-only --format= $h 2>$null | Where-Object { $_ })
    if ($LASTEXITCODE -ne 0) { Emit "Log hook error: git show $h failed"; exit 0 }
    # Docs-only commits (log/STATE updates) never trigger a reminder.
    if ($files.Count -gt 0 -and -not ($files | Where-Object { $_ -notlike '.project-docs/*' })) { continue }
    if ($log -notmatch [regex]::Escape($h)) { $unlogged++ }
  }
  if ($unlogged -gt 0) { Emit "Log reminder: $unlogged commit(s) today not logged." }
} catch {
  Emit "Log hook error: $($_.Exception.Message)"
}
exit 0
