# Build AAB for Google Play Store
# This script builds a release Android App Bundle (.aab) file

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Building FreeTalk AAB for Google Play Store" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Navigate to Flutter project directory
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectRoot

# Check if we're in the correct directory
if (-not (Test-Path "pubspec.yaml")) {
    Write-Host "Error: pubspec.yaml not found. Please run this script from the Flutter project root." -ForegroundColor Red
    exit 1
}

# Display current version
Write-Host "Checking version..." -ForegroundColor Yellow
$pubspecContent = Get-Content "pubspec.yaml" -Raw
if ($pubspecContent -match 'version:\s*([\d.]+)\+(\d+)') {
    $versionName = $matches[1]
    $versionCode = $matches[2]
    Write-Host "Current version: $versionName+$versionCode" -ForegroundColor Green
} else {
    Write-Host "Warning: Could not parse version from pubspec.yaml" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Step 1: Cleaning previous builds..." -ForegroundColor Yellow
flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: flutter clean failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 2: Getting dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: flutter pub get failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 3: Analyzing code..." -ForegroundColor Yellow
flutter analyze --no-fatal-infos
if ($LASTEXITCODE -ne 0) {
    Write-Host "Warning: Code analysis found issues. Continuing anyway..." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Step 4: Building App Bundle (AAB)..." -ForegroundColor Yellow
Write-Host "This may take several minutes..." -ForegroundColor Gray
flutter build appbundle --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Build failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "Build completed successfully!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""

# Locate the AAB file
$aabPath = Join-Path $projectRoot "build\app\outputs\bundle\release\app-release.aab"
if (Test-Path $aabPath) {
    $fileInfo = Get-Item $aabPath
    $fileSizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
    
    Write-Host "AAB file location:" -ForegroundColor Cyan
    Write-Host $aabPath -ForegroundColor White
    Write-Host ""
    Write-Host "File size: $fileSizeMB MB" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Upload the AAB file to Google Play Console" -ForegroundColor White
    Write-Host "2. Go to: https://play.google.com/console" -ForegroundColor White
    Write-Host "3. Select your app → Release → Production (or Testing)" -ForegroundColor White
    Write-Host "4. Create new release and upload: $aabPath" -ForegroundColor White
} else {
    Write-Host "Warning: AAB file not found at expected location" -ForegroundColor Yellow
    Write-Host "Expected location: $aabPath" -ForegroundColor Yellow
}

Write-Host ""

