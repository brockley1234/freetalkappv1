# Download 3D Models for RPG Adventure Game
# This script downloads free GLB models from public sources

$assetsDir = "assets\models"
$ErrorActionPreference = "Continue"

Write-Host "=== Downloading 3D Models for RPG Adventure Game ===" -ForegroundColor Cyan
Write-Host "`nNote: Some models may need manual download from Sketchfab/Poly Pizza`n" -ForegroundColor Yellow

# Function to download with validation
function Download-Model {
    param (
        [string]$Url,
        [string]$OutputPath,
        [string]$Description
    )
    
    Write-Host "Downloading $Description..." -ForegroundColor Cyan -NoNewline
    
    try {
        $parentDir = Split-Path $OutputPath -Parent
        if (!(Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
        
        Invoke-WebRequest -Uri $Url -OutFile $OutputPath -TimeoutSec 60 -ErrorAction Stop
        
        if (Test-Path $OutputPath) {
            $size = (Get-Item $OutputPath).Length
            if ($size -gt 1000) {  # At least 1KB
                Write-Host " ✓ ($([math]::Round($size/1KB, 2)) KB)" -ForegroundColor Green
                return $true
            } else {
                Write-Host " ✗ (File too small, may be invalid)" -ForegroundColor Red
                Remove-Item $OutputPath -Force
                return $false
            }
        }
    }
    catch {
        Write-Host " ✗ (Failed: $($_.Exception.Message))" -ForegroundColor Red
        return $false
    }
    
    return $false
}

# IMPORTANT: Update these URLs with actual download links from:
# - Sketchfab (CC0 models): https://sketchfab.com
# - Poly Pizza: https://poly.pizza
# - Kenney Assets: https://kenney.nl/assets
# - GitHub repositories with free models

Write-Host "`n=== Download URLs ===`n" -ForegroundColor Yellow
Write-Host "To download models, update the URLs below with actual download links." -ForegroundColor Yellow
Write-Host "Recommended sources:" -ForegroundColor Yellow
Write-Host "1. Sketchfab - Search for 'low poly [model name]' with CC0 license" -ForegroundColor White
Write-Host "2. Poly Pizza - Browse free low-poly models" -ForegroundColor White
Write-Host "3. Kenney Assets - Download 3D model packs" -ForegroundColor White
Write-Host "`nExample URLs (replace with actual links):`n" -ForegroundColor Yellow

# Example download commands (these URLs are placeholders - replace with actual links)
# Uncomment and update URLs when you have them:

# PETS
# Download-Model -Url "https://example.com/dragon.glb" -OutputPath "$assetsDir\pets\dragon.glb" -Description "Dragon Pet"
# Download-Model -Url "https://example.com/fox.glb" -OutputPath "$assetsDir\pets\fox.glb" -Description "Fox Pet"
# Download-Model -Url "https://example.com/eagle.glb" -OutputPath "$assetsDir\pets\eagle.glb" -Description "Eagle Pet"
# Download-Model -Url "https://example.com/wolf.glb" -OutputPath "$assetsDir\pets\wolf.glb" -Description "Wolf Pet"
# Download-Model -Url "https://example.com/sparkle.glb" -OutputPath "$assetsDir\pets\sparkle.glb" -Description "Sparkle Pet"
# Download-Model -Url "https://example.com/shadow.glb" -OutputPath "$assetsDir\pets\shadow.glb" -Description "Shadow Pet"

# CHARACTERS
# Download-Model -Url "https://example.com/warrior.glb" -OutputPath "$assetsDir\characters\warrior.glb" -Description "Warrior Character"
# Download-Model -Url "https://example.com/mage.glb" -OutputPath "$assetsDir\characters\mage.glb" -Description "Mage Character"
# Download-Model -Url "https://example.com/rogue.glb" -OutputPath "$assetsDir\characters\rogue.glb" -Description "Rogue Character"
# Download-Model -Url "https://example.com/paladin.glb" -OutputPath "$assetsDir\characters\paladin.glb" -Description "Paladin Character"

# ENEMIES
# Download-Model -Url "https://example.com/goblin.glb" -OutputPath "$assetsDir\enemies\goblin.glb" -Description "Goblin Enemy"
# Download-Model -Url "https://example.com/orc.glb" -OutputPath "$assetsDir\enemies\orc.glb" -Description "Orc Enemy"
# Download-Model -Url "https://example.com/skeleton.glb" -OutputPath "$assetsDir\enemies\skeleton.glb" -Description "Skeleton Enemy"
# Download-Model -Url "https://example.com/spider.glb" -OutputPath "$assetsDir\enemies\spider.glb" -Description "Spider Enemy"

# BOSSES
# Download-Model -Url "https://example.com/dragon_boss.glb" -OutputPath "$assetsDir\enemies\bosses\dragon.glb" -Description "Dragon Boss"
# Download-Model -Url "https://example.com/demon_lord.glb" -OutputPath "$assetsDir\enemies\bosses\demon_lord.glb" -Description "Demon Lord Boss"

# WEAPONS
# Download-Model -Url "https://example.com/sword.glb" -OutputPath "$assetsDir\equipment\weapon\bronze_sword.glb" -Description "Bronze Sword"
# Download-Model -Url "https://example.com/staff.glb" -OutputPath "$assetsDir\equipment\weapon\mystic_staff.glb" -Description "Mystic Staff"

# ARMOR
# Download-Model -Url "https://example.com/armor.glb" -OutputPath "$assetsDir\equipment\armor\leather_armor.glb" -Description "Leather Armor"

Write-Host "`n=== Quick Download Guide ===" -ForegroundColor Cyan
Write-Host "`n1. Visit Sketchfab (https://sketchfab.com)" -ForegroundColor White
Write-Host "2. Search for models (e.g., 'low poly dragon')" -ForegroundColor White
Write-Host "3. Filter by: Downloadable + CC0 license" -ForegroundColor White
Write-Host "4. Download GLB format" -ForegroundColor White
Write-Host "5. Copy download URL and update this script" -ForegroundColor White
Write-Host "`nOr use Poly Pizza (https://poly.pizza) for free low-poly models!" -ForegroundColor Yellow

Write-Host "`n✓ Script ready! Update URLs and run to download models." -ForegroundColor Green
