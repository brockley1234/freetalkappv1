# App Icon Setup

## How to Add Your Custom App Icon

### Step 1: Create Your Icon Image
1. Design your app icon (ReelTalk logo)
2. Export as PNG file
3. **Recommended size: 1024x1024 pixels**
4. **Name it: `app_icon.png`**
5. Place it in this folder: `assets/icon/app_icon.png`

### Step 2: (Optional) Create Adaptive Icon for Android
For Android 8.0+ devices, create a foreground layer:
1. Create a foreground image (your logo without background)
2. Export as PNG (1024x1024 pixels)
3. **Name it: `app_icon_foreground.png`**
4. Place it in this folder: `assets/icon/app_icon_foreground.png`
5. The background color is set to white (#FFFFFF) in pubspec.yaml

### Step 3: Generate Icons
After placing your icon files, run:
```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

This will automatically generate all required icon sizes for:
- Android (mipmap folders with different densities)
- iOS (Assets.xcassets)

### Step 4: Rebuild Your App
```bash
flutter build appbundle --release
```

---

## Icon Requirements for Play Store:

When submitting to Google Play, you'll also need:

1. **App Icon** (already handled by flutter_launcher_icons)
   - 512x512 pixels
   - 32-bit PNG with alpha
   - Upload directly in Play Console

2. **Feature Graphic** (required for Play Store listing)
   - 1024x500 pixels
   - JPG or 24-bit PNG (no alpha)
   - Should showcase your app's brand/features

3. **Screenshots** (minimum 2, maximum 8)
   - Phone: 16:9 or 9:16 aspect ratio
   - Recommended: 1080x1920 or 1080x2340
   - PNG or JPG format

---

## Design Tips:

✅ **Do:**
- Use simple, recognizable design
- Make it distinctive and memorable
- Test on different background colors
- Ensure it's readable at small sizes (48x48)
- Use your brand colors

❌ **Don't:**
- Use too much text
- Use photos (they don't scale well)
- Copy other app icons
- Use rounded corners (Android adds them automatically)
- Use transparency for main icon (only for adaptive foreground)

---

## Current Status:
📁 Waiting for you to add: `app_icon.png` (1024x1024 PNG)

Once you add the icon file, I can generate all the required sizes for you!
