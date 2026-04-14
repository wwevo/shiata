import 'package:flutter/material.dart';

/// Resolves icon names to IconData.
/// Used across all pages for consistent icon handling.
IconData resolveIcon(String? name, IconData fallback) {
  switch (name) {
    case 'fitness_center':
      return Icons.fitness_center;
    case 'opacity':
      return Icons.opacity;
    case 'rice_bowl':
      return Icons.rice_bowl;
    case 'battery_charging_full':
      return Icons.battery_charging_full;
    case 'blur_on':
      return Icons.blur_on;
    case 'bolt':
      return Icons.bolt;
    case 'circle':
      return Icons.circle;
    case 'hexagon':
      return Icons.hexagon;
    case 'science':
      return Icons.science;
    case 'visibility':
      return Icons.visibility;
    case 'medical_information':
      return Icons.medical_information;
    case 'local_florist':
      return Icons.local_florist;
    case 'wb_sunny':
      return Icons.wb_sunny;
    case 'eco':
      return Icons.eco;
    case 'grass':
      return Icons.grass;
    default:
      return fallback;
  }
}
