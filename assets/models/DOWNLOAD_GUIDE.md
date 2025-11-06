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

**Pets** (ssets/models/pets/):
- dragon.glb
- fox.glb
- eagle.glb
- wolf.glb
- sparkle.glb
- shadow.glb

**Characters** (ssets/models/characters/):
- warrior.glb
- mage.glb
- rogue.glb
- paladin.glb

**Enemies** (ssets/models/enemies/):
- goblin.glb
- orc.glb
- skeleton.glb
- spider.glb
- ghost.glb
- slime.glb

**Bosses** (ssets/models/enemies/bosses/):
- dragon.glb
- demon_lord.glb
- ancient_mage.glb
- phoenix.glb

**Weapons** (ssets/models/equipment/weapon/):
- bronze_sword.glb
- steel_blade.glb
- golden_axe.glb
- mystic_staff.glb

**Armor** (ssets/models/equipment/armor/):
- leather_armor.glb
- iron_plate.glb
- dragon_scale.glb

### Option 3: Automated Download Script

Run this PowerShell script with actual download URLs:

`powershell
.\download_3d_assets.ps1
`

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

