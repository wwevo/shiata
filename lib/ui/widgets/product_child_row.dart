import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repo/entries_repository.dart';
import '../../domain/widgets/registry.dart';

class ProductChildRow extends ConsumerWidget {
  const ProductChildRow({super.key, required this.entry, required this.registry});
  final EntryRecord entry;
  final WidgetRegistry registry;
  String _formatAmount(Map<String, dynamic> map) {
    double? amount = (map['amount'] as num?)?.toDouble();
    final unitFromPayload = map['unit'] as String?; // optional
    if (amount == null) return '—';
    // derive a unit from kind registry when absent
    final kind = registry.byId(entry.widgetKind);
    final unit = unitFromPayload ?? kind?.unit ?? '';
    // Format: show 2 decimals for values < 1, otherwise 0 decimals
    final text = amount < 1
        ? amount.toStringAsFixed(2)
        : amount.toStringAsFixed(0);
    return unit.isEmpty ? text : '$text $unit';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = registry.byId(entry.widgetKind);
    final color = kind?.accentColor ?? Theme.of(context).colorScheme.onSurfaceVariant;
    final icon = kind?.icon ?? Icons.circle;
    String value = '—';
    try {
      final map = jsonDecode(entry.payloadJson) as Map<String, dynamic>;
      value = _formatAmount(map);
    } catch (_) {}
    // Trim trailing zeros for doubles
    String trimD(String s) => s.replaceFirst(RegExp(r'\.?0+$'), '');
    value = trimD(value);
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      leading: CircleAvatar(backgroundColor: color, foregroundColor: Colors.white, child: Icon(icon, size: 16)),
      title: Text(kind?.displayName ?? entry.widgetKind),
      trailing: Text(value, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
