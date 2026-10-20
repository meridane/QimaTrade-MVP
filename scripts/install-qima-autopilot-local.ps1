$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$runner = Join-Path $root "scripts\qima-autopilot-local.ps1"
foreach ($tool in @("git","node","npm","gh","ollama","aider")) {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { throw "Missing $tool. Follow docs/QIMA_AUTOPILOT_FREE_LOCAL.md." }
}
gh auth status
if ($LASTEXITCODE -ne 0) { throw "Run gh auth login first." }
ollama list
if ($LASTEXITCODE -ne 0) { throw "Start Ollama first." }
$action = New-ScheduledTaskAction -Execute (Get-Command powershell.exe).Source -Argument ('-NoProfile -ExecutionPolicy Bypass -File "' + $runner + '"')
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1)
$trigger.Repetition.Interval = "PT15M"
$trigger.Repetition.Duration = "P3650D"
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 40)
Register-ScheduledTask -TaskName "QIMA Autopilot Local" -Action $action -Trigger $trigger -Settings $settings -Description "Runs local QIMA coding agent every 15 minutes without a paid AI API." -Force | Out-Null
Write-Host "Installed. The task starts in about one minute, then repeats every 15 minutes."
Write-Host "To remove it: Unregister-ScheduledTask -TaskName 'QIMA Autopilot Local' -Confirm:$false"
