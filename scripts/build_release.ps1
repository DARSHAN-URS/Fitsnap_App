# build_release.ps1
# Automates building the release APK and copying it to the final signed release location.

Write-Host "Building release APK for ARM64 with R8 and obfuscation enabled..." -ForegroundColor Cyan
flutter build apk --release --target-platform android-arm64 --obfuscate --split-debug-info=build/app/outputs/debug-info --no-tree-shake-icons

# Define paths (checking both arm64 and arm64-v8a target names)
$apkSource = ""
if (Test-Path "build/app/outputs/flutter-apk/app-arm64-release.apk") {
    $apkSource = "build/app/outputs/flutter-apk/app-arm64-release.apk"
} elseif (Test-Path "build/app/outputs/flutter-apk/app-arm64-v8a-release.apk") {
    $apkSource = "build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
} elseif (Test-Path "build/app/outputs/flutter-apk/app-release.apk") {
    $apkSource = "build/app/outputs/flutter-apk/app-release.apk"
}

$signedApkDestDir = "build/outputs/apk/release"
$signedApkDest = "$signedApkDestDir/app-release-signed.apk"

# Ensure target directory exists
if (-not (Test-Path $signedApkDestDir)) {
    New-Item -ItemType Directory -Force -Path $signedApkDestDir | Out-Null
}

# Copy to final destination and display size
if ($apkSource -ne "" -and (Test-Path $apkSource)) {
    if (-not (Test-Path "build/app/outputs/flutter-apk/app-arm64-release.apk")) {
        Copy-Item -Path $apkSource -Destination "build/app/outputs/flutter-apk/app-arm64-release.apk" -Force
    }
    Copy-Item -Path $apkSource -Destination $signedApkDest -Force
    Write-Host "`nSuccess! Signed arm64 release APK created at: $signedApkDest" -ForegroundColor Green
    
    $file = Get-Item $signedApkDest
    $sizeMb = [Math]::Round(($file.Length / 1MB), 2)
    Write-Host "APK Size: $sizeMb MB" -ForegroundColor Yellow

    Write-Host "`nGenerated APK artifacts in build/app/outputs/flutter-apk:" -ForegroundColor Cyan
    Get-ChildItem "build/app/outputs/flutter-apk/*.apk" | ForEach-Object {
        $abiSize = [Math]::Round(($_.Length / 1MB), 2)
        Write-Host "  - $($_.Name): $abiSize MB" -ForegroundColor Gray
    }
} else {
    Write-Error "Error: Build failed or APK was not found."
    exit 1
}
