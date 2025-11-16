import '../../domain/widgets/registry.dart';

/// Shared data structure for aggregated nutrient information.
/// Provides unit normalization and formatting for display.
class NutrientSummary {
  NutrientSummary({
    required this.totalProductGrams,
    required this.nutrientsByKind,
    required this.normalizedNutrients,
  });

  /// Total grams of all products in this summary
  final double totalProductGrams;

  /// Original nutrient amounts by kind ID (as stored in entries)
  final Map<String, double> nutrientsByKind;

  /// Normalized nutrient amounts (converted to grams for weight units)
  final Map<String, double> normalizedNutrients;

  /// Get top N nutrients sorted by normalized value (descending).
  /// Returns list of (kindId, originalAmount) tuples.
  List<(String, double)> getTopNutrients(int n) {
    final sorted = nutrientsByKind.entries.toList()
      ..sort((a, b) {
        final normA = normalizedNutrients[a.key] ?? 0.0;
        final normB = normalizedNutrients[b.key] ?? 0.0;
        return normB.compareTo(normA);
      });
    return sorted.take(n).map((e) => (e.key, e.value)).toList();
  }

  /// Format as string with labels: "250g • Protein: 30g • Vitamin C: 500mg"
  String format(WidgetRegistry registry, {int topN = 2}) {
    final parts = <String>[];

    // Add total product grams if > 0
    if (totalProductGrams > 0) {
      final formatted = totalProductGrams < 1
          ? totalProductGrams.toStringAsFixed(2)
          : totalProductGrams.toStringAsFixed(0);
      parts.add('${formatted}g');
    }

    // Add top N nutrients with labels
    final topNutrients = getTopNutrients(topN);
    for (final (kindId, amount) in topNutrients) {
      final kind = registry.byId(kindId);
      final kindName = kind?.displayName ?? kindId;
      final unit = kind?.unit ?? '';
      final formatted = amount < 1
          ? amount.toStringAsFixed(2)
          : amount.toStringAsFixed(0);
      parts.add('$kindName: $formatted$unit');
    }

    return parts.isEmpty ? '' : parts.join(' • ');
  }

  /// Create an empty summary
  static NutrientSummary empty() {
    return NutrientSummary(
      totalProductGrams: 0.0,
      nutrientsByKind: {},
      normalizedNutrients: {},
    );
  }

  /// Normalize a nutrient value to grams based on unit.
  /// mg -> g (÷1000), µg -> g (÷1000000), g -> g (no change)
  static double normalizeToGrams(double value, String unit) {
    switch (unit.toLowerCase()) {
      case 'mg':
        return value / 1000;
      case 'ug':
      case 'µg':
        return value / 1000000;
      default:
        return value;
    }
  }
}
