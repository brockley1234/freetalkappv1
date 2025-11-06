import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

/// 3D Model Viewer Widget for displaying GLB/GLTF models
/// Used for pets, characters, enemies, and equipment
class Model3DViewer extends StatelessWidget {
  final String modelPath;
  final String? skyboxImage;
  final bool autoRotate;
  final bool enablePan;
  final bool enableZoom;
  final double width;
  final double height;
  final String? cameraOrbit;
  final String? backgroundColor;
  final VoidCallback? onTap;
  final List<String>? animationNames;
  final bool autoPlay;

  const Model3DViewer({
    super.key,
    required this.modelPath,
    this.skyboxImage,
    this.autoRotate = true,
    this.enablePan = true,
    this.enableZoom = true,
    this.width = 300,
    this.height = 300,
    this.cameraOrbit,
    this.backgroundColor,
    this.onTap,
    this.animationNames,
    this.autoPlay = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: height,
        child: ModelViewer(
          src: modelPath,
          alt: "3D Model",
          ar: false,
          autoRotate: autoRotate,
          disablePan: !enablePan,
          disableZoom: !enableZoom,
          cameraControls: true,
          cameraOrbit: cameraOrbit ?? "0deg 75deg 2.5m",
          autoPlay: autoPlay,
          backgroundColor: backgroundColor != null 
              ? Color(int.parse(backgroundColor!.replaceFirst('#', '0xFF')))
              : Colors.transparent,
          skyboxImage: skyboxImage,
          // Enable shadows for better depth perception
          shadowIntensity: 1.0,
          shadowSoftness: 0.8,
          exposure: 1.0,
          // Animation settings
          animationName: animationNames?.isNotEmpty == true ? animationNames!.first : null,
          // Interaction settings
          interactionPrompt: InteractionPrompt.none,
          loading: Loading.eager,
        ),
      ),
    );
  }
}

/// 3D Pet Model Viewer with evolution stages
class Pet3DViewer extends StatefulWidget {
  final String petType; // 'dragon', 'fox', 'eagle', etc.
  final int evolutionStage; // 0-3
  final int level;
  final bool isAlive;
  final VoidCallback? onTap;

  const Pet3DViewer({
    super.key,
    required this.petType,
    required this.evolutionStage,
    required this.level,
    this.isAlive = true,
    this.onTap,
  });

  @override
  State<Pet3DViewer> createState() => _Pet3DViewerState();
}

class _Pet3DViewerState extends State<Pet3DViewer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getPetModelPath() {
    // Map pet types to 3D model paths
    // In production, these would be actual .glb files
    final baseModels = {
      'dragon': 'assets/models/pets/dragon.glb',
      'fox': 'assets/models/pets/fox.glb',
      'eagle': 'assets/models/pets/eagle.glb',
      'wolf': 'assets/models/pets/wolf.glb',
      'sparkle': 'assets/models/pets/sparkle.glb',
      'shadow': 'assets/models/pets/shadow.glb',
    };

    // Add evolution stage suffix
    String petKey = widget.petType.toLowerCase();
    if (!baseModels.containsKey(petKey)) {
      petKey = 'dragon'; // Default fallback
    }

    // Evolution stages could use different models or materials
    if (widget.evolutionStage > 0) {
      return baseModels[petKey]!.replaceAll('.glb', '_stage${widget.evolutionStage}.glb');
    }

    return baseModels[petKey]!;
  }

  Color _getPetGlowColor() {
    switch (widget.evolutionStage) {
      case 1:
        return Colors.blue.withValues(alpha: 0.3);
      case 2:
              return Colors.purple.withValues(alpha: 0.4);
      case 3:
        return Colors.amber.withValues(alpha: 0.5);
      default:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow effect for evolved pets
        if (widget.evolutionStage > 0)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                width: 200 + (20 * _controller.value),
                height: 200 + (20 * _controller.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _getPetGlowColor(),
                      blurRadius: 30 + (10 * _controller.value),
                      spreadRadius: 10 + (5 * _controller.value),
                    ),
                  ],
                ),
              );
            },
          ),
        
        // 3D Model
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.purple.shade100.withValues(alpha: 0.3),
                Colors.blue.shade100.withValues(alpha: 0.3),
              ],
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Model3DViewer(
              modelPath: _getPetModelPath(),
              autoRotate: widget.isAlive,
              width: 250,
              height: 250,
              cameraOrbit: "0deg 75deg 3m",
              backgroundColor: '#00000000', // Transparent
              onTap: widget.onTap,
              animationNames: widget.isAlive ? ['idle', 'happy'] : ['sleep'],
              autoPlay: true,
            ),
          ),
        ),

        // Level indicator
        Positioned(
          bottom: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Text(
              'Lv ${widget.level}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),

        // Evolution stage indicator
        if (widget.evolutionStage > 0)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getPetGlowColor(),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                '⭐' * (widget.evolutionStage),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
      ],
    );
  }
}

/// 3D Character Model Viewer for battles
class Character3DViewer extends StatelessWidget {
  final String characterClass; // 'warrior', 'mage', 'rogue', 'paladin'
  final int level;
  final String? equippedWeapon;
  final String? equippedArmor;
  final bool isAttacking;
  final bool isDefending;
  final double width;
  final double height;

  const Character3DViewer({
    super.key,
    required this.characterClass,
    required this.level,
    this.equippedWeapon,
    this.equippedArmor,
    this.isAttacking = false,
    this.isDefending = false,
    this.width = 200,
    this.height = 200,
  });

  String _getCharacterModelPath() {
    final baseModels = {
      'warrior': 'assets/models/characters/warrior.glb',
      'mage': 'assets/models/characters/mage.glb',
      'rogue': 'assets/models/characters/rogue.glb',
      'paladin': 'assets/models/characters/paladin.glb',
    };

    return baseModels[characterClass.toLowerCase()] ?? baseModels['warrior']!;
  }

  List<String> _getAnimations() {
    if (isAttacking) return ['attack', 'slash', 'strike'];
    if (isDefending) return ['defend', 'block', 'guard'];
    return ['idle', 'breathe'];
  }

  @override
  Widget build(BuildContext context) {
    return Model3DViewer(
      modelPath: _getCharacterModelPath(),
      autoRotate: false,
      width: width,
      height: height,
      cameraOrbit: "45deg 75deg 2m",
      backgroundColor: '#1a1a2e',
      animationNames: _getAnimations(),
      autoPlay: true,
    );
  }
}

/// 3D Enemy Model Viewer for battles
class Enemy3DViewer extends StatelessWidget {
  final String enemyType;
  final bool isBoss;
  final int level;
  final bool isAttacking;
  final double width;
  final double height;

  const Enemy3DViewer({
    super.key,
    required this.enemyType,
    required this.isBoss,
    required this.level,
    this.isAttacking = false,
    this.width = 200,
    this.height = 200,
  });

  String _getEnemyModelPath() {
    // Extract enemy name from type (removes emoji)
    final cleanName = enemyType.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .trim()
        .replaceAll(' ', '_');

    if (isBoss) {
      return 'assets/models/enemies/bosses/$cleanName.glb';
    }

    return 'assets/models/enemies/$cleanName.glb';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Boss aura effect
        if (isBoss)
          Container(
            width: width + 40,
            height: height + 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withValues(alpha: 0.5),
                  blurRadius: 30,
                  spreadRadius: 15,
                ),
              ],
            ),
          ),

        // 3D Model
        Model3DViewer(
          modelPath: _getEnemyModelPath(),
          autoRotate: !isAttacking,
          width: width,
          height: height,
          cameraOrbit: isBoss ? "0deg 80deg 3.5m" : "0deg 75deg 2.5m",
          backgroundColor: '#2d1b1b',
          animationNames: isAttacking ? ['attack', 'roar'] : ['idle', 'breathe'],
          autoPlay: true,
        ),

        // Boss crown
        if (isBoss)
          Positioned(
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.purple.shade900,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber, width: 2),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('👑', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 4),
                  Text(
                    'BOSS',
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 3D Equipment Model Viewer
class Equipment3DViewer extends StatelessWidget {
  final String equipmentName;
  final String equipmentType; // 'weapon', 'armor', 'ring', etc.
  final String rarity;
  final bool showStats;

  const Equipment3DViewer({
    super.key,
    required this.equipmentName,
    required this.equipmentType,
    required this.rarity,
    this.showStats = true,
  });

  String _getEquipmentModelPath() {
    final cleanName = equipmentName.toLowerCase().replaceAll(' ', '_');
    return 'assets/models/equipment/$equipmentType/$cleanName.glb';
  }

  Color _getRarityGlow() {
    switch (rarity.toLowerCase()) {
      case 'legendary':
        return Colors.orange;
      case 'epic':
        return Colors.purple;
      case 'rare':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: RadialGradient(
          colors: [
            _getRarityGlow().withValues(alpha: 0.3),
            Colors.black.withValues(alpha: 0.8),
          ],
        ),
        border: Border.all(color: _getRarityGlow(), width: 2),
      ),
      child: Model3DViewer(
        modelPath: _getEquipmentModelPath(),
        autoRotate: true,
        width: 200,
        height: 200,
        cameraOrbit: "45deg 60deg 2m",
        backgroundColor: '#000000',
      ),
    );
  }
}

