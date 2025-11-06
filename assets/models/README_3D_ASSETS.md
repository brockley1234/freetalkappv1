# 3D Assets Guide for RPG Adventure Game

## Overview

This guide explains how to add 3D models to your RPG Adventure game. The game uses a **hybrid 2D/3D approach** where:
- **2D gameplay** remains fast and efficient (tile-based map, UI)
- **3D models** enhance visual experience (pets, characters, enemies, equipment)

## File Format

- **Supported**: `.glb` (GLTF Binary) and `.gltf` (GLTF JSON)
- **Recommended**: `.glb` (smaller file size, better performance)
- **File Size**: Keep models under 5MB each for mobile performance

## Directory Structure

```
assets/models/
├── pets/
│   ├── dragon.glb
│   ├── dragon_stage1.glb (evolution stage 1)
│   ├── dragon_stage2.glb (evolution stage 2)
│   ├── dragon_stage3.glb (evolution stage 3)
│   ├── fox.glb
│   ├── eagle.glb
│   ├── wolf.glb
│   ├── sparkle.glb
│   └── shadow.glb
├── characters/
│   ├── warrior.glb
│   ├── mage.glb
│   ├── rogue.glb
│   └── paladin.glb
├── enemies/
│   ├── goblin.glb
│   ├── orc.glb
│   ├── skeleton.glb
│   ├── spider.glb
│   ├── dragon.glb
│   └── bosses/
│       ├── dragon.glb
│       ├── demon_lord.glb
│       ├── ancient_mage.glb
│       └── phoenix.glb
└── equipment/
    ├── weapon/
    │   ├── bronze_sword.glb
    │   ├── steel_blade.glb
    │   ├── golden_axe.glb
    │   └── mystic_staff.glb
    └── armor/
        ├── leather_armor.glb
        ├── iron_plate.glb
        └── dragon_scale.glb
```

## Where to Get FREE 3D Models

### 1. **Sketchfab** (Best Source)
- URL: https://sketchfab.com
- Filter: "Downloadable" + "GLB Format" + "CC License"
- Keywords: "low poly pet", "chibi dragon", "fantasy character", "RPG weapon"
- **Recommended Collections**:
  - [Quaternius](https://sketchfab.com/Quaternius) - Free low-poly game assets
  - [Kenney](https://www.kenney.nl/assets) - Free game assets

### 2. **Poly Pizza** (Free Low-Poly Models)
- URL: https://poly.pizza
- All models are free and optimized for games
- Great for cartoon/stylized characters

### 3. **Mixamo** (Animated Characters)
- URL: https://www.mixamo.com
- Free animated character models (requires Adobe account)
- Download in FBX, convert to GLB using Blender

### 4. **OpenGameArt**
- URL: https://opengameart.org
- Filter by "3D Models"
- Many free CC0 licensed models

### 5. **Free3D**
- URL: https://free3d.com
- Various free models available
- Check license before use

### 6. **CGTrader Free**
- URL: https://www.cgtrader.com/free-3d-models
- Free section with many models
- Filter by GLB/GLTF format

## Model Requirements

### Technical Specifications:
- **Polygon Count**: 
  - Pets/Characters: 1,000 - 5,000 triangles
  - Enemies: 500 - 3,000 triangles
  - Equipment: 200 - 1,000 triangles
- **Texture Size**: 512x512 or 1024x1024 (no larger than 2048x2048)
- **Animations** (optional but recommended):
  - Idle, Attack, Defend, Walk, Death
  - Embedded in GLB file
- **Materials**: PBR (Physically Based Rendering) preferred
- **Lighting**: Baked lighting recommended for better performance

### Style Guidelines:
- **Low-Poly/Stylized**: Matches the game's casual aesthetic
- **Bright Colors**: Works well with the colorful UI
- **Clear Silhouettes**: Models should be recognizable at small sizes
- **Avoid**: Realistic/photographic textures, high-poly models

## Converting Models to GLB

If you have models in other formats (FBX, OBJ, DAE), convert them using:

### Option 1: Blender (FREE)
1. Download Blender: https://www.blender.org
2. File → Import → [Your Format]
3. File → Export → glTF 2.0 (.glb)
4. Export Settings:
   - Format: GLB
   - Include: Selected Objects
   - Compression: On
   - Export!

### Option 2: Online Converters
- **GLTF Viewer**: https://gltf-viewer.donmccurdy.com
- **Babylon.js Sandbox**: https://sandbox.babylonjs.com
- **Sketchfab**: Upload and re-download as GLB

### Option 3: Command Line (glTF-Pipeline)
```bash
npm install -g gltf-pipeline
gltf-pipeline -i model.obj -o model.glb
```

## Optimizing Models

### Reduce File Size:
```bash
# Install glTF-Pipeline
npm install -g gltf-pipeline

# Optimize GLB file
gltf-pipeline -i input.glb -o output.glb -d
```

### In Blender:
1. **Decimate Modifier**: Reduce polygon count
2. **Texture Baking**: Combine multiple textures
3. **Remove Unused Materials**: Clean up materials panel
4. **Apply Transforms**: Object → Apply → All Transforms

## Adding Models to Your Project

### Step 1: Add to Assets Folder
```
assets/models/pets/dragon.glb
```

### Step 2: Update pubspec.yaml
```yaml
flutter:
  assets:
    - assets/models/pets/
    - assets/models/characters/
    - assets/models/enemies/
    - assets/models/equipment/
```

### Step 3: Test Model
```dart
// In your widget:
Model3DViewer(
  modelPath: 'assets/models/pets/dragon.glb',
  autoRotate: true,
  width: 200,
  height: 200,
)
```

## Creating Custom Models

### Beginner-Friendly 3D Software:

1. **Blender** (FREE, Professional)
   - Best for game development
   - Steep learning curve but powerful
   - Tutorial: https://www.youtube.com/watch?v=nIoXOplUvAw

2. **BlockBench** (FREE, Minecraft-style)
   - Easy to learn
   - Perfect for low-poly/voxel models
   - Web-based: https://www.blockbench.net

3. **MagicaVoxel** (FREE, Voxel Art)
   - Very beginner-friendly
   - Great for stylized models
   - Export to OBJ, then convert to GLB

4. **Tinkercad** (FREE, Simple)
   - Browser-based
   - Good for basic shapes
   - Export to OBJ/STL

### Recommended Workflow:
1. Create model in BlockBench or MagicaVoxel
2. Export as OBJ
3. Import to Blender
4. Add materials/textures
5. Export as GLB
6. Test in game!

## Animation Guide

### Recommended Animations:

**Pets:**
- `idle` - Standing still, breathing
- `happy` - Wagging tail, jumping
- `sleep` - Lying down
- `attack` - Bite or scratch motion

**Characters:**
- `idle` - Standing ready
- `attack` - Weapon swing
- `defend` - Shield up
- `victory` - Celebration pose
- `death` - Falling animation

**Enemies:**
- `idle` - Patrol or breathing
- `attack` - Lunge or strike
- `death` - Collapse
- `roar` - Boss intimidation

### Animation Tips:
- Keep animations short (1-3 seconds)
- Loop smoothly for idle animations
- Use keyframes every 2-4 frames for smooth motion
- Export at 30 FPS

## Testing Your Models

### In Flutter:
```dart
// Test model in isolation
Model3DViewer(
  modelPath: 'assets/models/pets/dragon.glb',
  autoRotate: true,
  cameraOrbit: "0deg 75deg 2.5m",
  backgroundColor: '#ffffff',
)
```

### In Browser:
- Use https://gltf-viewer.donmccurdy.com
- Drag and drop your GLB file
- Check animations, textures, size

## Troubleshooting

### Model Not Showing:
1. Check file path in pubspec.yaml
2. Run `flutter pub get`
3. Rebuild app: `flutter clean && flutter run`
4. Check browser console for errors

### Model Too Large:
1. Optimize with gltf-pipeline
2. Reduce texture resolution
3. Decimate mesh in Blender
4. Remove unnecessary materials

### Animations Not Playing:
1. Check animation names in GLB
2. Verify animations are embedded
3. Set `autoPlay: true` in ModelViewer
4. Use glTF Viewer to test animations

### Performance Issues:
1. Reduce polygon count (target < 5000 triangles)
2. Use smaller textures (512x512 or 1024x1024)
3. Limit number of 3D models on screen
4. Use LOD (Level of Detail) models for distance

## Example Models (Placeholders)

While you're sourcing real models, the game will use emoji fallbacks. Here's a quick-start list:

### Starter Pack (Free, Low-Poly):
1. **Dragon**: Search "low poly dragon" on Sketchfab
2. **Fox**: Poly Pizza has several free fox models
3. **Warrior**: Mixamo "Knight" character
4. **Sword**: Kenney's weapon pack

## Performance Best Practices

1. **Limit Concurrent 3D Models**: 
   - Max 2-3 3D models visible at once
   - Use 2D for background/UI elements

2. **Progressive Loading**:
   - Show 2D emoji while model loads
   - Use `loading: Loading.eager` for pre-caching

3. **Mobile Optimization**:
   - Test on actual devices
   - Aim for 30+ FPS
   - Monitor memory usage

4. **Fallback to 2D**:
   - Always provide emoji fallback
   - Let users toggle 3D/2D view
   - Auto-disable 3D on low-end devices

## License Considerations

Always check model licenses:
- **CC0**: Free for any use, no attribution
- **CC-BY**: Free with attribution required
- **CC-BY-SA**: Free with attribution, share-alike
- **Personal/Commercial**: Check usage rights

**Attribution Template**:
```dart
// In your about/credits screen:
// "Dragon model by [Artist] from Sketchfab (CC-BY)"
```

## Next Steps

1. ✅ Dependencies added (`model_viewer_plus`)
2. ✅ 3D viewer widgets created
3. ✅ Pet tab updated with 3D toggle
4. 🔲 Download starter models from Sketchfab
5. 🔲 Add models to assets folder
6. 🔲 Update pubspec.yaml with asset paths
7. 🔲 Test models in game
8. 🔲 Add more 3D views (battles, equipment)

## Resources

- **Flutter Model Viewer Docs**: https://pub.dev/packages/model_viewer_plus
- **GLTF Tutorial**: https://www.khronos.org/gltf/
- **Blender Game Dev**: https://www.youtube.com/c/Blenderguru
- **Low-Poly Modeling**: https://www.youtube.com/watch?v=HzZJJxR7E4I

## Support

If you encounter issues:
1. Check the model in glTF Viewer first
2. Verify file paths and pubspec.yaml
3. Test with a simple cube model
4. Check Flutter console for errors

Happy 3D modeling! 🎮✨

