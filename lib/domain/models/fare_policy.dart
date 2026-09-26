class FarePolicy {
  const FarePolicy._();

  static const int stepRwf = 100;
  static const int minRwf = 500;
  static const int maxRwf = 50000;
  static const int suggestedMinRwf = 800;

  static int normalize(int amount, {int minimum = minRwf}) {
    if (amount <= 0) return amount;
    return ((amount / stepRwf).round() * stepRwf)
        .clamp(minimum, maxRwf)
        .toInt();
  }
}
