$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$state = Join-Path $env:LOCALAPPDATA "QIMA-Autopilot"
New-Item -ItemType Directory -Path $state -Force | Out-Null
$log = Join-Path $state ("run-{0}.log" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
$last = Join-Path $state "last-result.md"
$promptFile = Join-Path $state "task-prompt.md"
$bodyFile = Join-Path $state "pr-body.md"
$mutex = New-Object System.Threading.Mutex($false, "Local\QIMA_Autopilot")
if (-not $mutex.WaitOne(0)) { Write-Output "Another cycle is running."; exit 0 }
Start-Transcript -Path $log -Append | Out-Null
$status = "failed"
$prUrl = ""
$checks = @()
function Test-Step([string]$name) {
  Write-Output ""
  Write-Output "===== $name ====="
  if ($name -eq "TypeScript") { npm run typecheck }
  elseif ($name -eq "Build") { npm run build }
  else { npm run test:e2e }
  $code = $LASTEXITCODE
  $script:checks += [pscustomobject]@{ Name = $name; Code = $code }
  Write-Output "$name exit code: $code"
  return ($code -eq 0)
}
try {
  Set-Location $root
  foreach ($tool in @("git","node","npm","gh","ollama","aider")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { throw "Missing $tool. Follow docs/QIMA_AUTOPILOT_FREE_LOCAL.md." }
  }
  gh auth status | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Run gh auth login first." }
  $models = ollama list
  if ($LASTEXITCODE -ne 0) { throw "Start Ollama first." }
  if (-not ($models -match "qwen2\.5-coder:1\.5b")) { throw "Run ollama pull qwen2.5-coder:1.5b first." }
  $pending = (gh pr list --state open --json headRefName --jq '[.[] | select(.headRefName | startswith("qima-autopilot/"))] | length' | Out-String).Trim()
  if ($pending -ne "0") { $status = "waiting-for-review"; Write-Output "An automation PR is open; waiting for review."; exit 0 }
  if (git status --porcelain) { throw "Working tree is not clean. Commit or stash local changes first." }
  git fetch origin main
  if ($LASTEXITCODE -ne 0) { throw "git fetch failed." }
  git checkout main
  if ($LASTEXITCODE -ne 0) { throw "Cannot switch to main; close other Git operations." }
  git pull --ff-only origin main
  if ($LASTEXITCODE -ne 0) { throw "Cannot fast-forward main." }
  $branch = "qima-autopilot/local-{0}" -f (Get-Date -Format "yyyyMMdd-HHmmss")
  git checkout -b $branch origin/main
  if ($LASTEXITCODE -ne 0) { throw "Cannot create branch." }
  $previous = "No previous cycle result."
  if (Test-Path $last) { $previous = Get-Content $last -Raw; if ($previous.Length -gt 4000) { $previous = $previous.Substring($previous.Length - 4000) } }
  if (-not (Test-Path (Join-Path $root "docs/QIMA_V1_FUNCTION_REGISTER.md"))) { throw "QIMA function register not found." }
  $prompt = @"
Work only in this QIMA repository. Read AGENTS.md if present, docs/QIMA_V1_FUNCTION_REGISTER.md, and relevant source files.
Choose exactly ONE small, high-value incomplete task supported by repository evidence. Do not assume a route or table means a journey works.
Update the function register if feature status changes. Never change .github/, supabase/migrations/, .env files, package.json, package-lock.json, auth/RLS policies, secrets, or production settings/data. Do not deploy, migrate, push, or merge.
Make focused changes. The outer script runs tests and opens a reviewable PR. Inspect the previous result and avoid repeating failures without fixing their cause.
Previous cycle result:
$previous
Summarize your changes and limitations.
"@
  Set-Content -Path $promptFile -Value $prompt -Encoding UTF8
  aider --model ollama_chat/qwen2.5-coder:1.5b --yes-always --no-auto-commits --message-file $promptFile
  Write-Output "Aider exit code: $LASTEXITCODE"
  $paths = @((git diff --name-only)) + @((git diff --cached --name-only)) + @((git ls-files --others --exclude-standard))
  foreach ($path in ($paths | Where-Object { $_ } | Sort-Object -Unique)) {
    if ($path -match '^(\.github/|supabase/migrations/|\.env[^/]*$|package\.json$|package-lock\.json$)') {
      Write-Output "Restoring protected path $path"
      git ls-files --error-unmatch -- "$path" 2>$null | Out-Null
      if ($LASTEXITCODE -eq 0) { git restore --source=HEAD --staged --worktree -- "$path" }
      else { git rm --cached -f -- "$path" 2>$null | Out-Null; Remove-Item -LiteralPath (Join-Path $root $path) -Force -ErrorAction SilentlyContinue }
    }
  }
  if (-not (git status --porcelain)) { $status = "no-changes"; Write-Output "No changes produced."; exit 0 }
  $t = Test-Step "TypeScript"
  $b = Test-Step "Build"
  $e = Test-Step "E2E"
  $all = $t -and $b -and $e
  $checkText = ($checks | ForEach-Object { "- $($_.Name): exit $($_.Code)" }) -join [Environment]::NewLine
  $body = @"
## QIMA local autopilot (no paid AI API)

Validation results:
$checkText

No automatic merge or deployment. Review the complete diff before merging.
"@
  Set-Content -Path $bodyFile -Value $body -Encoding UTF8
  git add -A
  git commit -m "chore(qima-autopilot): local autonomous task"
  if ($LASTEXITCODE -ne 0) { throw "git commit failed." }
  git push --set-upstream origin $branch
  if ($LASTEXITCODE -ne 0) { throw "git push failed." }
  $argsPr = @("pr","create","--base","main","--head",$branch,"--title","QIMA local autopilot: $(Get-Date -Format 'yyyy-MM-dd HH:mm')")
  if (-not $all) { $argsPr += "--draft" }
  $argsPr += @("--body-file",$bodyFile)
  $prUrl = (gh @argsPr | Out-String).Trim()
  if ($LASTEXITCODE -ne 0) { throw "gh pr create failed." }
  if ($all) { $status = "PR-created-tests-passed" } else { $status = "draft-PR-created-tests-failed" }
  Write-Output "Created PR $prUrl"
}
catch { Write-Output "QIMA Autopilot error: $($_.Exception.Message)"; $status = "failed" }
finally {
  $summary = @"
# QIMA local Autopilot result
Time: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz")
Status: $status
PR: $prUrl
Checks:
$($checks | ForEach-Object { "- $($_.Name): exit $($_.Code)" } | Out-String)
Log: $log
"@
  Set-Content -Path $last -Value $summary -Encoding UTF8
  Stop-Transcript | Out-Null
  try { $mutex.ReleaseMutex() } catch {}
  $mutex.Dispose()
}
