# Claude Code Guidelines for Shiata

**Premium experience standards**: Clean, tight, congruent. Follow established patterns.

## Core Principles

1. **NEVER invent APIs**: Always read existing code. NEVER create fake services, methods, or constructors that don't exist. Use Read/Grep tools extensively.
2. **Consistency is king**: Users recognize visual patterns (colors, icons) better than text
3. **Follow the pattern**: If a pattern exists, use it everywhere
4. **Show, don't hide**: File paths, actions, state changes - make them visible

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

## Testing

**Tests are living documentation**: They must always reflect current behavior.

### Test Maintenance (CRITICAL)
- **WHEN**: Any service, repository, or business logic changes
- **WHAT**: Update corresponding tests IMMEDIATELY
- **WHY**: Broken tests = broken trust. Green tests that test wrong behavior are worse than no tests.

### Test Format (Scientific Method)
All tests must follow this structure:
```dart
print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
print('TEST: Description of what is being tested');
print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

// Setup code...

print('INIT:     What was created/initial state');
print('ACTION:   What operation was performed');
print('EXPECTED: What should happen');
print('ACTUAL:   What actually happened\n');

// Assertions...

print('RESULT:   ✅ PASS or ❌ FAIL - Why it passed/failed');
print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
```

### Running Tests
```bash
flutter test test/propagation_test.dart  # Run specific test file
flutter test                              # Run all tests
```

## Version Management

- Update `pubspec.yaml` version
- Update `CHANGELOG.md` with categories: Added, Changed, Fixed, Technical
- Format: `## [X.Y.Z] - YYYY-MM-DD`
