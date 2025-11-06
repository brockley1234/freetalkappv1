# Quick Start: Adding 3D Models to RPG Adventure

## 🎮 What You Get

Your RPG Adventure game now has **hybrid 2D/3D** support! This means:
- ✨ **3D pet companions** that rotate and evolve
- ⚔️ **3D battle visualizations** (coming soon)
- 🗡️ **3D equipment preview** (coming soon)
- 🎭 **Toggle between 2D and 3D** views anytime

## 🚀 5-Minute Setup

### Step 1: Install Dependencies

```bash
cd "Backup 10-28-25/freetalk"
flutter pub get
```

This installs the `model_viewer_plus` package for 3D model rendering.

### Step 2: Create Asset Directories

The directories are already referenced in `pubspec.yaml`. Create them:

```bash
# Windows PowerShell
New-Item -Path "assets/models/pets" -ItemType Directory -Force
New-Item -Path "assets/models/characters" -ItemType Directory -Force
New-Item -Path "assets/models/enemies" -ItemType Directory -Force
New-Item -Path "assets/models/enemies/bosses" -ItemType Directory -Force
New-Item -Path "assets/models/equipment/weapon" -ItemType Directory -Force
New-Item -Path "assets/models/equipment/armor" -ItemType Directory -Force

# Linux/Mac
mkdir -p assets/models/{pets,characters,enemies/bosses,equipment/weapon,equipment/armor}
```

### Step 3: Download FREE Starter Models

#### Option A: Quick Starter Pack (Recommended)

Visit these direct links for free, game-ready models:

1. **Dragon Pet** (Main pet):
   - https://sketchfab.com/3d-models/low-poly-dragon-free-download
   - Download as GLB → Rename to `dragon.glb`
   - Place in: `assets/models/pets/dragon.glb`

2. **Fox Pet**:
   - https://poly.pizza/m/fox
   - Download → Save as `fox.glb`
   - Place in: `assets/models/pets/fox.glb`

3. **Warrior Character**:
   - https://www.mixamo.com (free account required)
   - Choose "Knight" or "Warrior" model
   - Download as FBX, convert to GLB (see below)
   - Place in: `assets/models/characters/warrior.glb`

#### Option B: Search and Download

**Best Free 3D Model Sites:**

1. **Sketchfab** (https://sketchfab.com)
   - Filter: "Downloadable" + "Free"
   - Search: "low poly dragon", "low poly fox", "chibi pet"
   - Download format: GLB

2. **Poly Pizza** (https://poly.pizza)
   - All models are free!
   - Great for stylized/cartoon characters
   - Already in GLB format

3. **Quaternius** (Free Game Assets)
   - https://quaternius.com/packs.html
   - Download "Ultimate Animated Characters Pack"
   - Extract GLB files

### Step 4: Convert Models to GLB (If Needed)

If you downloaded FBX, OBJ, or other formats:

**Using Online Converter (Easiest):**
1. Go to: https://products.aspose.app/3d/conversion
2. Upload your file (FBX, OBJ, etc.)
3. Convert to GLB
4. Download!

**Using Blender (FREE, Powerful):**
1. Download Blender: https://www.blender.org
2. File → Import → [Your Format]
3. File → Export → glTF 2.0 (.glb)
4. Save!

### Step 5: Test Your Game!

```bash
flutter run -d chrome  # Test in browser (fastest)
# OR
flutter run            # Test on mobile/emulator
```

Navigate to: Games → RPG Adventure → Pet Tab
Toggle the 3D/2D switch to see your models!

## 📂 File Organization

Your models should be organized like this:

```
assets/models/
├── pets/
│   ├── dragon.glb          ← Your main dragon
│   ├── dragon_stage1.glb   ← Optional: Evolution stage 1
│   ├── dragon_stage2.glb   ← Optional: Evolution stage 2
│   ├── dragon_stage3.glb   ← Optional: Evolution stage 3
│   ├── fox.glb
│   ├── eagle.glb
│   └── wolf.glb
├── characters/
│   ├── warrior.glb
│   ├── mage.glb
│   ├── rogue.glb
│   └── paladin.glb
└── enemies/
    ├── goblin.glb
    ├── skeleton.glb
    └── bosses/
        └── dragon.glb
```

## 🎯 Minimum Viable Setup

**Don't have time to get all models?** Just get these 3:

1. `dragon.glb` → `assets/models/pets/`
2. `warrior.glb` → `assets/models/characters/`
3. `goblin.glb` → `assets/models/enemies/`

The game will use emoji fallbacks for missing models!

## ⚡ Quick Model Sources

### 1. Kenney Game Assets (FREE Pack)
- URL: https://kenney.nl/assets/characters-pack
- Download "Characters Pack" (includes multiple GLB files)
- Copy to appropriate folders

### 2. Quaternius Mega Pack (FREE)
- URL: https://quaternius.com/packs.html
- Download "Ultimate Low Poly Creatures Pack"
- Extract and organize by type

### 3. Mixamo Characters (FREE, Animated)
- URL: https://www.mixamo.com
- Create free Adobe account
- Download characters with animations
- Convert FBX → GLB

## 🔧 Troubleshooting

### "Model not showing" ❌
**Fix:**
```bash
flutter clean
flutter pub get
flutter run
```

### "File path error" ❌
**Check:**
1. Model is in correct folder? (`assets/models/pets/dragon.glb`)
2. Ran `flutter pub get`?
3. Restarted app after adding model?

### "Model too big/slow" ❌
**Optimize:**
```bash
# Install optimizer
npm install -g gltf-pipeline

# Compress model
gltf-pipeline -i dragon.glb -o dragon_optimized.glb -d
```

Target size: < 2MB per model for mobile

### "Animation not playing" ❌
**Check:**
1. Model has animations embedded?
2. Test in: https://gltf-viewer.donmccurdy.com
3. Animation names are correct?

## 🎨 Model Requirements

**For Best Results:**
- **Format**: GLB (not GLTF JSON, not FBX)
- **Size**: Under 2MB each
- **Polygons**: 1,000 - 5,000 triangles
- **Textures**: 512x512 or 1024x1024
- **Style**: Low-poly, cartoon, stylized

**Avoid:**
- Realistic/photographic models
- High-poly (> 10,000 triangles)
- Large textures (> 2048x2048)
- Multiple materials (keep it simple)

## 🚀 Next Steps

After basic setup:

1. **Add More Pets**: Create evolution stages
   - `dragon_stage1.glb`, `dragon_stage2.glb`, etc.

2. **Add Character Models**: One for each class
   - `warrior.glb`, `mage.glb`, `rogue.glb`, `paladin.glb`

3. **Add Enemy Models**: For battles
   - Regular enemies: `goblin.glb`, `skeleton.glb`
   - Bosses: `enemies/bosses/dragon.glb`

4. **Add Equipment Models**: For item preview
   - Weapons: `equipment/weapon/sword.glb`
   - Armor: `equipment/armor/plate.glb`

5. **Enable 3D Battles** (coming soon in next update)

## 📚 Resources

- **Full 3D Guide**: See `assets/models/README_3D_ASSETS.md`
- **Model Viewer Docs**: https://pub.dev/packages/model_viewer_plus
- **Blender Tutorials**: https://www.youtube.com/c/Blenderguru
- **GLB Viewer**: https://gltf-viewer.donmccurdy.com

## 🎮 Feature Roadmap

- [x] 3D Pet Viewer with evolution effects
- [x] 2D/3D toggle in Pet tab
- [ ] 3D Battle scenes with character models
- [ ] 3D Enemy models in combat
- [ ] 3D Equipment preview in inventory
- [ ] Animated skill effects
- [ ] Dynamic camera angles in battles

## 💡 Tips

1. **Start with free models** - Don't spend money yet!
2. **Test in browser first** - Faster development
3. **Use small models** - Mobile performance matters
4. **Keep 2D fallback** - Not all devices support WebGL
5. **Attribution** - Credit artists in your credits screen

## 🆘 Need Help?

1. Check the full guide: `README_3D_ASSETS.md`
2. Test models in: https://gltf-viewer.donmccurdy.com
3. Read Flutter docs: https://docs.flutter.dev

---

**You're all set!** 🎉

The game will use 2D emojis until you add 3D models.
Start with just the dragon model and go from there!

Happy gaming! 🎮✨

