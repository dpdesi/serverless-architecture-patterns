$ErrorActionPreference = "Stop"

$repoRoot = (Get-Location).Path
$tmp = Join-Path $repoRoot ".terraform-tmp"
$cache = Join-Path $repoRoot ".terraform-plugin-cache"
New-Item -ItemType Directory -Force -Path $tmp, $cache | Out-Null
$env:TEMP = $tmp
$env:TMP = $tmp
$env:TF_PLUGIN_CACHE_DIR = $cache

$scanDirs = @("examples", "stacks/reference") + @(if (Test-Path "subsystems") { "subsystems" })
$roots = Get-ChildItem -Path $scanDirs -Recurse -Filter versions.tf |
  ForEach-Object { $_.Directory.FullName } |
  Sort-Object -Unique

foreach ($root in $roots) {
  Write-Host "==> validating $root"
  Push-Location $root
  terraform init -backend=false -input=false
  if ($LASTEXITCODE -ne 0) { throw "terraform init failed in $root" }
  terraform validate
  if ($LASTEXITCODE -ne 0) { throw "terraform validate failed in $root" }
  Pop-Location
}
