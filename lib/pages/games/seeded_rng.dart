import 'dart:math';

/// Seedable RNG wrapper to enable deterministic simulations and tests
class SeededRandom {
  final Random _random;

  SeededRandom(int seed) : _random = Random(seed);

  int nextInt(int max) => _random.nextInt(max);

  double nextDouble() => _random.nextDouble();

  bool rollPercent(int percent) {
    if (percent <= 0) return false;
    if (percent >= 100) return true;
    return nextInt(100) < percent;
  }
}


