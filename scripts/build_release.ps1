# build_release.ps1
# Automates building the release APK and copying it to the final signed release location.

Write-Host "Building release APKs with split-per-abi, R8, and obfuscation enabled..." -ForegroundColor Cyan
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/app/outputs/debug-info

# Define paths (using arm64-v8a as the primary optimized release target)
$apkSource = "build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
$signedApkDestDir = "build/outputs/apk/release"
$signedApkDest = "$signedApkDestDir/app-release-signed.apk"

# Ensure target directory exists
if (-not (Test-Path $signedApkDestDir)) {
    New-Item -ItemType Directory -Force -Path $signedApkDestDir | Out-Null
}

# Copy to final destination and display size
if (Test-Path $apkSource) {
    Copy-Item -Path $apkSource -Destination $signedApkDest -Force
    Write-Host "`nSuccess! Signed arm64-v8a release APK created at: $signedApkDest" -ForegroundColor Green
    
    $file = Get-Item $signedApkDest
    $sizeMb = [Math]::Round(($file.Length / 1MB), 2)
    Write-Host "APK Size: $sizeMb MB" -ForegroundColor Yellow

    # List all other ABI sizes
    Write-Host "`nAll generated ABI APKs:" -ForegroundColor Cyan
    Get-ChildItem "build/app/outputs/flutter-apk/app-*-release.apk" | ForEach-Object {
        $abiSize = [Math]::Round(($_.Length / 1MB), 2)
        Write-Host "  - $($_.Name): $abiSize MB" -ForegroundColor Gray
    }
} else {
    Write-Error "Error: Build failed or APK was not found at $apkSource"
    exit 1
}
