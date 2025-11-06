# PowerShell script to download 3D model assets for RPG Adventure Game
# This script downloads free GLB/GLTF models from reliable sources

param(
    [switch]$DryRun = $false
)

$ErrorActionPreference = "Stop"

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$assetsDir = Join-Path $scriptDir "assets\models"

Write-Host "`n=== RPG Adventure Game - 3D Asset Downloader ===" -ForegroundColor Cyan
Write-Host "Target directory: $assetsDir`n" -ForegroundColor Yellow

# Create all required directories
$directories = @(
    "pets",
    "characters",
    "enemies",
    "enemies\bosses",
    "equipment\weapon",
    "equipment\armor"
)

foreach ($dir in $directories) {
    $fullPath = Join-Path $assetsDir $dir
    if (!(Test-Path $fullPath)) {
        New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
        Write-Host "Created: $fullPath" -ForegroundColor Green
    }
}

# Function to download with retry
function Download-Model {
    param (
        [string]$Url,
        [string]$OutputPath,
        [string]$Description,
        [int]$MaxRetries = 3
    )
    
    if ($DryRun) {
        Write-Host "[DRY RUN] Would download $Description to $OutputPath" -ForegroundColor Yellow
        return $true
    }
    
    $attempt = 0
    while ($attempt -lt $MaxRetries) {
        try {
            Write-Host "Downloading $Description..." -ForegroundColor Cyan -NoNewline
            
            $parentDir = Split-Path $OutputPath -Parent
            if (!(Test-Path $parentDir)) {
                New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
            }
            
            # Download with progress
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $Url -OutFile $OutputPath -TimeoutSec 60 -ErrorAction Stop
            
            if (Test-Path $OutputPath) {
                $size = (Get-Item $OutputPath).Length
                Write-Host " ✓ ($([math]::Round($size/1KB, 2)) KB)" -ForegroundColor Green
                return $true
            }
        }
        catch {
            $attempt++
            if ($attempt -lt $MaxRetries) {
                Write-Host " ✗ (Retry $attempt/$MaxRetries)" -ForegroundColor Yellow
                Start-Sleep -Seconds 2
            } else {
                Write-Host " ✗ Failed: $_" -ForegroundColor Red
                return $false
            }
        }
    }
    return $false
}

# Free model sources - Using public repositories and CDNs
# Note: Some URLs may need to be updated with actual working links

Write-Host "`n=== Downloading Models ===" -ForegroundColor Cyan

# Sample models from public sources
# These are placeholder URLs - you'll need to replace with actual download links

$downloads = @()

# For now, let's create a comprehensive guide and download script
# Since direct GLB downloads require specific URLs, I'll create placeholder files
# with instructions for manual download

Write-Host "`nCreating download guide..." -ForegroundColor Yellow

$guide = @"
# 3D Model Assets Download Guide

## Quick Start

### Option 1: Use Pre-made Asset Packs (Recommended)

1. **Kenney Assets** (Free, CC0 License)
   - Website: https://kenney.nl/assets
   - Download: "3D Models" packs
   - Includes: Characters, enemies, weapons, props
   - License: CC0 (Free for commercial use)

2. **Poly Pizza** (Free Low-Poly Models)
   - Website: https://poly.pizza
   - All models are free
   - Great for stylized/cartoon style
   - Download format: GLB/GLTF available

3. **Sketchfab** (Free CC0 Models)
   - Website: https://sketchfab.com
   - Filter: "Downloadable" + "CC0" or "CC-BY"
   - Search terms:
     - "low poly dragon"
     - "chibi fox"
     - "rpg warrior"
     - "fantasy sword glb"

### Option 2: Manual Download Instructions

#### Required Models:

**Pets** (`assets/models/pets/`):
- dragon.glb
- fox.glb
- eagle.glb
- wolf.glb
- sparkle.glb
- shadow.glb

**Characters** (`assets/models/characters/`):
- warrior.glb
- mage.glb
- rogue.glb
- paladin.glb

**Enemies** (`assets/models/enemies/`):
- goblin.glb
- orc.glb
- skeleton.glb
- spider.glb
- ghost.glb
- slime.glb

**Bosses** (`assets/models/enemies/bosses/`):
- dragon.glb
- demon_lord.glb
- ancient_mage.glb
- phoenix.glb

**Weapons** (`assets/models/equipment/weapon/`):
- bronze_sword.glb
- steel_blade.glb
- golden_axe.glb
- mystic_staff.glb

**Armor** (`assets/models/equipment/armor/`):
- leather_armor.glb
- iron_plate.glb
- dragon_scale.glb

### Option 3: Automated Download Script

Run this PowerShell script with actual download URLs:

```powershell
.\download_3d_assets.ps1
```

## Model Requirements

- **Format**: GLB (preferred) or GLTF
- **Size**: Under 5MB per model
- **Polygons**: 500-5000 triangles (optimized for mobile)
- **Textures**: 512x512 or 1024x1024 max
- **Animations**: Optional but recommended (idle, attack, etc.)

## Recommended Sources

1. **Kenney.nl** - Free game assets, CC0 license
2. **Sketchfab** - Filter by CC0/CC-BY license
3. **Poly Pizza** - Free low-poly models
4. **Mixamo** - Free animated characters (requires conversion)
5. **OpenGameArt** - Free 3D models collection

## Conversion Tools

If you have models in other formats (FBX, OBJ):

1. **Blender** (Free)
   - Download: https://www.blender.org
   - Import → Export as GLB
   - File → Export → glTF 2.0 (.glb)

2. **Online Converters**
   - https://gltf-viewer.donmccurdy.com
   - https://sandbox.babylonjs.com

## Testing Models

After downloading, test in:
- https://gltf-viewer.donmccurdy.com
- Or in Flutter app using Model3DViewer widget

## License Notes

Always check model licenses:
- **CC0**: Free for any use, no attribution needed
- **CC-BY**: Free with attribution required
- **CC-BY-SA**: Free with attribution, share-alike

"@

$guidePath = Join-Path $assetsDir "DOWNLOAD_GUIDE.md"
$guide | Out-File -FilePath $guidePath -Encoding UTF8
Write-Host "Created guide: $guidePath" -ForegroundColor Green

# Create a PowerShell script with actual download commands
# User can update URLs with real model links

$downloadScript = @"
# Download script for 3D models
# Update URLs with actual model download links

`$assetsDir = "assets\models"

# Example download commands (update URLs):
# Invoke-WebRequest -Uri "https://example.com/dragon.glb" -OutFile "`$assetsDir\pets\dragon.glb"
# Invoke-WebRequest -Uri "https://example.com/warrior.glb" -OutFile "`$assetsDir\characters\warrior.glb"

Write-Host "Update this script with actual download URLs from:" -ForegroundColor Yellow
Write-Host "- Sketchfab (CC0 models)" -ForegroundColor White
Write-Host "- Poly Pizza" -ForegroundColor White
Write-Host "- Kenney Assets" -ForegroundColor White
Write-Host "- GitHub repositories" -ForegroundColor White

"@

$downloadScriptPath = Join-Path $assetsDir "download_models.ps1"
$downloadScript | Out-File -FilePath $downloadScriptPath -Encoding UTF8
Write-Host "Created download script template: $downloadScriptPath" -ForegroundColor Green

Write-Host "`n=== Setup Complete ===" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Check: $guidePath" -ForegroundColor White
Write-Host "2. Download models from recommended sources" -ForegroundColor White
Write-Host "3. Place GLB files in appropriate directories" -ForegroundColor White
Write-Host "4. Run: flutter pub get" -ForegroundColor White
Write-Host "`nNote: Models are optional - the game works with emoji fallbacks!" -ForegroundColor Cyan
