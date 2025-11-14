import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repo/entries_repository.dart';
import '../../domain/widgets/registry.dart';
import '../main_screen_providers.dart';
import 'product_child_row.dart';

class NestedProductParentRow extends ConsumerWidget {
  const NestedProductParentRow({super.key, required this.entry, required this.registry, required this.children, required this.expandedSet});
  final EntryRecord entry;
  final WidgetRegistry registry;
  final List<EntryRecord> children;
  final Set<String> expandedSet;
  String _productTitleFromPayload(EntryRecord e) {
    try {
      final map = jsonDecode(e.payloadJson) as Map<String, dynamic>;
      final name = (map['name'] as String?) ?? 'Product';
      final grams = (map['grams'] as num?)?.toInt();
      if (grams != null) {
        return '$name • $grams g';
      }
      return name;
    } catch (_) {
      return 'Product';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpanded = expandedSet.contains(entry.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.only(left: 0, right: 0),
          onTap: () {
            final set = {...expandedSet};
            if (isExpanded) {
              set.remove(entry.id);
            } else {
              set.add(entry.id);
            }
            ref.read(expandedProductsProvider.notifier).state = set;
          },
          leading: const CircleAvatar(backgroundColor: Colors.purple, foregroundColor: Colors.white, child: Icon(Icons.shopping_basket, size: 16)),
          title: Text(_productTitleFromPayload(entry)),
          trailing: AnimatedRotation(
            turns: isExpanded ? 0.5 : 0.0,
            duration: const Duration(milliseconds: 120),
            child: const Icon(Icons.expand_more),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 52, right: 8, bottom: 8),
            child: Column(
              children: [
                for (final c in children) ProductChildRow(entry: c, registry: registry),
              ],
            ),
          ),
      ],
    );
  }
}
