# ringserv_build.ps1 -- the RingServ binary the cloud's first server pack stages (SRV-2).
#
#   powershell -ExecutionPolicy Bypass -File experiment\ringserv_build.ps1
#   powershell -ExecutionPolicy Bypass -File experiment\ringserv_build.ps1 -Source <a local clone>
#
# It clones RingServ's source (from GitHub, or from a local clone with -Source: only
# its git objects are read, never its working tree), checks out the ref vendor/PIN.md
# pins, and builds it for x86_64 Linux as the one static binary RingServ ships:
# `zig build -j2 -Dtarget=x86_64-linux-musl` (-j2: this machine stops dead under
# memory pressure, CLAUDE.md). The result is zig-out\ringserv\ringserv, which
# machines\ringserv.stage names and which is not in git.
#
# The SOURCE is what is pinned, not the binary: two builds of this ref in two folders
# differ by 160 bytes (measured 2026-10-04), so a digest of the binary would convict an
# honest rebuild. The digest printed at the end is for the record.
param(
    [string]$Source = "https://github.com/mayouni/ringserv.git",
    [string]$Out = "zig-out\ringserv"
)
$ErrorActionPreference = "Stop"
$Ref = "002ba2126bb78681b2aae40e365dd19385ca4d9f"

Set-Location (Join-Path $PSScriptRoot "..")
New-Item -ItemType Directory -Force $Out | Out-Null
$Src = Join-Path $Out "src"
if (Test-Path $Src) { Remove-Item -Recurse -Force $Src }

git clone --quiet --no-checkout $Source $Src
if ($LASTEXITCODE -ne 0) { throw "git clone of $Source failed" }
git -C $Src checkout --quiet $Ref
if ($LASTEXITCODE -ne 0) { throw "the ref $Ref is not in $Source" }
$Got = (git -C $Src rev-parse HEAD).Trim()
if ($Got -ne $Ref) { throw "checked out $Got, and vendor/PIN.md pins $Ref" }
Write-Output "ringserv $Got"

Push-Location $Src
try {
    zig build -j2 -Dtarget=x86_64-linux-musl
    if ($LASTEXITCODE -ne 0) { throw "zig build failed" }
} finally { Pop-Location }

Copy-Item (Join-Path $Src "zig-out\bin\ringserv") (Join-Path $Out "ringserv") -Force
Set-Content -Path (Join-Path $Out "REF") -Value $Got -Encoding ascii
$bin = Get-Item (Join-Path $Out "ringserv")
$hash = (Get-FileHash -Algorithm SHA256 $bin.FullName).Hash.ToLower()
Write-Output ("built {0} bytes, sha256 {1} (for the record: the pin is the source ref)" -f $bin.Length, $hash)
