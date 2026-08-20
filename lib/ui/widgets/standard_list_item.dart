import 'package:flutter/material.dart';

/// A standardized list item widget that follows the application's visual style.
/// It uses a Card + ListTile pattern for top-level items and a plain ListTile for nested items.
class StandardListItem extends StatelessWidget {
  final Widget leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isNested;
  final bool isSelected;
  final Color? tileColor;

  const StandardListItem({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.isNested = false,
    this.isSelected = false,
    this.tileColor,
  });

  @override
  Widget build(BuildContext context) {
    final listTile = ListTile(
      dense: isNested,
      visualDensity: VisualDensity.compact,
      contentPadding: EdgeInsets.symmetric(
        horizontal: isNested ? 0 : 12,
      ),
      onTap: onTap,
      onLongPress: onLongPress,
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      selected: isSelected,
      tileColor: tileColor,
    );

    if (isNested) {
      return listTile;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: listTile,
    );
  }
}
