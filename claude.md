# Claude Code Guidelines for Shiata

**Premium experience standards**: Clean, tight, congruent. Follow established patterns.

## Core Principles

1. **Consistency is king**: Users recognize visual patterns (colors, icons) better than text
2. **Follow the pattern**: If a pattern exists, use it everywhere
3. **Show, don't hide**: File paths, actions, state changes - make them visible

## Key Patterns

### List Items (MANDATORY)
**ALL list items** must follow this pattern:

```dart
Card(
  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  child: ListTile(
    leading: CircleAvatar(
      backgroundColor: color,  // Item's actual color
      foregroundColor: Colors.white,
      child: Icon(icon, color: Colors.white),  // Item's actual icon
    ),
    title: Text(item.name),
    subtitle: Text('relevant • metadata'),
    trailing: /* Checkbox OR Row(Edit, Delete) */,
  ),
)
```

**Standard colors/icons:**
- **Kinds**: Use kind's own color and icon from metadata
- **Products**: Purple (`Colors.purple`), basket (`Icons.shopping_basket`)
- **Recipes**: Recipe's color/icon if set, else brown (`Colors.brown`), menu (`Icons.restaurant_menu`)

### Edit Dialogs
- **Two save buttons**: "Save" (OutlinedButton) + "Save & Close" (FilledButton)
- **Cancel**: TextButton

### Navigation
- **Section-based**: Use `currentSectionProvider` - NO `Navigator.push` for main sections
- **Bottom bar**: Always visible

## Architecture

### State Management
- **Riverpod**: StateProvider for simple state, StreamBuilder for reactive data
- **Key providers**: `currentSectionProvider`, `viewModeProvider`, `searchQueryProvider`, `selectedDayProvider`

### File Organization
- `lib/ui/` - All UI (editors, pages, widgets)
- `lib/data/` - Repositories, services, database
- `lib/domain/` - Models and business logic

### Key Patterns
- **Names**: Extract from `payloadJson` using `jsonDecode`
- **Dates**: Store UTC milliseconds, display local
- **Units**: From kind metadata, never hardcode
- **Unit Normalization**: Convert mg→g (÷1000), µg→g (÷1000000) for pie chart proportions

## Version Management

- Update `pubspec.yaml` version
- Update `CHANGELOG.md` with categories: Added, Changed, Fixed, Technical
- Format: `## [X.Y.Z] - YYYY-MM-DD`
