import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'combat_engine.dart';
import '../../services/game_service.dart';
import '../../utils/app_logger.dart';
import 'games_list_page.dart';
import 'widgets/model_3d_viewer.dart';

/// RPG Adventure - An epic turn-based RPG adventure game
/// Enhanced with:
/// - Daily quests & challenges
/// - Achievements system with medals
/// - Pet companion system
/// - Item shop & equipment enchantment
/// - Dungeon raids (multiplayer co-op simulation)
/// - Skill trees & class specialization
/// - Leaderboards
/// - Battle animations & visual effects
/// - Weekly tournaments
/// - Auto-save & manual save system
/// - Tutorial & help system
/// - Improved UI/UX with better feedback
class RPGAdventureGame extends StatefulWidget {
  const RPGAdventureGame({super.key});

  @override
  State<RPGAdventureGame> createState() => _RPGAdventureGameState();
}

/// Elemental types for damage system
enum ElementType {
  none,
  fire,
  ice,
  lightning,
  poison,
  holy,
  dark,
}

/// Player skill definition
class Skill {
  final String name;
  final String icon;
  final int manaCost;
  final int damage;
  final int heal;
  final String effect; // 'damage', 'heal', 'stun', 'poison', 'shield', 'buff', 'ultimate'
  final ElementType element;
  final int? comboBonus; // Extra damage when combo is active
  final int unlockLevel; // Level required to unlock
  final bool isUltimate; // Ultimate ability (high cooldown, high cost)
  final String? buffType; // Type of buff if effect is 'buff'
  int cooldown = 0;
  int level = 1; // Skill level for upgrades

  Skill({
    required this.name,
    required this.icon,
    required this.manaCost,
    this.damage = 0,
    this.heal = 0,
    this.effect = 'damage',
    this.element = ElementType.none,
    this.comboBonus,
    this.unlockLevel = 1,
    this.isUltimate = false,
    this.buffType,
  });

  bool get isOnCooldown => cooldown > 0;
  bool get isUnlocked => unlockLevel <= 1; // Will be set by player level
  
  Skill copyWith({int? level}) => Skill(
    name: name,
    icon: icon,
    manaCost: manaCost,
    damage: damage,
    heal: heal,
    effect: effect,
    element: element,
    comboBonus: comboBonus,
    unlockLevel: unlockLevel,
    isUltimate: isUltimate,
    buffType: buffType,
  )..level = level ?? this.level;
}

/// Skill tree node for character progression
class SkillTreeNode {
  final String id;
  final String name;
  final String description;
  final String icon;
  final int unlockLevel;
  final int skillPointsRequired;
  final SkillTreeNode? parent;
  final List<SkillTreeNode> children;
  bool unlocked = false;

  SkillTreeNode({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.unlockLevel,
    this.skillPointsRequired = 1,
    this.parent,
    this.children = const [],
  });
}

/// Equipment item
class Equipment {
  final String name;
  final String rarity; // 'common', 'rare', 'epic', 'legendary'
  final String slot; // 'weapon', 'armor', 'ring', 'amulet', 'boots'
  final int atkBonus;
  final int defBonus;
  final int hpBonus;
  final ElementType element;
  final String? setName; // Set name for set bonuses
  int enchantmentLevel;

  Equipment({
    required this.name,
    required this.rarity,
    required this.slot,
    this.atkBonus = 0,
    this.defBonus = 0,
    this.hpBonus = 0,
    this.element = ElementType.none,
    this.enchantmentLevel = 0,
    this.setName,
  });

  Color getRarityColor() {
    switch (rarity) {
      case 'rare':
        return Colors.blue;
      case 'epic':
        return Colors.purple;
      case 'legendary':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String getRarityEmoji() {
    switch (rarity) {
      case 'rare':
        return '🔵';
      case 'epic':
        return '💜';
      case 'legendary':
        return '⭐';
      default:
        return '⚪';
    }
  }

  int getTotalAtkBonus() => atkBonus + (enchantmentLevel * 2);
  int getTotalDefBonus() => defBonus + (enchantmentLevel * 1);
  int getTotalHpBonus() => hpBonus + (enchantmentLevel * 5);
}

/// Equipment set bonus
class SetBonus {
  final String setName;
  final int piecesRequired;
  final String effect;
  final int value;

  SetBonus({
    required this.setName,
    required this.piecesRequired,
    required this.effect,
    required this.value,
  });
}

/// Status effects
class StatusEffect {
  final String name;
  final String emoji;
  final int duration;
  int remainingTurns;

  StatusEffect({
    required this.name,
    required this.emoji,
    required this.duration,
  }) : remainingTurns = duration;
}

/// Quest system
class Quest {
  final String id;
  final String name;
  final String description;
  final String icon;
  final int targetValue;
  int progress;
  final int goldReward;
  final int expReward;
  bool completed;

  Quest({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.targetValue,
    required this.goldReward,
    required this.expReward,
    this.progress = 0,
    this.completed = false,
  });

  double get progressPercent => (progress / targetValue).clamp(0, 1);
  bool get isCompleted => progress >= targetValue;
}

/// Enemy on the map - tracks position and enemy data
class MapEnemy {
  Point<int> position;
  Enemy enemy;
  DateTime lastMoveTime;
  int moveDirection; // 0=up, 1=right, 2=down, 3=left, -1=random

  MapEnemy({
    required this.position,
    required this.enemy,
    DateTime? lastMoveTime,
    this.moveDirection = -1,
  }) : lastMoveTime = lastMoveTime ?? DateTime.now();

  void move(Point<int> newPosition) {
    position = newPosition;
    lastMoveTime = DateTime.now();
  }
}

/// Pet companion
class PetCompanion {
  String name;
  String emoji;
  int level;
  int exp;
  int maxHp;
  int hp;
  int atkBonus;
  int defBonus;
  String? specialAbility; // Combat ability name
  int abilityCooldown = 0;
  int evolutionStage = 0; // 0-3 stages

  PetCompanion({
    required this.name,
    required this.emoji,
    this.level = 1,
    this.exp = 0,
    this.maxHp = 30,
    int? hp,
    this.atkBonus = 2,
    this.defBonus = 1,
    this.specialAbility,
    this.evolutionStage = 0,
  }) : hp = hp ?? 30;

  void takeDamage(int damage) {
    hp = max(0, hp - damage);
  }

  void heal(int amount) {
    hp = min(hp + amount, maxHp);
  }

  bool get isAlive => hp > 0;
  
  String get evolvedEmoji {
    if (evolutionStage == 0) return emoji;
    if (evolutionStage == 1) return '$emoji✨';
    if (evolutionStage == 2) return '$emoji⭐';
    return '$emoji👑';
  }
  
  void evolve() {
    if (evolutionStage < 3 && level >= (evolutionStage + 1) * 5) {
      evolutionStage++;
      maxHp = (maxHp * 1.2).toInt();
      hp = maxHp;
      atkBonus = (atkBonus * 1.15).toInt();
      defBonus = (defBonus * 1.15).toInt();
    }
  }
}

/// Achievement system
class Achievement {
  final String id;
  final String name;
  final String description;
  final String icon;
  final int reward;
  bool unlocked;
  DateTime? unlockedAt;

  Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.reward,
    this.unlocked = false,
    this.unlockedAt,
  });

  void unlock() {
    if (!unlocked) {
      unlocked = true;
      unlockedAt = DateTime.now();
    }
  }
}

class _RPGAdventureGameState extends State<RPGAdventureGame>
    with TickerProviderStateMixin {
  late AnimationController _attackController;
  late AnimationController _healController;
  late AnimationController _movementController;

  // Player stats
  int playerHP = 0;
  int playerMaxHP = 0;
  int playerLevel = 1;
  int playerExp = 0;
  int playerExpToLevel = 0;
  int playerATK = 0;
  int playerDEF = 0;
  int playerGold = 0;
  int manaPoints = 0;
  int maxMana = 0;
  int comboCounter = 0;
  int streak = 0; // Consecutive hits
  CharacterClass playerClass = CharacterClass.warrior;
  
  // Advanced combat mechanics
  int dodgeChance = 5; // Base dodge chance %
  int parryChance = 3; // Base parry chance %
  int blockChance = 8; // Base block chance %
  bool isDefending = false; // Guard state
  
  // Damage numbers for animation
  List<DamageNumber> damageNumbers = [];
  
  // Combat log
  List<String> combatLog = [];

  // Equipment
  List<Equipment> equipment = [];
  Equipment? equippedWeapon;
  Equipment? equippedArmor;
  Equipment? equippedRing;
  Equipment? equippedAmulet;
  Equipment? equippedBoots;
  
  // Skill tree system
  int skillPoints = 0;
  List<SkillTreeNode> skillTree = [];
  
  // Buffs/debuffs
  Map<String, int> activeBuffs = {}; // buff name -> turns remaining

  // Skills
  late List<Skill> skills;

  // Status effects
  List<StatusEffect> playerEffects = [];
  List<StatusEffect> enemyEffects = [];

  // Enemy stats
  late Enemy currentEnemy;
  int enemiesDefeated = 0;
  int bossesDefeated = 0;
  int currentWave = 1;

  // Game state
  bool gameOver = false;
  bool showDifficultyMenu = true;
  bool showClassSelection = false;
  String difficulty = 'medium';
  String message = '';
  bool showMessage = false;
  String gameStatus = 'Welcome to the RPG Adventure!';
  bool inBattle = false;
  bool playerTurn = true;
  bool canAction = true;
  bool isPaused = false;
  int? countdown;
  Timer? countdownTimer;
  bool inExploreBattle = false; // Track if battle started from explore

  // Overworld state
  // 0 = grass, 1 = wall, 2 = water, 3 = town, 4 = forest, 
  // 5 = mountain, 6 = desert, 7 = cave, 8 = beach, 9 = swamp
  late List<List<int>> worldMap;
  int worldWidth = 16;
  int worldHeight = 12;
  Point<int> playerPos = const Point(2, 2);
  Point<int> targetPlayerPos = const Point(2, 2); // Target position for smooth movement
  int playerFacingDirection = 2; // 0=up, 1=right, 2=down, 3=left
  Offset playerVisualOffset = Offset.zero; // Visual offset for smooth animation
  List<Point<int>> npcPositions = [];
  Map<Point<int>, String> npcDialogue = {};
  bool showExploreToast = false;
  DateTime lastStepAt = DateTime.now();
  bool isMoving = false; // Track if player is currently moving
  FocusNode? _mapFocusNode; // Focus node for keyboard input
  
  // Map enemies - visible enemies that walk around
  List<MapEnemy> mapEnemies = [];
  Timer? enemyMovementTimer;

  // NEW: Quest system
  late List<Quest> dailyQuests;
  late List<Quest> activeQuests;

  // NEW: Pet companion
  late PetCompanion playerPet;
  int petHappiness = 100;

  // NEW: Achievements
  late List<Achievement> achievements;
  
  // 3D View toggle
  bool use3DView = true; // Toggle between 2D emojis and 3D models
  bool use3DBattle = true; // Enable 3D battle visualization

  // NEW: Shop & inventory
  List<Equipment> shopInventory = [];
  int totalSpentGold = 0;

  // NEW: Player experience
  int totalGamesPlayed = 0;
  int totalEnemiesDefeated = 0;
  
  // NEW: Save/Load system
  bool autoSaveEnabled = true;
  Timer? autoSaveTimer;
  DateTime? lastSaveTime;
  bool showSaveIndicator = false;
  
  // NEW: Tutorial system
  bool showTutorial = false;
  int tutorialStep = 0;
  List<String> tutorialMessages = [];
  
  // NEW: Performance tracking
  int criticalHitsCount = 0;
  int skillsUsed = 0;
  int healingDone = 0;
  int damageTaken = 0;
  int damageDealt = 0;

  late CombatEngine combatEngine;

  // Difficulty settings
  final Map<String, Map<String, dynamic>> difficultySettings = {
    'easy': {
      'playerHP': 150,
      'playerATK': 15,
      'playerDEF': 8,
      'manaMax': 100,
      'enemyScaling': 0.7,
      'expReward': 1.0,
      'lootChance': 0.4,
    },
    'medium': {
      'playerHP': 100,
      'playerATK': 12,
      'playerDEF': 6,
      'manaMax': 80,
      'enemyScaling': 1.0,
      'expReward': 1.0,
      'lootChance': 0.3,
    },
    'hard': {
      'playerHP': 80,
      'playerATK': 10,
      'playerDEF': 4,
      'manaMax': 60,
      'enemyScaling': 1.3,
      'expReward': 1.5,
      'lootChance': 0.2,
    },
  };

  @override
  void initState() {
    super.initState();
    combatEngine = CombatEngine(seed: DateTime.now().millisecondsSinceEpoch);
    _attackController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _healController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _movementController = AnimationController(
      duration: const Duration(milliseconds: 200), // Smooth movement animation
      vsync: this,
    );
    
    _movementController.addListener(() {
      if (mounted) {
        setState(() {
          // Update visual offset during animation
          final progress = _movementController.value;
          final dx = (targetPlayerPos.x - playerPos.x) * progress;
          final dy = (targetPlayerPos.y - playerPos.y) * progress;
          playerVisualOffset = Offset(dx, dy);
        });
      }
    });
    
    _movementController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Animation complete, update actual position
        setState(() {
          playerPos = targetPlayerPos;
          playerVisualOffset = Offset.zero;
          isMoving = false;
        });
        _movementController.reset();
      }
    });
    
    _mapFocusNode = FocusNode();
    _initializeSkills();
    _initializeSkillTree();
    _initializeQuests();
    _initializePet();
    _initializeAchievements();
    _initializeWorld();
    _initializeTutorial();
    _loadSaveData();
    _startAutoSave();
  }

  void _initializeSkills() {
    skills = [
      Skill(
        name: 'Fireball',
        icon: '🔥',
        manaCost: 40,
        damage: 25,
        effect: 'damage',
        element: ElementType.fire,
        comboBonus: 10,
        unlockLevel: 1,
      ),
      Skill(
        name: 'Heal',
        icon: '💚',
        manaCost: 30,
        heal: 40,
        effect: 'heal',
        unlockLevel: 1,
      ),
      Skill(
        name: 'Poison Strike',
        icon: '☠️',
        manaCost: 35,
        damage: 15,
        effect: 'poison',
        element: ElementType.poison,
        unlockLevel: 2,
      ),
      Skill(
        name: 'Ice Shard',
        icon: '❄️',
        manaCost: 35,
        damage: 22,
        effect: 'damage',
        element: ElementType.ice,
        comboBonus: 8,
        unlockLevel: 2,
      ),
      Skill(
        name: 'Stun Bash',
        icon: '⭐',
        manaCost: 45,
        damage: 20,
        effect: 'stun',
        unlockLevel: 3,
      ),
      Skill(
        name: 'Shield Spell',
        icon: '🛡️',
        manaCost: 25,
        effect: 'shield',
        unlockLevel: 1,
      ),
      Skill(
        name: 'Lightning Bolt',
        icon: '⚡',
        manaCost: 50,
        damage: 35,
        effect: 'damage',
        element: ElementType.lightning,
        comboBonus: 15,
        unlockLevel: 4,
      ),
      Skill(
        name: 'Meteor Storm',
        icon: '☄️',
        manaCost: 60,
        damage: 40,
        effect: 'damage',
        element: ElementType.fire,
        comboBonus: 20,
        unlockLevel: 5,
        isUltimate: true,
      ),
      Skill(
        name: 'Revive',
        icon: '✨',
        manaCost: 80,
        heal: 100,
        effect: 'heal',
        unlockLevel: 6,
      ),
      Skill(
        name: 'Holy Smite',
        icon: '✨',
        manaCost: 55,
        damage: 30,
        effect: 'damage',
        element: ElementType.holy,
        unlockLevel: 4,
      ),
      Skill(
        name: 'Berserker Rage',
        icon: '💪',
        manaCost: 50,
        effect: 'buff',
        buffType: 'attack',
        unlockLevel: 5,
      ),
      Skill(
        name: 'Dodge',
        icon: '💨',
        manaCost: 15,
        effect: 'buff',
        buffType: 'dodge',
        unlockLevel: 3,
      ),
      Skill(
        name: 'Flame Strike',
        icon: '🔥',
        manaCost: 45,
        damage: 30,
        effect: 'damage',
        element: ElementType.fire,
        comboBonus: 12,
        unlockLevel: 3,
      ),
      Skill(
        name: 'Frost Nova',
        icon: '❄️',
        manaCost: 40,
        damage: 25,
        effect: 'damage',
        element: ElementType.ice,
        unlockLevel: 3,
      ),
      Skill(
        name: 'Chain Lightning',
        icon: '⚡',
        manaCost: 55,
        damage: 32,
        effect: 'damage',
        element: ElementType.lightning,
        comboBonus: 18,
        unlockLevel: 5,
      ),
      Skill(
        name: 'Venom Strike',
        icon: '☠️',
        manaCost: 38,
        damage: 18,
        effect: 'poison',
        element: ElementType.poison,
        unlockLevel: 4,
      ),
      Skill(
        name: 'Divine Heal',
        icon: '✨',
        manaCost: 45,
        heal: 50,
        effect: 'heal',
        element: ElementType.holy,
        unlockLevel: 3,
      ),
    ];
  }
  
  void _initializeSkillTree() {
    skillTree = [
      SkillTreeNode(
        id: 'warrior_strength',
        name: 'Mighty Strike',
        description: '+10% attack damage',
        icon: '⚔️',
        unlockLevel: 3,
      ),
      SkillTreeNode(
        id: 'warrior_defense',
        name: 'Fortress',
        description: '+15% defense',
        icon: '🛡️',
        unlockLevel: 4,
      ),
      SkillTreeNode(
        id: 'mage_arcane',
        name: 'Arcane Mastery',
        description: '+20% spell damage',
        icon: '🔮',
        unlockLevel: 3,
      ),
      SkillTreeNode(
        id: 'rogue_stealth',
        name: 'Shadow Step',
        description: '+15% critical chance',
        icon: '🌑',
        unlockLevel: 3,
      ),
      SkillTreeNode(
        id: 'paladin_holy',
        name: 'Divine Protection',
        description: '+20% healing effectiveness',
        icon: '✨',
        unlockLevel: 3,
      ),
    ];
  }

  void _initializeQuests() {
    dailyQuests = [
      Quest(
        id: 'q1',
        name: 'Beast Slayer',
        description: 'Defeat 5 enemies',
        icon: '⚔️',
        targetValue: 5,
        goldReward: 100,
        expReward: 50,
      ),
      Quest(
        id: 'q2',
        name: 'Boss Hunter',
        description: 'Defeat 1 boss',
        icon: '👑',
        targetValue: 1,
        goldReward: 200,
        expReward: 100,
      ),
      Quest(
        id: 'q3',
        name: 'Spell Master',
        description: 'Use skills 10 times',
        icon: '✨',
        targetValue: 10,
        goldReward: 75,
        expReward: 40,
      ),
      Quest(
        id: 'q4',
        name: 'Survivor',
        description: 'Reach wave 10',
        icon: '🌊',
        targetValue: 10,
        goldReward: 150,
        expReward: 75,
      ),
    ];
    activeQuests = List.from(dailyQuests);
  }

  void _initializePet() {
    const petNames = ['Ember', 'Frost', 'Zephyr', 'Terra', 'Nova', 'Shadow'];
    const petEmojis = ['🐉', '🦊', '🦅', '🐺', '✨', '🐾'];
    const petAbilities = ['Fire Breath', 'Ice Shield', 'Wind Strike', 'Earth Shield', 'Light Burst', 'Shadow Claw'];

    final index = combatEngine.roll(petNames.length);

    playerPet = PetCompanion(
      name: petNames[index],
      emoji: petEmojis[index],
      atkBonus: 3,
      defBonus: 2,
      specialAbility: petAbilities[index],
    );
    petHappiness = 100;
  }

  void _initializeAchievements() {
    achievements = [
      Achievement(
        id: 'first-blood',
        name: 'First Blood',
        description: 'Defeat your first enemy',
        icon: '⚔️',
        reward: 50,
      ),
      Achievement(
        id: 'wave-5',
        name: 'Wave Survivor',
        description: 'Reach wave 5',
        icon: '🌊',
        reward: 100,
      ),
      Achievement(
        id: 'boss-slayer',
        name: 'Boss Slayer',
        description: 'Defeat 5 bosses',
        icon: '👑',
        reward: 250,
      ),
      Achievement(
        id: 'critical-master',
        name: 'Critical Master',
        description: 'Land 20 critical hits',
        icon: '⚡',
        reward: 150,
      ),
      Achievement(
        id: 'spell-caster',
        name: 'Spell Caster',
        description: 'Use 50 spells',
        icon: '🔮',
        reward: 100,
      ),
      Achievement(
        id: 'level-10',
        name: 'Legendary Hero',
        description: 'Reach level 10',
        icon: '👸',
        reward: 300,
      ),
      Achievement(
        id: 'pet-bond',
        name: 'Pet Bond',
        description: 'Reach max pet happiness',
        icon: '💕',
        reward: 200,
      ),
      Achievement(
        id: 'treasure-hunter',
        name: 'Treasure Hunter',
        description: 'Collect 10 pieces of equipment',
        icon: '💎',
        reward: 150,
      ),
    ];
  }
  
  void _initializeTutorial() {
    tutorialMessages = [
      '🎮 Welcome to RPG Adventure! Tap anywhere to continue.',
      '⚔️ Use the arrow keys or buttons to move around the map.',
      '👾 Walk into enemies on the map to start a battle!',
      '💥 In battle, you can Attack, Defend, or use Skills.',
      '✨ Skills require Mana (MP) and have special effects.',
      '🛡️ Defend to increase your block chance for the next turn.',
      '🐾 Your pet companion fights alongside you!',
      '📜 Complete quests to earn rewards and level up faster.',
      '🏪 Visit the town (orange area) to buy equipment.',
      '🎯 Good luck, hero! The world needs you!',
    ];
  }
  
  // ========== SAVE/LOAD SYSTEM ==========
  
  Future<void> _saveGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final saveData = {
        'playerLevel': playerLevel,
        'playerHP': playerHP,
        'playerMaxHP': playerMaxHP,
        'playerATK': playerATK,
        'playerDEF': playerDEF,
        'playerGold': playerGold,
        'playerExp': playerExp,
        'manaPoints': manaPoints,
        'maxMana': maxMana,
        'playerClass': playerClass.toString(),
        'difficulty': difficulty,
        'enemiesDefeated': enemiesDefeated,
        'bossesDefeated': bossesDefeated,
        'currentWave': currentWave,
        'skillPoints': skillPoints,
        'petLevel': playerPet.level,
        'petHappiness': petHappiness,
        'totalGamesPlayed': totalGamesPlayed,
        'totalEnemiesDefeated': totalEnemiesDefeated,
        'criticalHitsCount': criticalHitsCount,
        'skillsUsed': skillsUsed,
        'equipment': equipment.map((e) => {
          'name': e.name,
          'rarity': e.rarity,
          'slot': e.slot,
          'atkBonus': e.atkBonus,
          'defBonus': e.defBonus,
          'hpBonus': e.hpBonus,
        }).toList(),
        'achievements': achievements.where((a) => a.unlocked).map((a) => a.id).toList(),
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      await prefs.setString('rpg_save_data', jsonEncode(saveData));
      
      setState(() {
        lastSaveTime = DateTime.now();
        showSaveIndicator = true;
      });
      
      // Hide save indicator after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            showSaveIndicator = false;
          });
        }
      });
    } catch (e) {
      AppLogger().error('Failed to save game: $e');
    }
  }
  
  Future<void> _loadSaveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saveDataString = prefs.getString('rpg_save_data');
      
      if (saveDataString == null) {
        // Check if first time playing - show tutorial
        final hasPlayedBefore = prefs.getBool('rpg_has_played') ?? false;
        if (!hasPlayedBefore) {
          setState(() {
            showTutorial = true;
          });
        }
        return;
      }
      
      final saveData = jsonDecode(saveDataString) as Map<String, dynamic>;
      
      // Ask user if they want to load save
      if (mounted) {
        final shouldLoad = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Load Saved Game?'),
            content: Text('Found a saved game from ${_formatDateTime(saveData['timestamp'])}.\nLoad this save?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('New Game'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Load Save'),
              ),
            ],
          ),
        );
        
        if (shouldLoad == true) {
          _applySaveData(saveData);
        }
      }
    } catch (e) {
      AppLogger().error('Failed to load save data: $e');
    }
  }
  
  void _applySaveData(Map<String, dynamic> saveData) {
    setState(() {
      playerLevel = saveData['playerLevel'] ?? 1;
      playerHP = saveData['playerHP'] ?? 100;
      playerMaxHP = saveData['playerMaxHP'] ?? 100;
      playerATK = saveData['playerATK'] ?? 12;
      playerDEF = saveData['playerDEF'] ?? 6;
      playerGold = saveData['playerGold'] ?? 0;
      playerExp = saveData['playerExp'] ?? 0;
      manaPoints = saveData['manaPoints'] ?? 80;
      maxMana = saveData['maxMana'] ?? 80;
      enemiesDefeated = saveData['enemiesDefeated'] ?? 0;
      bossesDefeated = saveData['bossesDefeated'] ?? 0;
      currentWave = saveData['currentWave'] ?? 1;
      skillPoints = saveData['skillPoints'] ?? 0;
      petHappiness = saveData['petHappiness'] ?? 100;
      playerPet.level = saveData['petLevel'] ?? 1;
      totalGamesPlayed = saveData['totalGamesPlayed'] ?? 0;
      totalEnemiesDefeated = saveData['totalEnemiesDefeated'] ?? 0;
      criticalHitsCount = saveData['criticalHitsCount'] ?? 0;
      skillsUsed = saveData['skillsUsed'] ?? 0;
      
      // Unlock achievements
      final unlockedAchievements = (saveData['achievements'] as List<dynamic>? ?? []).cast<String>();
      for (final id in unlockedAchievements) {
        final achievement = achievements.firstWhere((a) => a.id == id, orElse: () => achievements.first);
        achievement.unlocked = true;
      }
      
      showDifficultyMenu = false;
      showClassSelection = false;
    });
  }
  
  void _startAutoSave() {
    if (!autoSaveEnabled) return;
    
    autoSaveTimer?.cancel();
    autoSaveTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (!gameOver && !showDifficultyMenu && !showClassSelection && playerLevel > 1) {
        _saveGame();
      }
    });
  }
  
  String _formatDateTime(String? isoString) {
    if (isoString == null) return 'Unknown';
    try {
      final dateTime = DateTime.parse(isoString);
      final now = DateTime.now();
      final diff = now.difference(dateTime);
      
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (e) {
      return 'Unknown';
    }
  }

  void _startGame(String selectedDifficulty) {
    setState(() {
      showDifficultyMenu = false;
      showClassSelection = true;
      difficulty = selectedDifficulty;
    });
  }

  void _selectClass(CharacterClass selectedClass) {
    setState(() {
      playerClass = selectedClass;
      showClassSelection = false;
    });
    _startCountdown();
  }

  void _initializeGame() {
    final settings = difficultySettings[difficulty]!;
    playerHP = settings['playerHP'] as int;
    playerMaxHP = playerHP;
    playerATK = settings['playerATK'] as int;
    playerDEF = settings['playerDEF'] as int;
    maxMana = settings['manaMax'] as int;
    manaPoints = maxMana;

    // Class bonuses
    if (playerClass == CharacterClass.warrior) {
      playerHP = (playerHP * 1.2).toInt();
      playerMaxHP = playerHP;
      playerATK = (playerATK * 1.1).toInt();
    } else if (playerClass == CharacterClass.mage) {
      maxMana = (maxMana * 1.3).toInt();
      manaPoints = maxMana;
    } else if (playerClass == CharacterClass.paladin) {
      playerHP = (playerHP * 1.15).toInt();
      playerMaxHP = playerHP;
      playerDEF = (playerDEF * 1.15).toInt();
    }

    playerLevel = 1;
    playerExp = 0;
    playerExpToLevel = 100;
    playerGold = 0;
    enemiesDefeated = 0;
    bossesDefeated = 0;
    currentWave = 1;
    comboCounter = 0;
    streak = 0;
    gameOver = false;
    inBattle = false;
    playerTurn = true;
    canAction = true;
    message = '';
    showMessage = false;
    inExploreBattle = false;
    equipment = [];
    equippedWeapon = null;
    equippedArmor = null;
    playerEffects = [];
    enemyEffects = [];
    damageNumbers = [];
    combatLog = [];

    // NEW: Reset quests and pet
    activeQuests = List.from(dailyQuests);
    for (var q in activeQuests) {
      q.progress = 0;
      q.completed = false;
    }
    playerPet.hp = playerPet.maxHp;
    petHappiness = 100;
    totalGamesPlayed++;
    // Battles now only happen in explore mode via encounters
    // Reset overworld
    _initializeWorld(resetOnly: true);
  }

  void _startCountdown() {
    countdownTimer?.cancel();
    setState(() {
      countdown = 3;
      isPaused = false;
      gameOver = false;
      showMessage = false;
    });
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        countdown = (countdown ?? 1) - 1;
      });
      if ((countdown ?? 0) <= 0) {
        timer.cancel();
        setState(() {
          countdown = null;
        });
        _initializeGame();
      }
    });
  }

  void _spawnEnemy() {
    bool isBoss = currentWave > 1 && currentWave % 5 == 0;
    final biome = _getBiomeAt(playerPos.x, playerPos.y);
    currentEnemy = Enemy.random(
      difficulty: difficulty,
      isBoss: isBoss,
      playerLevel: playerLevel,
      biome: biome,
    );
    inBattle = true;
    inExploreBattle = true; // All battles now happen in explore mode
    playerTurn = true;
    canAction = true; // ✅ FIX: Reset action flag so buttons are enabled
    enemyEffects = [];
    setState(() {
      gameStatus = 'Wave $currentWave: A wild ${currentEnemy.name} appeared!';
    });
  }

  /// Calculate elemental damage multiplier
  double _getElementalMultiplier(ElementType attackElement, ElementType targetWeakness, ElementType targetResistance) {
    if (attackElement == ElementType.none) return 1.0;
    if (attackElement == targetWeakness) return 1.5; // Weakness = 50% bonus
    if (attackElement == targetResistance) return 0.7; // Resistance = 30% reduction
    return 1.0;
  }

  /// Add damage number animation
  void _addDamageNumber(int value, bool isCritical, ElementType? element, bool isPlayer) {
    final color = isCritical 
        ? Colors.orange 
        : (element != null && element != ElementType.none)
            ? _getElementColor(element)
            : Colors.red;
    
    final position = Offset(
      MediaQuery.of(context).size.width * (isPlayer ? 0.3 : 0.7),
      MediaQuery.of(context).size.height * 0.3,
    );

    final damageNumber = DamageNumber(
      value: value,
      color: color,
      isCritical: isCritical,
      element: element,
      position: position,
      timestamp: DateTime.now(),
    );

    setState(() {
      damageNumbers.add(damageNumber);
    });

    // Remove after animation (match new animation duration)
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() {
          damageNumbers.remove(damageNumber);
        });
      }
    });
  }

  Color _getElementColor(ElementType element) {
    switch (element) {
      case ElementType.fire:
        return Colors.red;
      case ElementType.ice:
        return Colors.lightBlue;
      case ElementType.lightning:
        return Colors.yellow;
      case ElementType.poison:
        return Colors.green.shade700;
      case ElementType.holy:
        return Colors.yellow.shade100;
      case ElementType.dark:
        return Colors.purple.shade900;
      default:
        return Colors.red;
    }
  }

  void _playerAttack() {
    if (!canAction || !playerTurn || !inBattle || isPaused || countdown != null) {
      return;
    }

    canAction = false;
    playerTurn = false;
    isDefending = false; // Reset defense after action

    // Check for stun effect
    if (_hasEffect(playerEffects, 'Stun')) {
      setState(() {
        message = '😵 You are stunned!';
        showMessage = true;
        combatLog.add('You are stunned!');
      });
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          _enemyTurn();
        }
      });
      return;
    }

    // Calculate damage with equipment bonuses and pet bonus
    int equipmentBonus = (equippedWeapon?.getTotalAtkBonus() ?? 0);
    int petBonus = playerPet.isAlive ? playerPet.atkBonus : 0;
    int baseDamage = playerATK + equipmentBonus + petBonus + combatEngine.roll(5) - 2;
    
    // Class bonuses
    if (playerClass == CharacterClass.warrior) {
      baseDamage = (baseDamage * 1.15).toInt(); // 15% damage bonus
    } else if (playerClass == CharacterClass.rogue) {
      baseDamage = (baseDamage * 1.1).toInt();
      if (combatEngine.rng.nextDouble() < 0.3) baseDamage = (baseDamage * 1.3).toInt(); // 30% chance for extra crit
    }
    
    // Apply buffs
    if (activeBuffs.containsKey('attack')) {
      baseDamage = (baseDamage * 1.2).toInt(); // +20% attack buff
    }

    // Elemental damage from weapon
    ElementType weaponElement = equippedWeapon?.element ?? ElementType.none;
    double elementalMultiplier = _getElementalMultiplier(
      weaponElement,
      currentEnemy.weakness,
      currentEnemy.resistance,
    );
    
    int actualDamage = max(1, (baseDamage * elementalMultiplier).toInt() - (currentEnemy.def ~/ 2));

    // Combo system
    bool isCritical = combatEngine.roll(100) < (15 + streak * 2 + comboCounter * 3);
    if (isCritical) {
      actualDamage = (actualDamage * 1.5).toInt();
      streak++;
      comboCounter++;
      criticalHitsCount++; // Track critical hits
    } else {
      streak = 0;
      comboCounter = max(0, comboCounter - 1);
    }
    
    // Track damage dealt
    damageDealt += actualDamage;
    
    // Pet ability chance (10% chance per turn)
    if (playerPet.isAlive && playerPet.abilityCooldown == 0 && combatEngine.rng.nextDouble() < 0.1) {
      _usePetAbility();
    }

    // Apply damage
    setState(() {
      currentEnemy.hp -= actualDamage;
      message = isCritical
          ? '⚔️ CRITICAL HIT! $actualDamage damage! (Combo: $comboCounter)'
          : '⚔️ Attack! $actualDamage damage!';
      showMessage = true;
      combatLog.add(message);
      if (combatLog.length > 10) combatLog.removeAt(0);
    });

    // Add damage number animation
    _addDamageNumber(actualDamage, isCritical, weaponElement, false);

    if (GameSettings.hapticsEnabled) {
      if (isCritical) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    }

    _attackController.forward(from: 0);

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        _enemyTurn();
      }
    });
  }
  
  void _usePetAbility() {
    if (!playerPet.isAlive || playerPet.specialAbility == null) return;
    
    playerPet.abilityCooldown = 3; // 3 turn cooldown
    
    switch (playerPet.specialAbility) {
      case 'Fire Breath':
        int petDamage = (playerPet.atkBonus * 2).toInt() + combatEngine.roll(5);
        currentEnemy.hp -= petDamage;
        setState(() {
          message += '\n${playerPet.emoji} ${playerPet.name} uses Fire Breath! $petDamage damage!';
          combatLog.add('${playerPet.name} uses Fire Breath!');
        });
        _addDamageNumber(petDamage, false, ElementType.fire, false);
        break;
      case 'Ice Shield':
        playerEffects.add(StatusEffect(name: 'Ice Shield', emoji: '❄️', duration: 2));
        setState(() {
          message += '\n${playerPet.emoji} ${playerPet.name} casts Ice Shield!';
          combatLog.add('${playerPet.name} casts Ice Shield!');
        });
        break;
      case 'Wind Strike':
        int petDamage = playerPet.atkBonus + combatEngine.roll(8);
        currentEnemy.hp -= petDamage;
        setState(() {
          message += '\n${playerPet.emoji} ${playerPet.name} uses Wind Strike! $petDamage damage!';
          combatLog.add('${playerPet.name} uses Wind Strike!');
        });
        _addDamageNumber(petDamage, false, null, false);
        break;
      case 'Earth Shield':
        playerDEF += 5;
        setState(() {
          message += '\n${playerPet.emoji} ${playerPet.name} boosts your defense! +5 DEF!';
          combatLog.add('${playerPet.name} boosts defense!');
        });
        break;
      case 'Light Burst':
        int healAmount = 15 + playerPet.level;
        playerHP = min(playerHP + healAmount, playerMaxHP);
        setState(() {
          message += '\n${playerPet.emoji} ${playerPet.name} heals you for $healAmount HP!';
          combatLog.add('${playerPet.name} heals you!');
        });
        _addDamageNumber(healAmount, false, null, true);
        break;
      case 'Shadow Claw':
        int petDamage = (playerPet.atkBonus * 1.5).toInt() + combatEngine.roll(10);
        currentEnemy.hp -= petDamage;
        enemyEffects.add(StatusEffect(name: 'Bleeding', emoji: '🩸', duration: 2));
        setState(() {
          message += '\n${playerPet.emoji} ${playerPet.name} uses Shadow Claw! $petDamage damage + bleeding!';
          combatLog.add('${playerPet.name} uses Shadow Claw!');
        });
        _addDamageNumber(petDamage, false, ElementType.dark, false);
        break;
    }
  }
  
  void _playerDefend() {
    if (!canAction || !playerTurn || !inBattle || isPaused || countdown != null) {
      return;
    }
    
    setState(() {
      isDefending = true;
      blockChance = 25; // Increased block chance when defending
      message = '🛡️ You take a defensive stance!';
      showMessage = true;
      combatLog.add('You defend!');
      canAction = false;
      playerTurn = false;
    });
    
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        _enemyTurn();
      }
    });
  }

  void _playerUseSkill(Skill skill) {
    if (!canAction || !playerTurn || !inBattle || isPaused || countdown != null) {
      return;
    }
    
    // Check if skill is unlocked
    if (skill.unlockLevel > playerLevel) {
      setState(() {
        message = '🔒 Skill locked! Reach level ${skill.unlockLevel} to unlock.';
        showMessage = true;
      });
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          setState(() {
            showMessage = false;
          });
        }
      });
      return;
    }
    
    if (manaPoints < skill.manaCost) {
      setState(() {
        message = '💫 Not enough mana! (Need ${skill.manaCost})';
        showMessage = true;
      });
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          setState(() {
            showMessage = false;
          });
        }
      });
      return;
    }

    canAction = false;
    playerTurn = false;
    isDefending = false;
    manaPoints -= skill.manaCost;
    skill.cooldown = skill.isUltimate ? 5 : 2; // Ultimates have longer cooldown
    skillsUsed++; // Track skill usage

    setState(() {
      if (skill.effect == 'heal') {
        int healAmount = skill.heal;
        // Class bonuses for healing
        if (playerClass == CharacterClass.paladin) {
          healAmount = (healAmount * 1.2).toInt();
        }
        playerHP = min(playerHP + healAmount, playerMaxHP);
        healingDone += healAmount; // Track healing
        message = '💚 ${skill.name}! Healed $healAmount HP!';
        comboCounter = 0;
        streak = 0;
        _addDamageNumber(healAmount, false, null, true);
        if (GameSettings.hapticsEnabled) HapticFeedback.selectionClick();
      } else if (skill.effect == 'poison') {
        int baseDamage = skill.damage + combatEngine.roll(10);
        // Elemental multiplier
        double elementalMultiplier = _getElementalMultiplier(
          skill.element,
          currentEnemy.weakness,
          currentEnemy.resistance,
        );
        int damage = (baseDamage * elementalMultiplier).toInt();
        // Combo bonus
        if (comboCounter > 0 && skill.comboBonus != null) {
          damage += skill.comboBonus!;
        }
        currentEnemy.hp -= damage;
        enemyEffects
            .add(StatusEffect(name: 'Poison', emoji: '☠️', duration: 3));
        message = '☠️ ${skill.name}! $damage damage + poison!';
        comboCounter++;
        _addDamageNumber(damage, false, skill.element, false);
        if (GameSettings.hapticsEnabled) HapticFeedback.lightImpact();
      } else if (skill.effect == 'stun') {
        int baseDamage = skill.damage + combatEngine.roll(10);
        double elementalMultiplier = _getElementalMultiplier(
          skill.element,
          currentEnemy.weakness,
          currentEnemy.resistance,
        );
        int damage = (baseDamage * elementalMultiplier).toInt();
        if (comboCounter > 0 && skill.comboBonus != null) {
          damage += skill.comboBonus!;
        }
        currentEnemy.hp -= damage;
        enemyEffects.add(StatusEffect(name: 'Stun', emoji: '⭐', duration: 1));
        message = '⭐ ${skill.name}! $damage damage + stun!';
        comboCounter++;
        _addDamageNumber(damage, false, skill.element, false);
        if (GameSettings.hapticsEnabled) HapticFeedback.mediumImpact();
      } else if (skill.effect == 'shield') {
        playerEffects
            .add(StatusEffect(name: 'Shield', emoji: '🛡️', duration: 2));
        message = '🛡️ ${skill.name}! Protected for 2 turns!';
        comboCounter = 0;
        streak = 0;
        if (GameSettings.hapticsEnabled) HapticFeedback.selectionClick();
      } else if (skill.effect == 'buff') {
        if (skill.buffType == 'attack') {
          activeBuffs['attack'] = 3; // 3 turns
          message = '💪 ${skill.name}! +20% attack for 3 turns!';
        } else if (skill.buffType == 'dodge') {
          activeBuffs['dodge'] = 2; // 2 turns
          dodgeChance = 30; // Increased dodge chance
          message = '💨 ${skill.name}! Increased dodge chance!';
        }
        comboCounter = 0;
        streak = 0;
        if (GameSettings.hapticsEnabled) HapticFeedback.lightImpact();
      } else {
        // Damage skill
        int baseDamage = skill.damage + combatEngine.roll(15);
        // Mage class bonus
        if (playerClass == CharacterClass.mage && skill.element != ElementType.none) {
          baseDamage = (baseDamage * 1.2).toInt();
        }
        // Elemental multiplier
        double elementalMultiplier = _getElementalMultiplier(
          skill.element,
          currentEnemy.weakness,
          currentEnemy.resistance,
        );
        int damage = (baseDamage * elementalMultiplier).toInt();
        // Combo bonus
        if (comboCounter > 0 && skill.comboBonus != null) {
          damage += skill.comboBonus!;
          message = '${skill.icon} ${skill.name}! $damage damage! (Combo +${skill.comboBonus}!)';
        } else {
          message = '${skill.icon} ${skill.name}! $damage damage!';
        }
        currentEnemy.hp -= damage;
        comboCounter++;
        _addDamageNumber(damage, false, skill.element, false);
        if (GameSettings.hapticsEnabled) HapticFeedback.lightImpact();
      }
      showMessage = true;
      combatLog.add(message);
      if (combatLog.length > 10) combatLog.removeAt(0);
    });

    _attackController.forward(from: 0);

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        _enemyTurn();
      }
    });
  }

  bool _hasEffect(List<StatusEffect> effects, String name) {
    return effects.any((e) => e.name == name && e.remainingTurns > 0);
  }

  void _enemyTurn() {
    if (isPaused) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && !isPaused) _enemyTurn();
      });
      return;
    }
    
    // Reduce cooldowns and apply damage over time effects
    for (var effect in enemyEffects) {
      if (effect.name == 'Poison' && effect.remainingTurns > 0) {
        int poisonDamage = 5 + (playerLevel ~/ 2);
        currentEnemy.hp -= poisonDamage;
      }
      if (effect.name == 'Bleeding' && effect.remainingTurns > 0) {
        int bleedDamage = 3 + (playerLevel ~/ 3);
        currentEnemy.hp -= bleedDamage;
      }
    }

    for (var effect in playerEffects) {
      if (effect.name == 'Poison' && effect.remainingTurns > 0) {
        int poisonDamage = 3 + (playerLevel ~/ 2);
        playerHP -= poisonDamage;
      }
      effect.remainingTurns--;
    }

    for (var effect in enemyEffects) {
      effect.remainingTurns--;
    }
    
    // Reduce pet ability cooldown
    if (playerPet.abilityCooldown > 0) {
      playerPet.abilityCooldown--;
    }

    // Reduce skill cooldowns
    for (var skill in skills) {
      if (skill.cooldown > 0) {
        skill.cooldown--;
      }
    }
    
    // Reduce buff durations
    activeBuffs.forEach((key, value) {
      if (value > 0) {
        activeBuffs[key] = value - 1;
      } else {
        activeBuffs.remove(key);
      }
    });
    
    // Reset dodge chance if buff expired
    if (!activeBuffs.containsKey('dodge')) {
      dodgeChance = 5;
    }
    
    // Reset block chance if not defending
    if (!isDefending) {
      blockChance = 8;
    }

    // Check if enemy is defeated
    if (currentEnemy.hp <= 0) {
      _defeatEnemy();
      return;
    }

    // Check if enemy is stunned
    if (_hasEffect(enemyEffects, 'Stun')) {
      setState(() {
        message = '⭐ ${currentEnemy.name} is stunned!';
        showMessage = true;
      });
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          setState(() {
            showMessage = false;
          });
          playerTurn = true;
          canAction = true;
        }
      });
      return;
    }

    // Enemy action with special abilities
    int action = combatEngine.roll(100);
    int damage = 0;
    
    // Check for dodge/parry/block before calculating damage
    bool dodged = false;
    bool parried = false;
    bool blocked = false;
    
    if (combatEngine.roll(100) < dodgeChance) {
      dodged = true;
      setState(() {
        message = '💨 You dodged the attack!';
        combatLog.add('You dodged!');
      });
    } else if (combatEngine.roll(100) < parryChance && equippedWeapon != null) {
      parried = true;
      // Counter-attack on parry
      int counterDamage = (playerATK * 0.5).toInt();
      currentEnemy.hp -= counterDamage;
      setState(() {
        message = '⚔️ You parried and counter-attacked! $counterDamage damage!';
        combatLog.add('You parried!');
      });
      _addDamageNumber(counterDamage, false, null, false);
    } else if (combatEngine.roll(100) < blockChance || isDefending) {
      blocked = true;
      setState(() {
        message = '🛡️ You blocked the attack!';
        combatLog.add('You blocked!');
      });
    }

    if (dodged || blocked || parried) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          setState(() {
            showMessage = false;
          });
          
          // Restore mana gradually
          if (manaPoints < maxMana) {
            manaPoints = min(manaPoints + 15, maxMana);
          }
          
          playerTurn = true;
          canAction = true;
        }
      });
      return;
    }

    // Boss special abilities
    if (currentEnemy.isBoss && currentEnemy.specialAbility != null) {
      if (currentEnemy.specialAbilityCharges <= 0 && currentEnemy.hp < currentEnemy.maxHp * 0.5) {
        // Use special ability
        currentEnemy.specialAbilityCharges = 3; // Cooldown
        
        if (currentEnemy.specialAbility == 'Fire Breath') {
          damage = (currentEnemy.atk * 1.5).toInt() + combatEngine.roll(10);
          int playerShield = _hasEffect(playerEffects, 'Shield') ? 5 : 0;
          int petBonus = playerPet.isAlive ? playerPet.defBonus : 0;
          damage = max(1, damage - (playerDEF ~/ 3) - playerShield - petBonus);
          playerEffects.add(StatusEffect(name: 'Burning', emoji: '🔥', duration: 2));
          setState(() {
            message = '🔥 ${currentEnemy.name} uses Fire Breath! $damage damage + burning!';
          });
        } else if (currentEnemy.specialAbility == 'Shadow Strike') {
          damage = (currentEnemy.atk * 1.3).toInt();
          int playerShield = _hasEffect(playerEffects, 'Shield') ? 5 : 0;
          int petBonus = playerPet.isAlive ? playerPet.defBonus : 0;
          damage = max(1, damage - (playerDEF ~/ 4) - playerShield - petBonus);
          setState(() {
            message = '🌑 ${currentEnemy.name} uses Shadow Strike! $damage damage!';
          });
        } else if (currentEnemy.specialAbility == 'Tidal Wave') {
          damage = (currentEnemy.atk * 1.2).toInt();
          int playerShield = _hasEffect(playerEffects, 'Shield') ? 5 : 0;
          int petBonus = playerPet.isAlive ? playerPet.defBonus : 0;
          damage = max(1, damage - (playerDEF ~/ 3) - playerShield - petBonus);
          playerEffects.add(StatusEffect(name: 'Slowed', emoji: '💧', duration: 2));
          setState(() {
            message = '💧 ${currentEnemy.name} uses Tidal Wave! $damage damage + slowed!';
          });
        } else if (currentEnemy.specialAbility == 'Bone Shield') {
          currentEnemy.def += 5;
          setState(() {
            message = '🛡️ ${currentEnemy.name} raises Bone Shield! +5 DEF!';
          });
          damage = 0;
        } else if (currentEnemy.specialAbility == 'Stone Armor') {
          currentEnemy.def += 8;
          setState(() {
            message = '🗿 ${currentEnemy.name} activates Stone Armor! +8 DEF!';
          });
          damage = 0;
        } else if (currentEnemy.specialAbility == 'Regeneration') {
          int heal = (currentEnemy.maxHp * 0.25).toInt();
          currentEnemy.hp = min(currentEnemy.hp + heal, currentEnemy.maxHp);
          setState(() {
            message = '💚 ${currentEnemy.name} regenerates $heal HP!';
          });
          damage = 0;
        } else if (currentEnemy.specialAbility == 'Divine Strike') {
          damage = (currentEnemy.atk * 1.6).toInt() + combatEngine.roll(10);
          int playerShield = _hasEffect(playerEffects, 'Shield') ? 5 : 0;
          int petBonus = playerPet.isAlive ? playerPet.defBonus : 0;
          damage = max(1, damage - (playerDEF ~/ 4) - playerShield - petBonus);
          setState(() {
            message = '✨ ${currentEnemy.name} uses Divine Strike! $damage damage!';
          });
        } else if (currentEnemy.specialAbility == 'Hellfire') {
          damage = (currentEnemy.atk * 1.7).toInt() + combatEngine.roll(12);
          int playerShield = _hasEffect(playerEffects, 'Shield') ? 5 : 0;
          int petBonus = playerPet.isAlive ? playerPet.defBonus : 0;
          damage = max(1, damage - (playerDEF ~/ 3) - playerShield - petBonus);
          playerEffects.add(StatusEffect(name: 'Burning', emoji: '🔥', duration: 3));
          setState(() {
            message = '🔥 ${currentEnemy.name} unleashes Hellfire! $damage damage + severe burning!';
          });
        }
      } else {
        if (currentEnemy.specialAbilityCharges > 0) {
          currentEnemy.specialAbilityCharges--;
        }
      }
    }

    if (damage == 0) {
      if (action < 60) {
        // Regular attack
        damage = currentEnemy.atk + combatEngine.roll(5) - 2;
        int playerShield = _hasEffect(playerEffects, 'Shield') ? 5 : 0;
        int petBonus = playerPet.isAlive ? playerPet.defBonus : 0;
        damage = max(1, damage - (playerDEF ~/ 2) - playerShield - petBonus);
        setState(() {
          message = '💥 ${currentEnemy.name} attacks! $damage damage!';
        });
      } else if (action < 80 && currentEnemy.hp < currentEnemy.maxHp * 0.3) {
        // Enemy heals
        int heal = (currentEnemy.maxHp * 0.3).toInt();
        currentEnemy.hp = min(currentEnemy.hp + heal, currentEnemy.maxHp);
        setState(() {
          message = '💚 ${currentEnemy.name} heals $heal HP!';
        });
        damage = 0;
      } else {
        // Powerful attack
        damage = (currentEnemy.atk * 1.3).toInt() + combatEngine.roll(5);
        int playerShield = _hasEffect(playerEffects, 'Shield') ? 5 : 0;
        int petBonus = playerPet.isAlive ? playerPet.defBonus : 0;
        damage = max(1, damage - (playerDEF ~/ 3) - playerShield - petBonus);
        setState(() {
          message =
              '⚡ ${currentEnemy.name} uses a powerful attack! $damage damage!';
        });
      }
    }

    setState(() {
      playerHP -= damage;
      damageTaken += damage; // Track damage taken
      showMessage = true;
      combatLog.add(message);
      if (combatLog.length > 10) combatLog.removeAt(0);
    });
    
    if (damage > 0) {
      _addDamageNumber(damage, false, currentEnemy.element, true);
      if (GameSettings.hapticsEnabled) HapticFeedback.lightImpact();
    }

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          showMessage = false;
        });

        // Restore mana gradually
        if (manaPoints < maxMana) {
          manaPoints = min(manaPoints + 15, maxMana);
        }

        if (playerHP <= 0) {
          _endGame();
        } else {
          playerTurn = true;
          canAction = true;
        }
      }
    });
  }

  void _defeatEnemy() {
    int expGain = (100 * difficultySettings[difficulty]!['expReward']).toInt() +
        (currentWave * 10); // More exp for higher waves
    int goldGain = (50 * combatEngine.rng.nextDouble() + 30).toInt() + (currentWave * 5);

    playerExp += expGain;
    playerGold += goldGain;
    enemiesDefeated++;
    totalEnemiesDefeated++;
    currentWave++;

    if (currentEnemy.isBoss) {
      bossesDefeated++;
      goldGain = (goldGain * 2).toInt(); // Double gold from bosses
    }

    // NEW: Update pet happiness and track quests
    petHappiness = min(petHappiness + 5, 100);

    // Update quests
    for (var quest in activeQuests) {
      if (quest.completed) continue;

      if (quest.id == 'q1') {
        // Beast Slayer
        quest.progress++;
      } else if (quest.id == 'q2' && currentEnemy.isBoss) {
        // Boss Hunter
        quest.progress++;
      }
    }

    // Check achievements
    if (enemiesDefeated == 1) {
      _unlockAchievement('first-blood');
    }
    if (bossesDefeated >= 5) {
      _unlockAchievement('boss-slayer');
    }
    if (criticalHitsCount >= 20) {
      _unlockAchievement('critical-master');
    }
    if (skillsUsed >= 50) {
      _unlockAchievement('spell-caster');
    }
    if (currentWave >= 5) {
      _unlockAchievement('wave-5');
    }
    if (equipment.length >= 10) {
      _unlockAchievement('treasure-hunter');
    }
    if (petHappiness >= 100) {
      _unlockAchievement('pet-bond');
    }

    // Chance to drop loot
    double lootChance = difficultySettings[difficulty]!['lootChance'] as double;
    if (combatEngine.rng.nextDouble() < lootChance) {
      _generateLoot();
    }

    setState(() {
      message = '🎉 Victory! +$expGain EXP, +$goldGain gold!';
      if (currentEnemy.isBoss) {
        message += '\n👑 Boss defeated!';
      }
      showMessage = true;
      gameStatus = 'Victory! Defeated ${currentEnemy.name}';
    });

    // Check for level up
    while (playerExp >= playerExpToLevel) {
      playerExp -= playerExpToLevel;
      playerLevel++;
      skillPoints++; // Grant skill point on level up
      int hpIncrease = (playerMaxHP * 0.15).toInt();
      playerMaxHP += hpIncrease;
      playerHP = playerMaxHP;
      playerATK = (playerATK * 1.1).toInt();
      playerDEF = (playerDEF * 1.08).toInt();
      maxMana = (maxMana * 1.1).toInt();
      manaPoints = maxMana;
      playerExpToLevel = (playerExpToLevel * 1.15).toInt();

      // Pet levels up too
      playerPet.level++;
      playerPet.maxHp = (playerPet.maxHp * 1.15).toInt();
      playerPet.hp = playerPet.maxHp;
      playerPet.atkBonus = (playerPet.atkBonus * 1.1).toInt();
      playerPet.defBonus = (playerPet.defBonus * 1.1).toInt();
      playerPet.evolve(); // Check for evolution

      setState(() {
        gameStatus = '⭐ LEVEL UP! You are now level $playerLevel! (+1 Skill Point)';
      });

      if (playerLevel == 10) {
        _unlockAchievement('level-10');
      }
    }

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        _checkQuestCompletion();
        
        // All battles now happen in explore mode - return to explore after battle
        setState(() {
          inBattle = false;
          inExploreBattle = false;
          showMessage = false;
          message = '';
        });
        
        // Spawn new enemy on map after battle ends (if map is getting empty)
        if (mapEnemies.length < 3 && !isPaused) {
          _spawnAdditionalEnemy();
        }
      }
    });
  }

  void _checkQuestCompletion() {
    List<Quest> completed = [];
    for (var quest in activeQuests) {
      if (!quest.completed && quest.isCompleted) {
        quest.completed = true;
        completed.add(quest);
        playerGold += quest.goldReward;
        playerExp += quest.expReward;
      }
    }

    if (completed.isNotEmpty) {
      String questNames = completed.map((q) => q.name).join(', ');
      setState(() {
        message =
            '✅ Quest Complete: $questNames!\n+${completed.fold<int>(0, (sum, q) => sum + q.goldReward)} gold!';
        showMessage = true;
      });
    }
  }

  void _unlockAchievement(String id) {
    final achievement = achievements.firstWhere((a) => a.id == id,
        orElse: () => Achievement(
              id: 'none',
              name: 'none',
              description: 'none',
              icon: 'none',
              reward: 0,
            ));

    if (achievement.id != 'none' && !achievement.unlocked) {
      achievement.unlock();
      playerGold += achievement.reward;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '🏆 Achievement Unlocked: ${achievement.name}! +${achievement.reward} gold'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.purple,
          ),
        );
      }
    }
  }

  void _generateLoot() {
    final rarities = ['common', 'rare', 'epic'];
    final rarity = rarities[combatEngine.roll(rarities.length + 1)];

    const weaponNames = [
      'Iron Sword',
      'Steel Blade',
      'Golden Axe',
      'Mystic Staff',
      'Dragon Fang',
      'Holy Mace'
    ];

    const armorNames = [
      'Leather Armor',
      'Iron Plate',
      'Mithril Mail',
      'Dragon Scale',
      'Shadow Cloak',
      'Crystal Armor'
    ];
    
    const ringNames = [
      'Ring of Power',
      'Ring of Defense',
      'Ring of Health',
      'Ring of Mana',
    ];
    
    const amuletNames = [
      'Amulet of Strength',
      'Amulet of Protection',
      'Amulet of Vitality',
    ];

    final slotTypes = ['weapon', 'armor', 'ring', 'amulet'];
    final slot = slotTypes[combatEngine.roll(slotTypes.length)];
    
    String name;
    if (slot == 'weapon') {
      name = weaponNames[combatEngine.roll(weaponNames.length)];
    } else if (slot == 'armor') {
      name = armorNames[combatEngine.roll(armorNames.length)];
    } else if (slot == 'ring') {
      name = ringNames[combatEngine.roll(ringNames.length)];
    } else {
      name = amuletNames[combatEngine.roll(amuletNames.length)];
    }

    int atkBonus = 0;
    int defBonus = 0;
    int hpBonus = 0;

    if (rarity == 'common') {
      if (slot == 'weapon') {
        atkBonus = 2;
      } else if (slot == 'armor') {
        defBonus = 1;
      } else if (slot == 'ring' || slot == 'amulet') {
        atkBonus = 1;
        defBonus = 1;
      }
    } else if (rarity == 'rare') {
      if (slot == 'weapon') {
        atkBonus = 5;
      } else if (slot == 'armor') {
        defBonus = 3;
        hpBonus = 10;
      } else if (slot == 'ring' || slot == 'amulet') {
        atkBonus = 2;
        defBonus = 2;
        hpBonus = 5;
      }
    } else {
      if (slot == 'weapon') {
        atkBonus = 10;
      } else if (slot == 'armor') {
        defBonus = 6;
        hpBonus = 20;
      } else if (slot == 'ring' || slot == 'amulet') {
        atkBonus = 4;
        defBonus = 4;
        hpBonus = 10;
      }
    }

    final loot = Equipment(
      name: name,
      rarity: rarity,
      slot: slot,
      atkBonus: atkBonus,
      defBonus: defBonus,
      hpBonus: hpBonus,
    );

    equipment.add(loot);
    _equipItem(loot);

    setState(() {
      message += '\n${loot.getRarityEmoji()} ${loot.name} dropped!';
    });
  }

  void _equipItem(Equipment item) {
    if (item.slot == 'weapon') {
      if (equippedWeapon != null) {
        playerATK -= equippedWeapon!.getTotalAtkBonus();
      }
      equippedWeapon = item;
      playerATK += item.getTotalAtkBonus();
    } else if (item.slot == 'armor') {
      if (equippedArmor != null) {
        playerDEF -= equippedArmor!.getTotalDefBonus();
        playerMaxHP -= equippedArmor!.getTotalHpBonus();
      }
      equippedArmor = item;
      playerDEF += item.getTotalDefBonus();
      playerMaxHP += item.getTotalHpBonus();
      playerHP = min(playerHP, playerMaxHP);
    } else if (item.slot == 'ring') {
      if (equippedRing != null) {
        playerATK -= equippedRing!.getTotalAtkBonus();
        playerDEF -= equippedRing!.getTotalDefBonus();
        playerMaxHP -= equippedRing!.getTotalHpBonus();
      }
      equippedRing = item;
      playerATK += item.getTotalAtkBonus();
      playerDEF += item.getTotalDefBonus();
      playerMaxHP += item.getTotalHpBonus();
      playerHP = min(playerHP, playerMaxHP);
    } else if (item.slot == 'amulet') {
      if (equippedAmulet != null) {
        playerATK -= equippedAmulet!.getTotalAtkBonus();
        playerDEF -= equippedAmulet!.getTotalDefBonus();
        playerMaxHP -= equippedAmulet!.getTotalHpBonus();
      }
      equippedAmulet = item;
      playerATK += item.getTotalAtkBonus();
      playerDEF += item.getTotalDefBonus();
      playerMaxHP += item.getTotalHpBonus();
      playerHP = min(playerHP, playerMaxHP);
    }
  }

  void _endGame() {
    setState(() {
      gameOver = true;
      gameStatus = 'Game Over! You were defeated!';
    });
    _submitScore();
  }

  Future<void> _submitScore() async {
    try {
      final statistics = {
        'level': playerLevel,
        'enemiesDefeated': enemiesDefeated,
        'bossesDefeated': bossesDefeated,
        'totalGold': playerGold,
        'totalExp': playerExp,
      };

      await GameService.submitScore(
        'rpg-adventure',
        playerGold,
        difficulty,
        statistics: statistics,
      );
    } catch (e) {
      AppLogger().error('Failed to submit RPG score: $e');
    }
  }

  void _resetGame() {
    setState(() {
      showDifficultyMenu = true;
      showClassSelection = false;
      _initializeGame();
    });
  }

  @override
  void dispose() {
    _attackController.dispose();
    _healController.dispose();
    _movementController.dispose();
    _mapFocusNode?.dispose();
    enemyMovementTimer?.cancel();
    autoSaveTimer?.cancel();
    countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('RPG Adventure'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              countdownTimer?.cancel();
              Navigator.pop(context);
            },
          ),
          actions: [
            if (!showDifficultyMenu && !gameOver) ...[
              // Manual save button
              IconButton(
                tooltip: 'Save Game',
                icon: Stack(
                  children: [
                    const Icon(Icons.save),
                    if (showSaveIndicator)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () {
                  _saveGame();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Game saved successfully!'),
                      duration: Duration(seconds: 2),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              ),
              // Tutorial button
              IconButton(
                tooltip: 'Tutorial',
                icon: const Icon(Icons.help_outline),
                onPressed: () => setState(() => showTutorial = true),
              ),
              // Pause/Resume button
              IconButton(
                tooltip: isPaused ? 'Resume' : 'Pause',
                icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
                onPressed: () => setState(() => isPaused = !isPaused),
              ),
            ],
          ],
          bottom: !showDifficultyMenu && !gameOver
              ? const TabBar(
                  tabs: [
                    Tab(text: '🗺 Explore'),
                    Tab(text: '📜 Quests'),
                    Tab(text: '🐉 Pet'),
                  ],
                )
              : null,
        ),
        body: Stack(
          children: [
            showDifficultyMenu
                ? _buildDifficultyMenu()
                : showClassSelection
                    ? _buildClassSelectionMenu()
                    : gameOver
                        ? _buildGameOverScreen()
                        : _buildGameScreen(),
            if (countdown != null && !showDifficultyMenu && !gameOver && !showClassSelection)
              Container(
                color: Colors.black.withValues(alpha: 0.4),
                child: Center(
                  child: Text(
                    '${countdown ?? ''}',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                  ),
                ),
              ),
            if (isPaused && !showDifficultyMenu && !gameOver && !showClassSelection)
              Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pause, size: 64, color: Colors.white),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => setState(() => isPaused = false),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Resume'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Tutorial overlay
            if (showTutorial) _buildTutorialOverlay(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTutorialOverlay() {
    final fontSize = ResponsiveSizing.getFontSize(context,
        small: 14, medium: 16, large: 18, xlarge: 20);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          if (tutorialStep < tutorialMessages.length - 1) {
            tutorialStep++;
          } else {
            showTutorial = false;
            tutorialStep = 0;
            // Mark as played
            SharedPreferences.getInstance().then((prefs) {
              prefs.setBool('rpg_has_played', true);
            });
          }
        });
      },
      child: Container(
        color: Colors.black.withValues(alpha: 0.85),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade900.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.purple.shade300, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        tutorialMessages[tutorialStep],
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${tutorialStep + 1}/${tutorialMessages.length}',
                            style: TextStyle(
                              color: Colors.purple.shade200,
                              fontSize: fontSize * 0.9,
                            ),
                          ),
                          const SizedBox(width: 16),
                          if (tutorialStep == tutorialMessages.length - 1)
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  showTutorial = false;
                                  tutorialStep = 0;
                                });
                                SharedPreferences.getInstance().then((prefs) {
                                  prefs.setBool('rpg_has_played', true);
                                });
                              },
                              icon: const Icon(Icons.check, color: Colors.green),
                              label: Text(
                                'Got it!',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: fontSize,
                                ),
                              ),
                            )
                          else
                            Text(
                              'Tap to continue',
                              style: TextStyle(
                                color: Colors.purple.shade200,
                                fontSize: fontSize * 0.8,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    setState(() {
                      showTutorial = false;
                      tutorialStep = 0;
                    });
                  },
                  child: Text(
                    'Skip Tutorial',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: fontSize * 0.9,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClassSelectionMenu() {
    final padding = ResponsiveSizing.getHorizontalPadding(context);
    final spacing =
        ResponsiveSizing.getSpacing(context, small: 20, medium: 24, large: 32);

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: padding,
                child: Column(
                  children: [
                    Text(
                      'Choose Your Class',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: ResponsiveSizing.getFontSize(context,
                                    small: 24,
                                    medium: 28,
                                    large: 32,
                                    xlarge: 36),
                              ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Each class has unique abilities and bonuses',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                            fontSize: ResponsiveSizing.getFontSize(context,
                                small: 12, medium: 14, large: 16, xlarge: 16),
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              SizedBox(height: spacing),
              _buildClassButton(
                CharacterClass.warrior,
                '⚔️ Warrior',
                'High HP & Attack\n+15% damage bonus',
                Colors.red,
              ),
              const SizedBox(height: 10),
              _buildClassButton(
                CharacterClass.mage,
                '🔮 Mage',
                'High Mana & Spell Power\n+20% elemental damage',
                Colors.purple,
              ),
              const SizedBox(height: 10),
              _buildClassButton(
                CharacterClass.rogue,
                '🗡️ Rogue',
                'High Critical Chance\n+30% crit chance bonus',
                Colors.orange,
              ),
              const SizedBox(height: 10),
              _buildClassButton(
                CharacterClass.paladin,
                '🛡️ Paladin',
                'High HP & Defense\n+20% healing bonus',
                Colors.blue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassButton(
    CharacterClass characterClass,
    String label,
    String desc,
    Color color,
  ) {
    final borderRadius = ResponsiveSizing.getBorderRadius(context);
    final padding =
        ResponsiveSizing.getSpacing(context, small: 10, medium: 12, large: 14);

    return GestureDetector(
      onTap: () => _selectClass(characterClass),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.7), color],
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: ResponsiveSizing.getShadowBlur(context),
            )
          ],
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: ResponsiveSizing.getFontSize(context,
                    small: 18, medium: 20, large: 22, xlarge: 24),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: ResponsiveSizing.getFontSize(context,
                    small: 12, medium: 13, large: 14, xlarge: 14),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyMenu() {
    final padding = ResponsiveSizing.getHorizontalPadding(context);
    final spacing =
        ResponsiveSizing.getSpacing(context, small: 20, medium: 24, large: 32);
    final buttonWidth = ResponsiveSizing.isSmallScreen(context) ? 140.0 : 180.0;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: padding,
                child: Column(
                  children: [
                    Text(
                      '⚔️ RPG Adventure ⚔️',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: ResponsiveSizing.getFontSize(context,
                                    small: 24,
                                    medium: 28,
                                    large: 32,
                                    xlarge: 36),
                              ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Battle enemies and become legendary!',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                            fontSize: ResponsiveSizing.getFontSize(context,
                                small: 12, medium: 14, large: 16, xlarge: 16),
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              SizedBox(height: spacing),
              _buildDifficultyButton(
                'Easy',
                'More HP & defense',
                Colors.green,
                buttonWidth,
              ),
              const SizedBox(height: 10),
              _buildDifficultyButton(
                'Medium',
                'Balanced difficulty',
                Colors.orange,
                buttonWidth,
              ),
              const SizedBox(height: 10),
              _buildDifficultyButton(
                'Hard',
                'Challenging adventure',
                Colors.red,
                buttonWidth,
              ),
              SizedBox(height: spacing),
              Container(
                padding: EdgeInsets.all(ResponsiveSizing.getSpacing(context,
                    small: 12, medium: 14, large: 16)),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(
                      ResponsiveSizing.getBorderRadius(context)),
                  border: Border.all(color: Colors.purple.shade300),
                ),
                child: Column(
                  children: [
                    Text(
                      '💡 How to Play',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveSizing.getFontSize(context,
                            small: 12, medium: 13, large: 14, xlarge: 14),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. Battle enemies to earn EXP and gold\n2. Level up to increase your stats\n3. Use spells to heal or deal extra damage\n4. Defeat bosses for big rewards!\n5. Survive as long as you can',
                      style: TextStyle(
                        fontSize: ResponsiveSizing.getFontSize(context,
                            small: 11, medium: 12, large: 13, xlarge: 13),
                        color: Colors.grey.shade700,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyButton(
    String label,
    String desc,
    Color color,
    double width,
  ) {
    final borderRadius = ResponsiveSizing.getBorderRadius(context);
    final padding =
        ResponsiveSizing.getSpacing(context, small: 10, medium: 12, large: 14);
    final shadowBlur = ResponsiveSizing.getShadowBlur(context);

    return GestureDetector(
      onTap: () => _startGame(label.toLowerCase()),
      child: Container(
        width: width,
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.7), color],
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: shadowBlur,
            )
          ],
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: ResponsiveSizing.getFontSize(context,
                    small: 15, medium: 16, large: 18, xlarge: 20),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: ResponsiveSizing.getFontSize(context,
                    small: 10, medium: 11, large: 12, xlarge: 12),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameScreen() {
    final padding = ResponsiveSizing.getPadding(context);
    final spacing = ResponsiveSizing.getSpacing(context);
    final borderRadius = ResponsiveSizing.getBorderRadius(context);

    return TabBarView(
      children: [
        // Explore Tab
        _buildExploreTab(padding, spacing, borderRadius),
        // Quests Tab
        _buildQuestsTab(padding, spacing, borderRadius),
        // Pet Tab
        _buildPetTab(padding, spacing, borderRadius),
      ],
    );
  }

  Widget _buildExploreTab(
      EdgeInsets padding, double spacing, double borderRadius) {
    const tileSize = 28.0;
    
    return Stack(
      children: [
        // Always show the map in the background
        SingleChildScrollView(
          child: Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Enhanced Player Stats HUD
                Container(
                  padding: EdgeInsets.all(ResponsiveSizing.getSpacing(context,
                      small: 8, medium: 10, large: 12)),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade50, Colors.purple.shade50],
                    ),
                    borderRadius: BorderRadius.circular(borderRadius),
                    border: Border.all(color: Colors.purple.shade200, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Lv $playerLevel ${_getClassIcon()} ${_getClassName()}',
                                  style: TextStyle(
                                    fontSize: ResponsiveSizing.getFontSize(context,
                                        small: 13, medium: 14, large: 15),
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple.shade900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.favorite, size: 12, color: Colors.red.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$playerHP/$playerMaxHP',
                                      style: TextStyle(
                                        fontSize: ResponsiveSizing.getFontSize(context,
                                            small: 11, medium: 12, large: 12),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(Icons.water_drop, size: 12, color: Colors.blue.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$manaPoints/$maxMana',
                                      style: TextStyle(
                                        fontSize: ResponsiveSizing.getFontSize(context,
                                            small: 11, medium: 12, large: 12),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  const Text('💰', style: TextStyle(fontSize: 14)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$playerGold',
                                    style: TextStyle(
                                      fontSize: ResponsiveSizing.getFontSize(context,
                                          small: 12, medium: 13, large: 14),
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '⚔️ $playerATK | 🛡️ $playerDEF',
                                style: TextStyle(
                                  fontSize: ResponsiveSizing.getFontSize(context,
                                      small: 10, medium: 11, large: 11),
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: spacing * 0.5),
                      // HP Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: playerHP / playerMaxHP,
                          minHeight: 6,
                          backgroundColor: Colors.red.shade100,
                          valueColor: AlwaysStoppedAnimation(Colors.red.shade600),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Mana Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: manaPoints / maxMana,
                          minHeight: 6,
                          backgroundColor: Colors.blue.shade100,
                          valueColor: AlwaysStoppedAnimation(Colors.blue.shade600),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // EXP Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: playerExp / playerExpToLevel,
                          minHeight: 6,
                          backgroundColor: Colors.purple.shade100,
                          valueColor: AlwaysStoppedAnimation(Colors.purple.shade600),
                        ),
                      ),
                      SizedBox(height: spacing * 0.3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '📍 (${playerPos.x}, ${playerPos.y}) | ${_getBiomeAt(playerPos.x, playerPos.y).toUpperCase()}',
                            style: TextStyle(
                              fontSize: ResponsiveSizing.getFontSize(context,
                                  small: 9, medium: 10, large: 10),
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (playerPet.isAlive)
                            Text(
                              '${playerPet.emoji} ${playerPet.name} Lv${playerPet.level}',
                              style: TextStyle(
                                fontSize: ResponsiveSizing.getFontSize(context,
                                    small: 9, medium: 10, large: 10),
                                color: Colors.pink.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: spacing),
                // Map viewport with keyboard support
                Focus(
                  focusNode: _mapFocusNode,
                  autofocus: true,
                  onKeyEvent: (node, event) {
                    _handleKeyEvent(event);
                    return KeyEventResult.handled;
                  },
                  child: GestureDetector(
                    onTap: () {
                      // Ensure focus when tapping map
                      _mapFocusNode?.requestFocus();
                    },
                    child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(borderRadius),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Center(
                          child: SizedBox(
                            width: worldWidth * tileSize,
                            height: worldHeight * tileSize,
                            child: Stack(
                              children: [
                          // Tiles
                          Positioned.fill(
                            child: Column(
                              children: List.generate(worldHeight, (y) {
                                return Row(
                                  children: List.generate(worldWidth, (x) {
                                    final t = worldMap[y][x];
                                    Color c;
                                    if (t == 1) {
                                      c = Colors.brown.shade400; // wall
                                    } else if (t == 2) {
                                      c = Colors.blue.shade400; // water
                                    } else if (t == 3) {
                                      c = Colors.orange.shade300; // town
                                    } else if (t == 4) {
                                      c = Colors.green.shade700; // forest
                                    } else if (t == 5) {
                                      c = Colors.grey.shade600; // mountain
                                    } else if (t == 6) {
                                      c = Colors.amber.shade300; // desert
                                    } else if (t == 7) {
                                      c = Colors.grey.shade800; // cave
                                    } else if (t == 8) {
                                      c = Colors.blue.shade200; // beach
                                    } else if (t == 9) {
                                      c = Colors.brown.shade700; // swamp
                                    } else {
                                      c = Colors.green.shade500; // grass
                                    }
                                    return Container(
                                      width: tileSize,
                                      height: tileSize,
                                      decoration: BoxDecoration(
                                        color: c,
                                        border: Border.all(
                                            color: Colors.black.withValues(alpha: 0.2),
                                            width: 0.5),
                                      ),
                                    );
                                  }),
                                );
                              }),
                            ),
                          ),
                          // NPCs
                          ...npcPositions.map((p) => Positioned(
                                left: p.x * tileSize,
                                top: p.y * tileSize,
                                child: const SizedBox(
                                  width: tileSize,
                                  height: tileSize,
                                  child: Center(child: Text('🧑')),
                                ),
                              )),
                          // Map enemies (visible enemies walking around)
                          ...mapEnemies.map((mapEnemy) => Positioned(
                                left: mapEnemy.position.x * tileSize,
                                top: mapEnemy.position.y * tileSize,
                                child: Container(
                                  width: mapEnemy.enemy.isBoss ? tileSize * 1.2 : tileSize,
                                  height: mapEnemy.enemy.isBoss ? tileSize * 1.2 : tileSize,
                                  decoration: BoxDecoration(
                                    color: mapEnemy.enemy.isBoss 
                                        ? Colors.purple.shade100.withValues(alpha: 0.8)
                                        : Colors.red.shade100.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(mapEnemy.enemy.isBoss ? 4 : 2),
                                    border: Border.all(
                                      color: mapEnemy.enemy.isBoss 
                                          ? Colors.purple.shade600 
                                          : Colors.red.shade400,
                                      width: mapEnemy.enemy.isBoss ? 2 : 1.5,
                                    ),
                                    boxShadow: mapEnemy.enemy.isBoss ? [
                                      BoxShadow(
                                        color: Colors.purple.withValues(alpha: 0.5),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ] : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      mapEnemy.enemy.emoji,
                                      style: TextStyle(
                                        fontSize: mapEnemy.enemy.isBoss ? tileSize * 0.75 : tileSize * 0.6,
                                        fontWeight: mapEnemy.enemy.isBoss ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              )),
                          // Player with smooth movement and facing direction
                          Positioned(
                            left: (playerPos.x * tileSize) + (playerVisualOffset.dx * tileSize),
                            top: (playerPos.y * tileSize) + (playerVisualOffset.dy * tileSize),
                            child: SizedBox(
                              width: tileSize,
                              height: tileSize,
                              child: Center(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 100),
                                  transform: () {
                                    final scale = isMoving ? 1.15 : 1.0;
                                    return Matrix4.identity()
                                      ..scaleByDouble(scale, scale, 1.0, 1.0);
                                  }(),
                                  child: Builder(
                                    builder: (context) {
                                      const playerFontSize = tileSize * 0.9;
                                      return Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          const Text(
                                            '🧙',
                                            style: TextStyle(
                                              fontSize: playerFontSize,
                                            ),
                                          ),
                                          // Direction indicator
                                          Positioned(
                                            top: 0,
                                            child: Text(
                                              playerFacingDirection == 0 ? '↑' :
                                              playerFacingDirection == 1 ? '→' :
                                              playerFacingDirection == 2 ? '↓' : '←',
                                              style: TextStyle(
                                                fontSize: tileSize * 0.3,
                                                color: Colors.white.withValues(alpha: 0.7),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Show enemy on current position during battle
                          if (inBattle && inExploreBattle)
                            Positioned(
                              left: playerPos.x * tileSize,
                              top: (playerPos.y - 1) * tileSize,
                              child: Container(
                                width: tileSize,
                                height: tileSize,
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.red,
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    currentEnemy.name.split(' ').first, // Show first word of enemy name
                                    style: const TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                    ),
                  ),
                ),
                SizedBox(height: spacing),
                
                // Quick Info Cards
                if (!inBattle)
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(borderRadius),
                            border: Border.all(color: Colors.purple.shade200),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '🌊 Wave $currentWave',
                                style: TextStyle(
                                  fontSize: ResponsiveSizing.getFontSize(context,
                                      small: 11, medium: 12, large: 13),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple.shade900,
                                ),
                              ),
                              Text(
                                '👹 $enemiesDefeated defeated',
                                style: TextStyle(
                                  fontSize: ResponsiveSizing.getFontSize(context,
                                      small: 9, medium: 10, large: 11),
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: spacing * 0.5),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(borderRadius),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (equippedWeapon != null)
                                    Text(equippedWeapon!.getRarityEmoji(), style: const TextStyle(fontSize: 16)),
                                  const SizedBox(width: 4),
                                  if (equippedArmor != null)
                                    Text(equippedArmor!.getRarityEmoji(), style: const TextStyle(fontSize: 16)),
                                  const SizedBox(width: 4),
                                  if (equippedRing != null)
                                    Text(equippedRing!.getRarityEmoji(), style: const TextStyle(fontSize: 16)),
                                ],
                              ),
                              Text(
                                '${equipment.length} items',
                                style: TextStyle(
                                  fontSize: ResponsiveSizing.getFontSize(context,
                                      small: 9, medium: 10, large: 11),
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                
                if (!inBattle)
                  SizedBox(height: spacing),
                
                // Movement controls - always show but disable when in battle or paused
                Column(
                  children: [
                    // Show status message if movement is blocked
                    if (inBattle || isPaused)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: inBattle ? Colors.red.shade100 : Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(borderRadius),
                        ),
                        child: Text(
                          inBattle ? '⚠️ Cannot move during battle' : '⏸️ Game is paused',
                          style: TextStyle(
                            fontSize: ResponsiveSizing.getFontSize(context,
                                small: 11, medium: 12, large: 13),
                            color: inBattle ? Colors.red.shade900 : Colors.orange.shade900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: (inBattle || isPaused) ? null : () => _onMove(0, -1),
                          icon: const Icon(Icons.keyboard_arrow_up),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.grey.shade200,
                            disabledBackgroundColor: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: (inBattle || isPaused) ? null : () => _onMove(-1, 0),
                          icon: const Icon(Icons.keyboard_arrow_left),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.grey.shade200,
                            disabledBackgroundColor: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: (inBattle || isPaused) ? null : () => _interact(),
                          icon: const Icon(Icons.chat_bubble_outline),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.amber.shade200,
                            disabledBackgroundColor: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: (inBattle || isPaused) ? null : () => _onMove(1, 0),
                          icon: const Icon(Icons.keyboard_arrow_right),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.grey.shade200,
                            disabledBackgroundColor: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: (inBattle || isPaused) ? null : () => _onMove(0, 1),
                          icon: const Icon(Icons.keyboard_arrow_down),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.grey.shade200,
                            disabledBackgroundColor: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        // Overlay battle UI on top when in battle from explore
        if (inBattle && inExploreBattle)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBattleOverlay(padding, spacing, borderRadius),
          ),
      ],
    );
  }
  
  /// Battle overlay for explore mode - shown at bottom while map remains visible
  Widget _buildBattleOverlay(
      EdgeInsets padding, double spacing, double borderRadius) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.95),
            Colors.red.shade900.withValues(alpha: 0.9),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.6),
            blurRadius: 15,
            spreadRadius: 3,
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Battle Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '⚔️ BATTLE!',
                    style: TextStyle(
                      color: Colors.red.shade100,
                      fontSize: ResponsiveSizing.getFontSize(context,
                          small: 16, medium: 18, large: 20),
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.red.withValues(alpha: 0.8),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  if (comboCounter > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text(
                        '🔥 Combo x$comboCounter',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: ResponsiveSizing.getFontSize(context,
                              small: 11, medium: 12, large: 13),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: spacing * 0.5),
              
              // Player and Enemy stats side by side
              Row(
                children: [
                  // Player stats
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(spacing * 0.7),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(borderRadius),
                        border: Border.all(color: Colors.blue.shade300, width: 2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'YOU',
                            style: TextStyle(
                              fontSize: ResponsiveSizing.getFontSize(context,
                                  small: 10, medium: 11, large: 12),
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '❤️ $playerHP/$playerMaxHP',
                            style: TextStyle(
                              fontSize: ResponsiveSizing.getFontSize(context,
                                  small: 10, medium: 11, large: 12),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: playerHP / playerMaxHP,
                              minHeight: 8,
                              backgroundColor: Colors.red.shade200,
                              valueColor: AlwaysStoppedAnimation(Colors.red.shade600),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '💧 $manaPoints/$maxMana',
                            style: TextStyle(
                              fontSize: ResponsiveSizing.getFontSize(context,
                                  small: 9, medium: 10, large: 11),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: manaPoints / maxMana,
                              minHeight: 6,
                              backgroundColor: Colors.blue.shade200,
                              valueColor: AlwaysStoppedAnimation(Colors.blue.shade600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: spacing * 0.5),
                  // Enemy stats
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(spacing * 0.7),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(borderRadius),
                        border: Border.all(color: Colors.red.shade300, width: 2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  currentEnemy.name.split('(')[0].trim(),
                                  style: TextStyle(
                                    fontSize: ResponsiveSizing.getFontSize(context,
                                        small: 10, medium: 11, large: 12),
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade900,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (currentEnemy.element != ElementType.none)
                                Text(
                                  _getElementEmoji(currentEnemy.element),
                                  style: const TextStyle(fontSize: 16),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '❤️ ${max(0, currentEnemy.hp)}/${currentEnemy.maxHp}',
                            style: TextStyle(
                              fontSize: ResponsiveSizing.getFontSize(context,
                                  small: 10, medium: 11, large: 12),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: max(0, currentEnemy.hp.toDouble()) / currentEnemy.maxHp.toDouble(),
                              minHeight: 8,
                              backgroundColor: Colors.red.shade200,
                              valueColor: AlwaysStoppedAnimation(Colors.red.shade700),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '⚔️ ${currentEnemy.atk} | 🛡️ ${currentEnemy.def}',
                            style: TextStyle(
                              fontSize: ResponsiveSizing.getFontSize(context,
                                  small: 9, medium: 10, large: 11),
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing),

              // Battle message
              if (showMessage)
                Container(
                  padding: EdgeInsets.all(ResponsiveSizing.getSpacing(context,
                      small: 10, medium: 12, large: 14)),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(borderRadius),
                    border: Border.all(color: Colors.amber.shade600, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Text(
                    message,
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveSizing.getFontSize(context,
                          small: 12, medium: 14, large: 15),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              SizedBox(height: spacing),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: canAction && playerTurn ? _playerAttack : null,
                      icon: const Icon(Icons.flash_on, size: 20),
                      label: const Text('Attack'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade600,
                        disabledForegroundColor: Colors.grey.shade400,
                        padding: EdgeInsets.symmetric(
                          vertical: ResponsiveSizing.getSpacing(context,
                              small: 10, medium: 12, large: 14),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(borderRadius),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: spacing * 0.5),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: canAction && playerTurn ? _playerDefend : null,
                      icon: const Icon(Icons.shield, size: 20),
                      label: const Text('Defend'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade600,
                        disabledForegroundColor: Colors.grey.shade400,
                        padding: EdgeInsets.symmetric(
                          vertical: ResponsiveSizing.getSpacing(context,
                              small: 10, medium: 12, large: 14),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(borderRadius),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: spacing * 0.5),
                  ElevatedButton(
                    onPressed: canAction && playerTurn ? () => _showSkillsDialog() : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade600,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade600,
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveSizing.getSpacing(context,
                            small: 12, medium: 14, large: 16),
                        vertical: ResponsiveSizing.getSpacing(context,
                            small: 10, medium: 12, large: 14),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(borderRadius),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome, size: 20),
                        Text(
                          'Skills',
                          style: TextStyle(
                            fontSize: ResponsiveSizing.getFontSize(context,
                                small: 10, medium: 11, large: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing),
              
              // Status effects - Enhanced display
              if (playerEffects.where((e) => e.remainingTurns > 0).isNotEmpty || 
                  enemyEffects.where((e) => e.remainingTurns > 0).isNotEmpty)
                Container(
                  padding: EdgeInsets.all(spacing * 0.7),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(borderRadius),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      if (playerEffects.where((e) => e.remainingTurns > 0).isNotEmpty)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Effects:',
                                style: TextStyle(
                                  fontSize: ResponsiveSizing.getFontSize(context,
                                      small: 9, medium: 10, large: 11),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                              Wrap(
                                spacing: 4,
                                children: playerEffects
                                    .where((e) => e.remainingTurns > 0)
                                    .map((e) => Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.blue.shade300),
                                          ),
                                          child: Text(
                                            '${e.emoji} ${e.name} (${e.remainingTurns})',
                                            style: TextStyle(
                                              fontSize: ResponsiveSizing.getFontSize(context,
                                                  small: 8, medium: 9, large: 10),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      if (enemyEffects.where((e) => e.remainingTurns > 0).isNotEmpty)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Enemy Effects:',
                                style: TextStyle(
                                  fontSize: ResponsiveSizing.getFontSize(context,
                                      small: 9, medium: 10, large: 11),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade900,
                                ),
                              ),
                              Wrap(
                                spacing: 4,
                                children: enemyEffects
                                    .where((e) => e.remainingTurns > 0)
                                    .map((e) => Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.red.shade300),
                                          ),
                                          child: Text(
                                            '${e.emoji} ${e.name} (${e.remainingTurns})',
                                            style: TextStyle(
                                              fontSize: ResponsiveSizing.getFontSize(context,
                                                  small: 8, medium: 9, large: 10),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              
              // Combat log - Recent 3 messages
              if (combatLog.isNotEmpty)
                Column(
                  children: [
                    SizedBox(height: spacing * 0.5),
                    Container(
                      padding: EdgeInsets.all(spacing * 0.5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(borderRadius),
                        border: Border.all(color: Colors.grey.shade600),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📜 Battle Log',
                            style: TextStyle(
                              fontSize: ResponsiveSizing.getFontSize(context,
                                  small: 9, medium: 10, large: 11),
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...combatLog.reversed.take(3).map((log) => Text(
                                '• $log',
                                style: TextStyle(
                                  fontSize: ResponsiveSizing.getFontSize(context,
                                      small: 8, medium: 9, large: 10),
                                  color: Colors.white60,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestsTab(
      EdgeInsets padding, double spacing, double borderRadius) {
    final completedCount = activeQuests.where((q) => q.completed).length;

    return SingleChildScrollView(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(spacing),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📜 Daily Quests',
                    style: TextStyle(
                      fontSize: ResponsiveSizing.getFontSize(context,
                          small: 14, medium: 16, large: 18, xlarge: 18),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$completedCount/${activeQuests.length} Completed',
                    style: TextStyle(
                      fontSize: ResponsiveSizing.getFontSize(context,
                          small: 12, medium: 13, large: 14, xlarge: 14),
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing),
            ...activeQuests.map((quest) => Container(
                  margin: EdgeInsets.only(bottom: spacing * 0.8),
                  padding: EdgeInsets.all(spacing),
                  decoration: BoxDecoration(
                    color:
                        quest.completed ? Colors.green.shade50 : Colors.white,
                    borderRadius: BorderRadius.circular(borderRadius),
                    border: Border.all(
                      color: quest.completed
                          ? Colors.green.shade300
                          : Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            quest.icon,
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  quest.name,
                                  style: TextStyle(
                                    fontSize: ResponsiveSizing.getFontSize(
                                        context,
                                        small: 13,
                                        medium: 14,
                                        large: 15,
                                        xlarge: 15),
                                    fontWeight: FontWeight.bold,
                                    decoration: quest.completed
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                Text(
                                  quest.description,
                                  style: TextStyle(
                                    fontSize: ResponsiveSizing.getFontSize(
                                        context,
                                        small: 11,
                                        medium: 12,
                                        large: 12,
                                        xlarge: 12),
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (quest.completed)
                            const Icon(Icons.check_circle,
                                color: Colors.green, size: 28)
                        ],
                      ),
                      SizedBox(height: spacing * 0.5),
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: quest.progressPercent,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation(
                              quest.completed ? Colors.green : Colors.blue),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${quest.progress}/${quest.targetValue}',
                            style: TextStyle(
                              fontSize: ResponsiveSizing.getFontSize(context,
                                  small: 10, medium: 11, large: 11, xlarge: 11),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '💰 ${quest.goldReward} ✨ ${quest.expReward}',
                            style: TextStyle(
                              fontSize: ResponsiveSizing.getFontSize(context,
                                  small: 10, medium: 11, large: 11, xlarge: 11),
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )),
            SizedBox(height: spacing),
            // Achievements section
            Container(
              padding: EdgeInsets.all(spacing),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🏆 Achievements',
                    style: TextStyle(
                      fontSize: ResponsiveSizing.getFontSize(context,
                          small: 14, medium: 16, large: 18, xlarge: 18),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: spacing * 0.6,
                    runSpacing: spacing * 0.6,
                    children: achievements
                        .map((ach) => GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text('${ach.icon} ${ach.name}'),
                                    content: Text(ach.description),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Close'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: ach.unlocked
                                      ? Colors.yellow.shade100
                                      : Colors.grey.shade200,
                                  borderRadius:
                                      BorderRadius.circular(borderRadius * 0.8),
                                  border: Border.all(
                                    color: ach.unlocked
                                        ? Colors.orange
                                        : Colors.grey,
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        ach.icon,
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                      if (!ach.unlocked)
                                        Text(
                                          '🔒',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPetTab(EdgeInsets padding, double spacing, double borderRadius) {
    return SingleChildScrollView(
      child: Padding(
        padding: padding,
        child: Column(
          children: [
            // 3D/2D View Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  use3DView ? '3D View' : '2D View',
                  style: TextStyle(
                    fontSize: ResponsiveSizing.getFontSize(context,
                        small: 12, medium: 13, large: 14),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: use3DView,
                  onChanged: (value) {
                    setState(() {
                      use3DView = value;
                    });
                  },
                  activeThumbColor: Colors.purple,
                ),
              ],
            ),
            SizedBox(height: spacing * 0.5),
            
            // Pet display
            Container(
              padding: EdgeInsets.all(spacing),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.pink.shade100, Colors.purple.shade100],
                ),
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(color: Colors.pink.shade300, width: 2),
              ),
              child: Column(
                children: [
                  // 3D or 2D Pet Display
                  if (use3DView)
                    Pet3DViewer(
                      petType: _getPetType(playerPet.emoji),
                      evolutionStage: playerPet.evolutionStage,
                      level: playerPet.level,
                      isAlive: playerPet.isAlive,
                      onTap: () {
                        // Show pet interaction dialog
                        _showPetInteractionDialog();
                      },
                    )
                  else
                    Text(
                      playerPet.evolvedEmoji,
                      style: const TextStyle(fontSize: 80),
                    ),
                  SizedBox(height: spacing * 0.5),
                  Text(
                    playerPet.name,
                    style: TextStyle(
                      fontSize: ResponsiveSizing.getFontSize(context,
                          small: 18, medium: 20, large: 22, xlarge: 24),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Level ${playerPet.level}${playerPet.evolutionStage > 0 ? ' | Stage ${playerPet.evolutionStage + 1}' : ''}',
                    style: TextStyle(
                      fontSize: ResponsiveSizing.getFontSize(context,
                          small: 12, medium: 14, large: 16, xlarge: 16),
                      color: Colors.grey.shade700,
                    ),
                  ),
                  if (playerPet.specialAbility != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Special: ${playerPet.specialAbility}',
                        style: TextStyle(
                          fontSize: ResponsiveSizing.getFontSize(context,
                              small: 11, medium: 12, large: 13, xlarge: 13),
                          color: Colors.purple.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: spacing),

            // Pet stats
            Container(
              padding: EdgeInsets.all(spacing),
              decoration: BoxDecoration(
                color: Colors.pink.shade50,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(color: Colors.pink.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pet Stats',
                    style: TextStyle(
                      fontSize: ResponsiveSizing.getFontSize(context,
                          small: 13, medium: 14, large: 15, xlarge: 15),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: spacing * 0.8),
                  _buildPetStatRow(
                      '❤️ HP',
                      '${playerPet.hp}/${playerPet.maxHp}',
                      playerPet.hp / playerPet.maxHp,
                      Colors.red),
                  SizedBox(height: spacing * 0.6),
                  _buildPetStatRow('⚔️ Attack', '+${playerPet.atkBonus}',
                      (playerPet.atkBonus / 10).clamp(0, 1), Colors.orange),
                  SizedBox(height: spacing * 0.6),
                  _buildPetStatRow('🛡️ Defense', '+${playerPet.defBonus}',
                      (playerPet.defBonus / 10).clamp(0, 1), Colors.blue),
                  SizedBox(height: spacing * 0.8),
                  Text(
                    '😊 Happiness: $petHappiness%',
                    style: TextStyle(
                      fontSize: ResponsiveSizing.getFontSize(context,
                          small: 12, medium: 13, large: 14, xlarge: 14),
                      fontWeight: FontWeight.bold,
                      color: Colors.pink,
                    ),
                  ),
                  SizedBox(height: spacing * 0.4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: petHappiness / 100,
                      minHeight: 12,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation(Colors.pink.shade600),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing),

            // Pet benefits
            Container(
              padding: EdgeInsets.all(spacing),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✨ Pet Bonuses',
                    style: TextStyle(
                      fontSize: ResponsiveSizing.getFontSize(context,
                          small: 13, medium: 14, large: 15, xlarge: 15),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: spacing * 0.6),
                  Text(
                    '💪 +${playerPet.atkBonus} ATK in battle',
                    style: TextStyle(
                      fontSize: ResponsiveSizing.getFontSize(context,
                          small: 11, medium: 12, large: 12, xlarge: 12),
                    ),
                  ),
                  SizedBox(height: spacing * 0.3),
                  Text(
                    '🛡️ +${playerPet.defBonus} DEF in battle',
                    style: TextStyle(
                      fontSize: ResponsiveSizing.getFontSize(context,
                          small: 11, medium: 12, large: 12, xlarge: 12),
                    ),
                  ),
                  SizedBox(height: spacing * 0.3),
                  Text(
                    '💰 +5% gold from victories',
                    style: TextStyle(
                      fontSize: ResponsiveSizing.getFontSize(context,
                          small: 11, medium: 12, large: 12, xlarge: 12),
                    ),
                  ),
                  SizedBox(height: spacing * 0.3),
                  Text(
                    '✨ +3% EXP from victories',
                    style: TextStyle(
                      fontSize: ResponsiveSizing.getFontSize(context,
                          small: 11, medium: 12, large: 12, xlarge: 12),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing),

            // Pet info
            Container(
              padding: EdgeInsets.all(spacing),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pet Care Tips',
                    style: TextStyle(
                      fontSize: ResponsiveSizing.getFontSize(context,
                          small: 12, medium: 13, large: 14, xlarge: 14),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: spacing * 0.4),
                  Text(
                    '• Your pet gains happiness when you win battles\n• Higher happiness increases battle bonuses\n• Pet levels up when you level up\n• Feed your pet to keep them happy!',
                    style: TextStyle(
                      fontSize: ResponsiveSizing.getFontSize(context,
                          small: 10, medium: 11, large: 11, xlarge: 11),
                      height: 1.6,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPetStatRow(
      String label, String value, double progress, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: ResponsiveSizing.getFontSize(context,
                  small: 11, medium: 12, large: 12, xlarge: 12),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 16,
              backgroundColor: color.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 40,
          child: Text(
            value,
            style: TextStyle(
              fontSize: ResponsiveSizing.getFontSize(context,
                  small: 11, medium: 12, large: 12, xlarge: 12),
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  String _getElementEmoji(ElementType element) {
    switch (element) {
      case ElementType.fire:
        return '🔥';
      case ElementType.ice:
        return '❄️';
      case ElementType.lightning:
        return '⚡';
      case ElementType.poison:
        return '☠️';
      case ElementType.holy:
        return '✨';
      case ElementType.dark:
        return '🌑';
      default:
        return '';
    }
  }

  Widget _buildGameOverScreen() {
    final padding = ResponsiveSizing.getPadding(context);
    final spacing = ResponsiveSizing.getSpacing(context);
    final borderRadius = ResponsiveSizing.getBorderRadius(context);

    final unlockedAchievements = achievements.where((a) => a.unlocked).length;

    return SingleChildScrollView(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: spacing * 2),
            Container(
              padding: EdgeInsets.all(ResponsiveSizing.getSpacing(context,
                  small: 14, medium: 18, large: 22)),
              decoration: BoxDecoration(
                color: Colors.purple.shade100,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(color: Colors.purple, width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    '⚔️ Adventure Over! ⚔️',
                    style: TextStyle(
                      fontSize: ResponsiveSizing.getFontSize(context,
                          small: 20, medium: 24, large: 28, xlarge: 32),
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing),
                  Text(
                    'Level $playerLevel Hero - Reached Wave $currentWave!',
                    style: TextStyle(
                      fontSize: ResponsiveSizing.getFontSize(context,
                          small: 14, medium: 16, large: 18, xlarge: 18),
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
                    ),
                  ),
                  SizedBox(height: spacing * 0.5),
                  Text(
                    '${playerPet.emoji} ${playerPet.name} leveled up to ${playerPet.level}!',
                    style: TextStyle(
                      fontSize: ResponsiveSizing.getFontSize(context,
                          small: 12, medium: 13, large: 14, xlarge: 14),
                      color: Colors.pink.shade700,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing),

            // Stats Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              children: [
                _buildStatBox('💰 Gold Earned', '$playerGold', Colors.orange),
                _buildStatBox(
                    '👹 Enemies Defeated', '$enemiesDefeated', Colors.red),
                _buildStatBox(
                    '👑 Bosses Defeated', '$bossesDefeated', Colors.deepPurple),
                _buildStatBox('📊 Final ATK', '$playerATK', Colors.red),
                _buildStatBox('🛡️ Final DEF', '$playerDEF', Colors.blue),
                _buildStatBox('💛 Max HP', '$playerMaxHP', Colors.green),
                _buildStatBox('⚡ Critical Hits', '$criticalHitsCount', Colors.yellow),
                _buildStatBox('✨ Skills Used', '$skillsUsed', Colors.purple),
                _buildStatBox('❤️ Healing Done', '$healingDone', Colors.pink),
                _buildStatBox('💥 Damage Dealt', '$damageDealt', Colors.red.shade700),
                _buildStatBox('🛡️ Damage Taken', '$damageTaken', Colors.grey),
                _buildStatBox('🌊 Wave Reached', '$currentWave', Colors.blue.shade600),
              ],
            ),
            SizedBox(height: spacing),

            // Achievements unlocked this run
            Container(
              padding: EdgeInsets.all(ResponsiveSizing.getSpacing(context,
                  small: 12, medium: 14, large: 16)),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🏆 Progress: $unlockedAchievements/${achievements.length} Achievements',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveSizing.getFontSize(context,
                          small: 12, medium: 13, large: 14, xlarge: 14),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: spacing * 0.4,
                    runSpacing: spacing * 0.4,
                    children: achievements
                        .where((a) => a.unlocked)
                        .take(6)
                        .map((ach) => Tooltip(
                              message: ach.name,
                              child: Text(ach.icon,
                                  style: const TextStyle(fontSize: 28)),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing),

            // Equipment display
            if (equipment.isNotEmpty)
              Container(
                padding: EdgeInsets.all(ResponsiveSizing.getSpacing(context,
                    small: 12, medium: 14, large: 16)),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(color: Colors.amber),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚙️ Equipment Found: ${equipment.length}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveSizing.getFontSize(context,
                            small: 12, medium: 13, large: 14, xlarge: 14),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...equipment.map((e) => Text(
                          '${e.getRarityEmoji()} ${e.name} (+${e.atkBonus}ATK, +${e.defBonus}DEF)',
                          style: TextStyle(
                            fontSize: ResponsiveSizing.getFontSize(context,
                                small: 11, medium: 12, large: 13, xlarge: 13),
                            color: e.getRarityColor(),
                            fontWeight: FontWeight.bold,
                          ),
                        )),
                  ],
                ),
              ),
            SizedBox(height: spacing),

            // Quest completion summary
            if (activeQuests.any((q) => q.completed))
              Container(
                padding: EdgeInsets.all(ResponsiveSizing.getSpacing(context,
                    small: 12, medium: 14, large: 16)),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '✅ Quests Completed',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveSizing.getFontSize(context,
                            small: 12, medium: 13, large: 14, xlarge: 14),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...activeQuests.where((q) => q.completed).map((q) => Text(
                          '${q.icon} ${q.name}',
                          style: TextStyle(
                            fontSize: ResponsiveSizing.getFontSize(context,
                                small: 11, medium: 12, large: 12, xlarge: 12),
                            color: Colors.green.shade700,
                          ),
                        )),
                  ],
                ),
              ),
            SizedBox(height: spacing),

            // Play Again Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _resetGame,
                icon: const Icon(Icons.refresh),
                label: Text(
                  'New Adventure',
                  style: TextStyle(
                    fontSize: ResponsiveSizing.getFontSize(context,
                        small: 14, medium: 16, large: 18, xlarge: 18),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                ),
              ),
            ),
            SizedBox(height: spacing * 0.5),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: Text(
                  'Back to Games',
                  style: TextStyle(
                    fontSize: ResponsiveSizing.getFontSize(context,
                        small: 14, medium: 16, large: 18, xlarge: 18),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                ),
              ),
            ),
            SizedBox(height: spacing),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    final borderRadius = ResponsiveSizing.getBorderRadius(context);
    final padding =
        ResponsiveSizing.getSpacing(context, small: 12, medium: 14, large: 16);

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: ResponsiveSizing.getFontSize(context,
                  small: 11, medium: 12, large: 13, xlarge: 13),
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: ResponsiveSizing.getFontSize(context,
                  small: 16, medium: 18, large: 20, xlarge: 22),
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ====== OVERWORLD LOGIC ======
  void _initializeWorld({bool resetOnly = false}) {
    // Build an enhanced world with diverse biomes and terrain
    worldMap = List.generate(
      worldHeight,
      (y) => List.generate(worldWidth, (x) => 0),
    );
    
    // Initialize player positions
    if (!resetOnly) {
      playerPos = const Point(2, 2);
      targetPlayerPos = const Point(2, 2);
      playerVisualOffset = Offset.zero;
      isMoving = false;
    }

    final random = Random();

    // Borders as walls
    for (int x = 0; x < worldWidth; x++) {
      worldMap[0][x] = 1;
      worldMap[worldHeight - 1][x] = 1;
    }
    for (int y = 0; y < worldHeight; y++) {
      worldMap[y][0] = 1;
      worldMap[y][worldWidth - 1] = 1;
    }

    // Town rectangle (safe zone)
    const townLeft = 5;
    const townTop = 4;
    const townRight = 9;
    const townBottom = 7;
    for (int y = townTop; y <= townBottom; y++) {
      for (int x = townLeft; x <= townRight; x++) {
        worldMap[y][x] = 3;
      }
    }

    // Water pond/river (northeast)
    for (int y = 1; y <= 4; y++) {
      for (int x = worldWidth - 5; x <= worldWidth - 2; x++) {
        if (random.nextDouble() < 0.8) {
          worldMap[y][x] = 2;
        }
      }
    }

    // Beach area (northeast near water)
    for (int y = 1; y <= 3; y++) {
      for (int x = worldWidth - 6; x < worldWidth - 5; x++) {
        if (x >= 0 && y >= 0 && x < worldWidth && y < worldHeight) {
          worldMap[y][x] = 8;
        }
      }
    }

    // Mountain range (northwest)
    for (int y = 1; y <= 3; y++) {
      for (int x = 1; x <= 4; x++) {
        if (random.nextDouble() < 0.6) {
          worldMap[y][x] = 5;
        }
      }
    }

    // Desert area (southwest)
    for (int y = worldHeight - 3; y < worldHeight - 1; y++) {
      for (int x = 1; x <= 4; x++) {
        if (random.nextDouble() < 0.7) {
          worldMap[y][x] = 6;
        }
      }
    }

    // Swamp area (southeast)
    for (int y = worldHeight - 3; y < worldHeight - 1; y++) {
      for (int x = worldWidth - 6; x < worldWidth - 1; x++) {
        if (random.nextDouble() < 0.65) {
          worldMap[y][x] = 9;
        }
      }
    }

    // Cave entrance (south center)
    if (worldHeight > 8 && worldWidth > 10) {
      worldMap[worldHeight - 2][worldWidth ~/ 2] = 7;
      worldMap[worldHeight - 2][worldWidth ~/ 2 - 1] = 7;
      if (worldHeight > 9) {
        worldMap[worldHeight - 3][worldWidth ~/ 2] = 7;
      }
    }

    // Forest areas (main exploration zone)
    for (int y = townBottom + 1; y < worldHeight - 1; y++) {
      for (int x = 2; x < worldWidth - 2; x++) {
        // Skip if already assigned
        if (worldMap[y][x] == 0 && random.nextDouble() < 0.4) {
          worldMap[y][x] = 4;
        }
      }
    }
    
    // Additional forest patches (center area)
    for (int y = 2; y <= townTop - 1; y++) {
      for (int x = 2; x < worldWidth - 2; x++) {
        if (worldMap[y][x] == 0 && (x + y) % 4 == 0 && random.nextDouble() < 0.5) {
          worldMap[y][x] = 4;
        }
      }
    }

    // NPCs inside town
    npcPositions = [
      const Point(6, 5),
      const Point(8, 6),
    ];
    npcDialogue = {
      const Point(6, 5): 'Welcome to Elmwood! Explore diverse biomes: forests, mountains, deserts, and caves!',
      const Point(8, 6): 'Each biome has unique enemies. Venture far for stronger foes and better loot!',
    };

    // Player start
    playerPos = const Point(2, 2);
    showExploreToast = false;
    
    // Spawn map enemies if not reset only
    if (!resetOnly) {
      _spawnMapEnemies();
      _startEnemyMovementTimer();
    }
    
    if (!resetOnly) setState(() {});
  }
  
  void _spawnMapEnemies() {
    mapEnemies.clear();
    final random = Random();
    int enemyCount = 5 + (playerLevel ~/ 2); // More enemies at higher levels, max 15
    
    for (int i = 0; i < enemyCount; i++) {
      _spawnSingleEnemy(random);
    }
  }
  
  void _spawnAdditionalEnemy() {
    // Spawn just one additional enemy when map is getting empty
    _spawnSingleEnemy(Random());
  }
  
  void _spawnSingleEnemy(Random random) {
    Point<int>? spawnPos;
    String? targetBiome;
    int attempts = 0;
    
    // Sometimes spawn in a specific biome (30% chance), otherwise anywhere valid
    if (random.nextDouble() < 0.3) {
      final biomes = ['forest', 'desert', 'beach', 'swamp', 'cave'];
      targetBiome = biomes[random.nextInt(biomes.length)];
    }
    
    // Try to find a valid spawn position
    while (spawnPos == null && attempts < 100) {
      final x = random.nextInt(worldWidth);
      final y = random.nextInt(worldHeight);
      final tile = worldMap[y][x];
      final biome = _getBiomeAt(x, y);
      
      // Spawn on walkable terrain (grass, forest, desert, beach, swamp)
      if ((tile == 0 || tile == 4 || tile == 6 || tile == 8 || tile == 9) && 
          (x != playerPos.x || y != playerPos.y) &&
          !npcPositions.contains(Point(x, y)) &&
          !mapEnemies.any((e) => e.position.x == x && e.position.y == y)) {
        // If targeting a specific biome, check if this matches
        if (targetBiome == null || biome == targetBiome) {
          spawnPos = Point(x, y);
        }
      }
      attempts++;
      
      // If we've tried too many times with a target biome, allow any valid spawn
      if (attempts > 50 && targetBiome != null) {
        targetBiome = null;
        attempts = 0;
      }
    }
    
    if (spawnPos != null) {
      final biome = _getBiomeAt(spawnPos.x, spawnPos.y);
      
      // Randomly determine if boss (5% chance, higher at higher levels)
      // Bosses are more common in dangerous biomes
      double bossChance = 0.05 + (playerLevel * 0.01);
      if (biome == 'cave' || biome == 'swamp') {
        bossChance += 0.03; // Caves and swamps have stronger enemies
      }
      
      bool isBoss = random.nextDouble() < bossChance;
      
      final enemy = Enemy.random(
        difficulty: difficulty,
        isBoss: isBoss,
        playerLevel: playerLevel,
        biome: biome,
      );
      
      mapEnemies.add(MapEnemy(
        position: spawnPos,
        enemy: enemy,
        moveDirection: random.nextInt(4), // Random initial direction
      ));
      
      if (mounted) {
        setState(() {}); // Update UI to show new enemy
      }
    }
  }
  
  void _startEnemyMovementTimer() {
    enemyMovementTimer?.cancel();
    enemyMovementTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (!mounted || isPaused || inBattle) return;
      _moveMapEnemies();
    });
  }
  
  void _moveMapEnemies() {
    if (isPaused || inBattle) return;
    
    final random = Random();
    bool updated = false;
    
    for (var mapEnemy in mapEnemies) {
      // Decide whether to move (70% chance)
      if (random.nextDouble() > 0.7) continue;
      
      // Try to move in current direction, or pick a new random direction
      Point<int>? newPos;
      
      // Try current direction first
      if (mapEnemy.moveDirection >= 0) {
        int dx = 0, dy = 0;
        switch (mapEnemy.moveDirection) {
          case 0: dy = -1; break; // up
          case 1: dx = 1; break;  // right
          case 2: dy = 1; break;  // down
          case 3: dx = -1; break; // left
        }
        
        final nx = mapEnemy.position.x + dx;
        final ny = mapEnemy.position.y + dy;
        
        if (_isWalkableForEnemy(nx, ny)) {
          // Check if position is not occupied by another enemy or player
          if (!mapEnemies.any((e) => e != mapEnemy && e.position.x == nx && e.position.y == ny) &&
              !(nx == playerPos.x && ny == playerPos.y)) {
            newPos = Point(nx, ny);
          }
        }
      }
      
      // If couldn't move in current direction, pick a random valid direction
      if (newPos == null) {
        final directions = [
          const Point(0, -1), // up
          const Point(1, 0),  // right
          const Point(0, 1),  // down
          const Point(-1, 0), // left
        ];
        directions.shuffle(random);
        
        for (final dir in directions) {
          final nx = mapEnemy.position.x + dir.x;
          final ny = mapEnemy.position.y + dir.y;
          
          if (_isWalkableForEnemy(nx, ny) &&
              !mapEnemies.any((e) => e != mapEnemy && e.position.x == nx && e.position.y == ny) &&
              !(nx == playerPos.x && ny == playerPos.y)) {
            newPos = Point(nx, ny);
            // Update direction
            mapEnemy.moveDirection = directions.indexOf(dir);
            break;
          }
        }
      }
      
      if (newPos != null) {
        mapEnemy.move(newPos);
        updated = true;
      } else {
        // Change direction if stuck
        mapEnemy.moveDirection = random.nextInt(4);
      }
    }
    
    if (updated && mounted) {
      setState(() {});
    }
  }
  
  bool _isWalkableForEnemy(int x, int y) {
    if (x < 0 || y < 0 || x >= worldWidth || y >= worldHeight) return false;
    final t = worldMap[y][x];
    // Enemies can walk on grass, forest, desert, beach, swamp, but not town, water, walls, mountains, or caves
    return t == 0 || t == 4 || t == 6 || t == 8 || t == 9; // grass, forest, desert, beach, swamp
  }

  bool _isWalkable(int x, int y) {
    if (x < 0 || y < 0 || x >= worldWidth || y >= worldHeight) return false;
    final t = worldMap[y][x];
    // Player can walk on grass, town, forest, desert, beach, swamp, and caves
    return t == 0 || t == 3 || t == 4 || t == 6 || t == 7 || t == 8 || t == 9; 
  }
  
  // Get biome type at position for enemy spawning
  String _getBiomeAt(int x, int y) {
    if (x < 0 || y < 0 || x >= worldWidth || y >= worldHeight) return 'grass';
    final t = worldMap[y][x];
    switch (t) {
      case 4: return 'forest';
      case 5: return 'mountain';
      case 6: return 'desert';
      case 7: return 'cave';
      case 8: return 'beach';
      case 9: return 'swamp';
      case 2: return 'water';
      default: return 'grass';
    }
  }

  void _onMove(int dx, int dy) {
    try {
      if (isPaused) {
        // Provide feedback when trying to move while paused
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Game is paused. Press the play button to resume.'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      if (inBattle) {
        // Provide feedback when trying to move during battle
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot move during battle.'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      
      // Prevent movement if already animating
      if (isMoving) return;
      
      // Ensure world is initialized
      if (worldMap.isEmpty) {
        _initializeWorld();
        return;
      }
      
      // Improved step throttle - allows faster movement with keyboard
      final now = DateTime.now();
      if (now.difference(lastStepAt).inMilliseconds < 50) return;
      lastStepAt = now;

      // Update facing direction based on movement
      if (dy < 0) {
        playerFacingDirection = 0; // Up
      } else if (dx > 0) {
        playerFacingDirection = 1; // Right
      } else if (dy > 0) {
        playerFacingDirection = 2; // Down
      } else if (dx < 0) {
        playerFacingDirection = 3; // Left
      }

      final nx = playerPos.x + dx;
      final ny = playerPos.y + dy;
      
      if (!_isWalkable(nx, ny)) {
        // Provide feedback when trying to move to unwalkable tile
        if (GameSettings.hapticsEnabled) {
          HapticFeedback.lightImpact();
        }
        return;
      }
      
      // Check if there's an enemy at the new position
      MapEnemy? enemyAtPos;
      try {
        enemyAtPos = mapEnemies.firstWhere(
          (e) => e.position.x == nx && e.position.y == ny,
        );
      } catch (e) {
        // No enemy at this position
        enemyAtPos = null;
      }
      
      // If found an enemy at this position
      if (enemyAtPos != null) {
        // Start battle with this enemy
        currentEnemy = enemyAtPos.enemy;
        mapEnemies.remove(enemyAtPos); // Remove from map
        inExploreBattle = true;
        _spawnEnemy(); // This will set up the battle properly
        setState(() {
          inBattle = true;
          gameStatus = 'Wild ${currentEnemy.name} appeared!';
        });
        if (GameSettings.hapticsEnabled) HapticFeedback.mediumImpact();
        return;
      }
      
      // Smooth movement animation
      setState(() {
        isMoving = true;
        targetPlayerPos = Point(nx, ny);
        playerVisualOffset = Offset.zero; // Reset offset
      });
      
      // Start movement animation
      _movementController.forward(from: 0);
      
      // Haptic feedback for successful movement
      if (GameSettings.hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
      
      // Keep old random encounter system as backup (lower chance)
      // But primary method is now visible enemies
      // Random encounters are more common in dangerous biomes
      final biome = _getBiomeAt(nx, ny);
      double encounterChance = 0.01; // Base 1% chance
      if (biome == 'forest') encounterChance = 0.02;
      if (biome == 'swamp' || biome == 'cave') encounterChance = 0.03;
      
      if (ny >= 0 && ny < worldMap.length && 
          nx >= 0 && nx < worldMap[ny].length &&
          (worldMap[ny][nx] == 4 || worldMap[ny][nx] == 9 || worldMap[ny][nx] == 7) && 
          combatEngine.rng.nextDouble() < encounterChance) {
        // Random encounter in dangerous areas - delay to allow movement animation
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted && !inBattle) {
            inExploreBattle = true;
            _spawnEnemy();
            setState(() {
              inBattle = true;
              gameStatus = 'A wild ${currentEnemy.name} appeared!';
            });
            if (GameSettings.hapticsEnabled) HapticFeedback.mediumImpact();
          }
        });
      }
    } catch (e) {
      // Handle any errors silently but ensure state is updated
      debugPrint('Error in _onMove: $e');
      if (mounted) {
        setState(() {
          isMoving = false;
        });
      }
    }
  }
  
  // Handle keyboard input for movement
  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && !isPaused && !inBattle) {
      final logicalKey = event.logicalKey;
      
      // Arrow keys and WASD support
      if (logicalKey == LogicalKeyboardKey.arrowUp || logicalKey == LogicalKeyboardKey.keyW) {
        _onMove(0, -1);
      } else if (logicalKey == LogicalKeyboardKey.arrowDown || logicalKey == LogicalKeyboardKey.keyS) {
        _onMove(0, 1);
      } else if (logicalKey == LogicalKeyboardKey.arrowLeft || logicalKey == LogicalKeyboardKey.keyA) {
        _onMove(-1, 0);
      } else if (logicalKey == LogicalKeyboardKey.arrowRight || logicalKey == LogicalKeyboardKey.keyD) {
        _onMove(1, 0);
      } else if (logicalKey == LogicalKeyboardKey.space || logicalKey == LogicalKeyboardKey.keyE) {
        // Interact on space/E key
        _interact();
      }
    }
  }


  void _interact() {
    // Check for NPC on current or adjacent tile
    List<Point<int>> check = [
      playerPos,
      Point(playerPos.x + 1, playerPos.y),
      Point(playerPos.x - 1, playerPos.y),
      Point(playerPos.x, playerPos.y + 1),
      Point(playerPos.x, playerPos.y - 1),
    ];
    for (final p in check) {
      if (npcDialogue.containsKey(p)) {
        final text = npcDialogue[p]!;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Townsperson'),
            content: Text(text),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
              if (worldMap[playerPos.y][playerPos.x] == 3)
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openShop();
                  },
                  child: const Text('Shop'),
                ),
            ],
          ),
        );
        return;
      }
    }

    // If in town center, offer shop
    if (worldMap[playerPos.y][playerPos.x] == 3) {
      _openShop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('There is nothing to interact with.')),
      );
    }
  }

  void _openShop() {
    final items = <Equipment>[
      Equipment(name: 'Bronze Sword', rarity: 'common', slot: 'weapon', atkBonus: 3),
      Equipment(name: 'Sturdy Vest', rarity: 'common', slot: 'armor', defBonus: 2, hpBonus: 10),
      Equipment(name: 'Oak Staff', rarity: 'rare', slot: 'weapon', atkBonus: 5),
    ];
    final offer = items[combatEngine.roll(items.length)];
    final price = offer.rarity == 'rare' ? 120 : 70;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Town Shop'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${offer.getRarityEmoji()} ${offer.name}'),
            const SizedBox(height: 8),
            Text('Price: $price gold'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: playerGold >= price
                ? () {
                    setState(() {
                      playerGold -= price;
                      equipment.add(offer);
                      _equipItem(offer);
                    });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Purchased ${offer.name}!')),
                    );
                  }
                : null,
            child: const Text('Buy'),
          ),
        ],
      ),
    );
  }
  
  /// Map pet emoji to 3D model type
  String _getPetType(String emoji) {
    const emojiToType = {
      '🐉': 'dragon',
      '🦊': 'fox',
      '🦅': 'eagle',
      '🐺': 'wolf',
      '✨': 'sparkle',
      '🐾': 'shadow',
    };
    return emojiToType[emoji] ?? 'dragon';
  }
  
  /// Get class icon emoji
  String _getClassIcon() {
    switch (playerClass) {
      case CharacterClass.warrior:
        return '⚔️';
      case CharacterClass.mage:
        return '🔮';
      case CharacterClass.rogue:
        return '🗡️';
      case CharacterClass.paladin:
        return '🛡️';
    }
  }
  
  /// Get class name
  String _getClassName() {
    switch (playerClass) {
      case CharacterClass.warrior:
        return 'Warrior';
      case CharacterClass.mage:
        return 'Mage';
      case CharacterClass.rogue:
        return 'Rogue';
      case CharacterClass.paladin:
        return 'Paladin';
    }
  }
  
  /// Show skills selection dialog
  void _showSkillsDialog() {
    final availableSkills = skills.where((s) => s.unlockLevel <= playerLevel).toList();
    
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
            maxWidth: 400,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.purple.shade900,
                Colors.purple.shade700,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.purple.shade300, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.shade800.withValues(alpha: 0.8),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select Skill',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Mana: $manaPoints/$maxMana',
                            style: TextStyle(
                              color: Colors.blue.shade200,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              // Skills list
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: availableSkills.length,
                  itemBuilder: (context, index) {
                    final skill = availableSkills[index];
                    final canUse = manaPoints >= skill.manaCost && !skill.isOnCooldown;
                    final elementColor = skill.element != ElementType.none 
                        ? _getElementColor(skill.element)
                        : Colors.grey.shade600;
                    
                    return GestureDetector(
                      onTap: canUse
                          ? () {
                              Navigator.pop(ctx);
                              _playerUseSkill(skill);
                            }
                          : null,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: canUse 
                              ? Colors.white.withValues(alpha: 0.95)
                              : Colors.grey.shade300.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: skill.isOnCooldown 
                                ? Colors.red.shade400
                                : (canUse ? elementColor : Colors.grey.shade400),
                            width: 2,
                          ),
                          boxShadow: canUse ? [
                            BoxShadow(
                              color: elementColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ] : null,
                        ),
                        child: Row(
                          children: [
                            // Skill icon
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: elementColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: elementColor, width: 2),
                              ),
                              child: Center(
                                child: Text(
                                  skill.icon,
                                  style: const TextStyle(fontSize: 28),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Skill info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          skill.name,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: canUse ? Colors.black87 : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                      if (skill.isUltimate)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.orange,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'ULTIMATE',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.water_drop, size: 14, color: Colors.blue.shade600),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${skill.manaCost} MP',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: canUse ? Colors.blue.shade800 : Colors.grey.shade600,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (skill.damage > 0) ...[
                                        const SizedBox(width: 12),
                                        const Icon(Icons.flash_on, size: 14, color: Colors.red),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${skill.damage} DMG',
                                          style: const TextStyle(fontSize: 12, color: Colors.red),
                                        ),
                                      ],
                                      if (skill.heal > 0) ...[
                                        const SizedBox(width: 12),
                                        const Icon(Icons.favorite, size: 14, color: Colors.green),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${skill.heal} HEAL',
                                          style: const TextStyle(fontSize: 12, color: Colors.green),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (skill.isOnCooldown)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        '⏱️ Cooldown: ${skill.cooldown} turns',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.red.shade700,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  if (!canUse && !skill.isOnCooldown)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        '❌ Not enough mana',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.red.shade700,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Show pet interaction dialog
  void _showPetInteractionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Text('${playerPet.emoji} ${playerPet.name}'),
            const Spacer(),
            Text(
              'Lv ${playerPet.level}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your loyal companion is happy to see you!'),
            const SizedBox(height: 16),
            if (playerPet.specialAbility != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '✨ Special Ability',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      playerPet.specialAbility!,
                      style: TextStyle(
                        color: Colors.purple.shade700,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Text('Happiness: $petHappiness%'),
            LinearProgressIndicator(
              value: petHappiness / 100,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation(Colors.pink.shade400),
            ),
          ],
        ),
        actions: [
          if (playerGold >= 50)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  playerGold -= 50;
                  petHappiness = min(100, petHappiness + 20);
                  playerPet.heal(10);
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${playerPet.name} is very happy! +20 happiness'),
                    backgroundColor: Colors.pink,
                  ),
                );
              },
              icon: const Icon(Icons.pets),
              label: const Text('Feed (50 gold)'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.pink,
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Character class system
enum CharacterClass {
  warrior,
  mage,
  rogue,
  paladin,
}

/// Damage number animation data
class DamageNumber {
  final int value;
  final Color color;
  final bool isCritical;
  final ElementType? element;
  final Offset position;
  final DateTime timestamp;

  DamageNumber({
    required this.value,
    required this.color,
    this.isCritical = false,
    this.element,
    required this.position,
    required this.timestamp,
  });
}

/// Enemy class
class Enemy {
  String name;
  int hp;
  int maxHp;
  int atk;
  int def;
  bool isBoss;
  String emoji;
  ElementType element;
  ElementType weakness;
  ElementType resistance;
  String? specialAbility;
  int specialAbilityCharges = 0;

  Enemy({
    required this.name,
    required this.hp,
    required this.maxHp,
    required this.atk,
    required this.def,
    this.isBoss = false,
    required this.emoji,
    this.element = ElementType.none,
    this.weakness = ElementType.none,
    this.resistance = ElementType.none,
    this.specialAbility,
  });

  factory Enemy.random({
    required String difficulty,
    required bool isBoss,
    required int playerLevel,
    String? biome,
  }) {
    // Regular enemies by biome
    final biomeEnemies = {
      'grass': [
        ('Goblin', '👹'),
        ('Orc', '💪'),
        ('Bandit', '🗡️'),
        ('Wolf', '🐺'),
        ('Rat', '🐭'),
      ],
      'forest': [
        ('Goblin', '👹'),
        ('Spider', '🕷️'),
        ('Troll', '👹'),
        ('Bear', '🐻'),
        ('Ent', '🌳'),
        ('Forest Guardian', '🦌'),
      ],
      'desert': [
        ('Desert Bandit', '🏜️'),
        ('Scorpion', '🦂'),
        ('Sand Worm', '🐛'),
        ('Cactus Monster', '🌵'),
        ('Djinn', '💨'),
        ('Camel Raider', '🐫'),
      ],
      'beach': [
        ('Crab', '🦀'),
        ('Seagull', '🪶'),
        ('Pirate', '🏴‍☠️'),
        ('Sea Serpent', '🌊'),
        ('Siren', '🧜'),
      ],
      'swamp': [
        ('Zombie', '🧟'),
        ('Swamp Thing', '🪱'),
        ('Leech', '🩸'),
        ('Bog Monster', '🌊'),
        ('Marsh Witch', '🧙'),
        ('Will-o-Wisp', '✨'),
      ],
      'cave': [
        ('Bat', '🦇'),
        ('Cave Troll', '🧌'),
        ('Shadow', '👤'),
        ('Mimic', '📦'),
        ('Crystal Golem', '💎'),
        ('Deep Dweller', '🕳️'),
      ],
      'mountain': [
        ('Mountain Goat', '🐐'),
        ('Yeti', '🧸'),
        ('Eagle', '🦅'),
        ('Stone Golem', '🗿'),
        ('Wyvern', '🐉'),
      ],
    };

    // Boss enemies by biome
    final biomeBosses = {
      'grass': [
        ('Dark Knight', '⚫'),
        ('Orc Warlord', '👹'),
        ('Bandit King', '👑'),
      ],
      'forest': [
        ('Ancient Ent', '🌳'),
        ('Forest Dragon', '🐉'),
        ('Nature Guardian', '🌿'),
      ],
      'desert': [
        ('Desert King', '🏜️'),
        ('Sand Dragon', '🐉'),
        ('Ancient Djinn', '💨'),
      ],
      'beach': [
        ('Kraken', '🐙'),
        ('Pirate Captain', '🏴‍☠️'),
        ('Sea Dragon', '🐲'),
      ],
      'swamp': [
        ('Lich King', '💀'),
        ('Swamp Dragon', '🐉'),
        ('Undead Lord', '🧟'),
      ],
      'cave': [
        ('Shadow Beast', '👤'),
        ('Deep Dragon', '🐉'),
        ('Crystal King', '💎'),
      ],
      'mountain': [
        ('Mountain Titan', '🗿'),
        ('Frost Dragon', '❄️'),
        ('Elder Yeti', '🧸'),
      ],
    };

    // Universal enemies (can appear anywhere)
    const universalEnemies = [
      ('Skeleton', '💀'),
      ('Ghost', '👻'),
      ('Gargoyle', '🦅'),
      ('Slime', '💧'),
      ('Wisp', '✨'),
      ('Golem', '🗿'),
      ('Harpy', '🦅'),
      ('Vampire Bat', '🦇'),
      ('Werewolf', '🐺'),
    ];

    // Universal bosses (can appear anywhere)
    const universalBosses = [
      ('Dragon', '🐉'),
      ('Demon Lord', '😈'),
      ('Ancient Mage', '🧙'),
      ('Phoenix', '🔥'),
      ('Leviathan', '🐳'),
      ('Titan', '🗿'),
      ('Hydra', '🐍'),
      ('Archangel', '👼'),
      ('Balrog', '🔥'),
    ];

    final random = Random();
    List<(String, String)> selectedEnemies;
    
    if (isBoss) {
      // 70% chance for biome-specific boss, 30% for universal
      if (biome != null && biomeBosses.containsKey(biome) && random.nextDouble() < 0.7) {
        selectedEnemies = List.from(biomeBosses[biome]!);
        // Mix in some universal bosses occasionally
        if (random.nextDouble() < 0.3) {
          selectedEnemies.addAll(universalBosses);
        }
      } else {
        selectedEnemies = List.from(universalBosses);
      }
    } else {
      // 60% chance for biome-specific enemy, 40% for universal/mixed
      if (biome != null && biomeEnemies.containsKey(biome) && random.nextDouble() < 0.6) {
        selectedEnemies = List.from(biomeEnemies[biome]!);
        // Mix in some universal enemies
        if (random.nextDouble() < 0.4) {
          selectedEnemies.addAll(universalEnemies);
        }
      } else {
        selectedEnemies = List.from(universalEnemies);
      }
    }

    final difficultyScale = _getDifficultyScale(difficulty);
    final (name, emoji) = selectedEnemies[random.nextInt(selectedEnemies.length)];

    int baseHp = isBoss ? 120 : 40;
    int baseAtk = isBoss ? 22 : 10;
    int baseDef = isBoss ? 10 : 4;

    // Exponential scaling for higher levels
    final hpMultiplier = 1.0 + (playerLevel * 0.2) * difficultyScale;
    final atkMultiplier = 1.0 + (playerLevel * 0.15) * difficultyScale;
    final defMultiplier = 1.0 + (playerLevel * 0.12) * difficultyScale;

    final scaledHp = (baseHp * hpMultiplier).toInt();
    final scaledAtk = (baseAtk * atkMultiplier).toInt();
    final scaledDef = (baseDef * defMultiplier).toInt();

    // Assign elemental types and weaknesses based on enemy type
    ElementType element = ElementType.none;
    ElementType weakness = ElementType.none;
    ElementType resistance = ElementType.none;
    String? specialAbility;

    if (name == 'Dragon' || name == 'Phoenix') {
      element = ElementType.fire;
      weakness = ElementType.ice;
      resistance = ElementType.fire;
      specialAbility = 'Fire Breath';
    } else if (name == 'Ghost' || name == 'Shadow Beast') {
      element = ElementType.dark;
      weakness = ElementType.holy;
      resistance = ElementType.dark;
      specialAbility = 'Shadow Strike';
    } else if (name == 'Skeleton' || name == 'Lich King') {
      element = ElementType.dark;
      weakness = ElementType.holy;
      specialAbility = 'Bone Shield';
    } else if (name == 'Leviathan') {
      element = ElementType.ice;
      weakness = ElementType.lightning;
      resistance = ElementType.ice;
      specialAbility = 'Tidal Wave';
    } else if (name == 'Spider') {
      element = ElementType.poison;
      weakness = ElementType.fire;
    } else if (name == 'Vampire Bat' || name == 'Wisp') {
      element = ElementType.dark;
      weakness = ElementType.holy;
    } else if (name == 'Slime' || name == 'Golem') {
      element = ElementType.none;
      weakness = ElementType.lightning;
      resistance = ElementType.poison;
    } else if (name == 'Harpy') {
      element = ElementType.lightning;
      weakness = ElementType.ice;
    } else if (name == 'Titan' || name == 'Gargoyle') {
      element = ElementType.none;
      weakness = ElementType.lightning;
      resistance = ElementType.fire;
      specialAbility = 'Stone Armor';
    } else if (name == 'Hydra') {
      element = ElementType.poison;
      weakness = ElementType.fire;
      specialAbility = 'Regeneration';
    } else if (name == 'Archangel') {
      element = ElementType.holy;
      weakness = ElementType.dark;
      resistance = ElementType.holy;
      specialAbility = 'Divine Strike';
    } else if (name == 'Balrog') {
      element = ElementType.fire;
      weakness = ElementType.ice;
      resistance = ElementType.fire;
      specialAbility = 'Hellfire';
    }

    return Enemy(
      name: '$emoji $name (Lv$playerLevel)',
      hp: scaledHp,
      maxHp: scaledHp,
      atk: scaledAtk,
      def: scaledDef,
      isBoss: isBoss,
      emoji: emoji,
      element: element,
      weakness: weakness,
      resistance: resistance,
      specialAbility: specialAbility,
    );
  }

  static double _getDifficultyScale(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return 0.6;
      case 'hard':
        return 1.4;
      default:
        return 1.0;
    }
  }
}
