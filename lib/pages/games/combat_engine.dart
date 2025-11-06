import 'seeded_rng.dart';

// Minimal dependency on game code: we only reference ElementType by name
// The RPG file declares ElementType; to avoid import cycles, callers pass ints

/// Deterministic combat helpers and RNG access
class CombatEngine {
  final SeededRandom rng;

  CombatEngine({required int seed}) : rng = SeededRandom(seed);

  int roll(int maxExclusive) => rng.nextInt(maxExclusive);

  bool rollPercent(int percent) => rng.rollPercent(percent);

  /// Returns a multiplier for elemental interactions.
  /// attackElement and defendElement are ordinal indices of ElementType enum.
  double elementalMultiplier({required int attackElement, required int defendElement}) {
    // Simple sample chart; caller can supply resistances separately as needed
    if (attackElement == defendElement && attackElement != 0) {
      return 0.75; // same element resists slightly
    }
    // Fire > Ice, Ice > Lightning, Lightning > Water(poison here), Holy > Dark, Dark > Holy
    const fire = 1, ice = 2, lightning = 3, poison = 4, holy = 5, dark = 6;
    if ((attackElement == fire && defendElement == ice) ||
        (attackElement == ice && defendElement == lightning) ||
        (attackElement == lightning && defendElement == poison) ||
        (attackElement == holy && defendElement == dark) ||
        (attackElement == dark && defendElement == holy)) {
      return 1.25;
    }
    return 1.0;
  }

  int applyCrit(int baseDamage, {required int critChancePercent, double critMultiplier = 1.5}) {
    if (rollPercent(critChancePercent)) {
      return (baseDamage * critMultiplier).round();
    }
    return baseDamage;
  }
}


