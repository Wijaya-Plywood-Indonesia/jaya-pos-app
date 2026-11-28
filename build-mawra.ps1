# Build APK Mawra POS dengan nama file rapi, hasil di folder dist\
# Pemakaian:  .\build-mawra.ps1
#             .\build-mawra.ps1 -Server "https://pos.domainmu.com"
param(
    [string]$Server = "https://mawra.wijayaplywoods.com"
)

$ErrorActionPreference = "Stop"

flutter build apk --release --split-per-abi --dart-define=JAYA_SERVER_URL=$Server
if ($LASTEXITCODE -ne 0) { throw "Build gagal, lihat pesan error di atas." }

# Versi diambil dari pubspec.yaml (bagian sebelum tanda +)
$line = Select-String -Path "pubspec.yaml" -Pattern '^version:\s*(\S+)' | Select-Object -First 1
$version = if ($line) { $line.Matches[0].Groups[1].Value.Split('+')[0] } else { "1.0.0" }

$src = "build\app\outputs\flutter-apk"
$dist = "dist"
New-Item -ItemType Directory -Force -Path $dist | Out-Null

Get-ChildItem "$src\app-*-release.apk" | ForEach-Object {
    $abi = $_.Name -replace '^app-(.+)-release\.apk$', '$1'
    $target = Join-Path $dist "Mawra-POS-v$version-$abi.apk"
    Copy-Item $_.FullName $target -Force
    Write-Host "OK  $target"
}

Write-Host ""
Write-Host "Untuk HP Android modern pakai file: Mawra-POS-v$version-arm64-v8a.apk"
