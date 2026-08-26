import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/main_screen_providers.dart';

/// Base class for any item that can appear in navigation or menus.
sealed class NavItem {
  final String id;
  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final SelectionCategory? selectionCategory;

  const NavItem({
    required this.id,
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.selectionCategory,
  });
}

/// A destination that renders a full-page widget in MainScreen.
class NavPageItem extends NavItem {
  final Widget Function(BuildContext context, WidgetRef ref) pageBuilder;
  final SelectionCategory Function(Ref ref)? categoryResolver;

  const NavPageItem({
    required super.id,
    required super.label,
    required super.icon,
    super.selectedIcon,
    super.selectionCategory,
    required this.pageBuilder,
    this.categoryResolver,
  });

  SelectionCategory resolveCategory(Ref ref) {
    if (categoryResolver != null) {
      return categoryResolver!(ref);
    }
    return selectionCategory ?? SelectionCategory.entries;
  }
}

/// A destination that triggers an action/dialog without navigating away.
class NavActionItem extends NavItem {
  final Future<void> Function(BuildContext context, WidgetRef ref) onTrigger;

  const NavActionItem({
    required super.id,
    required super.label,
    required super.icon,
    super.selectedIcon,
    super.selectionCategory,
    required this.onTrigger,
  });
}

/// A top-level bottom bar entry that expands into a submenu (MenuAnchor).
class NavGroupItem extends NavItem {
  final List<NavItem> children;

  const NavGroupItem({
    required super.id,
    required super.label,
    required super.icon,
    super.selectedIcon,
    super.selectionCategory,
    required this.children,
  });
}
