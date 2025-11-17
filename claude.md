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

## Code Quality & Linter Best Practices

### BuildContext Async Gaps (CRITICAL)
**Problem**: Using `BuildContext` after `await` causes warnings and potential bugs if widget is unmounted.

**Solutions**:
1. **Capture context-dependent objects BEFORE any await**:
```dart
Future<void> _save() async {
  // ✅ Capture FIRST, before any await
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);

  await someAsyncOperation();

  // ✅ Use captured objects after await
  if (!mounted) return;
  messenger.showSnackBar(SnackBar(content: Text('Saved')));
  navigator.pop();
}
```

2. **Use `context.mounted` when context is used immediately**:
```dart
await someAsyncOperation();
if (!context.mounted) return;  // ✅ Related check
await showDialog(context: context, ...);  // ✅ Safe to use
```

**Anti-patterns**:
```dart
// ❌ BAD: Capturing after await
await someAsyncOperation();
if (!mounted) return;  // Unrelated check
ScaffoldMessenger.of(context).showSnackBar(...);  // Warning!

// ❌ BAD: Using mounted instead of context.mounted
if (!mounted) return;  // Unrelated to context
await showDialog(context: context, ...);  // Warning!
```

### Deprecated Flutter APIs
**DropdownButtonFormField.value** (deprecated in Flutter 3.33+):
```dart
// ❌ BAD: Using deprecated 'value' parameter
DropdownButtonFormField<String>(
  value: _selected,
  onChanged: (v) => setState(() => _selected = v),
  decoration: InputDecoration(labelText: 'Select'),
)

// ✅ GOOD: Use DropdownButton with state management
DropdownButton<String>(
  value: _selected,
  hint: Text('Select'),
  isExpanded: true,
  onChanged: (v) => setState(() => _selected = v),
)
```

### Unused Variables & Imports
**Always investigate before removing**:
- Check if variable was planned for future use (see TODOs, comments)
- If truly unused, remove it
- For return values: Consider if they should be used for user feedback

**Example - Making variables useful**:
```dart
// ❌ Before: unused variable
int updatedCount = 0;
for (final item in items) {
  await update(item);
  updatedCount++;
}
// TODO: Show user feedback

// ✅ After: return for user feedback
Future<int> updateItems() async {
  int updatedCount = 0;
  for (final item in items) {
    await update(item);
    updatedCount++;
  }
  return updatedCount;  // Now useful!
}
```

### Type Checks & Null Safety
```dart
// ❌ BAD: Unnecessary type check
if (value is dynamic) { ... }  // Always true

// ❌ BAD: Dead null-aware operator
final unit = kind.unit ?? '';  // If kind.unit is non-nullable

// ✅ GOOD: Remove unnecessary operations
if (value != null) { ... }     // Only check what's actually nullable
final unit = kind?.unit ?? '';  // Use ?. if kind itself is nullable
```

### Code Style
```dart
// ❌ BAD: Multiple unnecessary underscores
separatorBuilder: (_, __) => Divider()

// ✅ GOOD: Meaningful or single underscore
separatorBuilder: (context, index) => Divider()
// or if truly unused:
separatorBuilder: (_, __) => Divider()  // But prefer meaningful names
```

### Library Documentation
```dart
// ❌ BAD: Dangling doc comment
/// This is a utility library.
///
/// It contains helper functions.

import 'package:flutter/material.dart';

// ✅ GOOD: Add library directive
/// This is a utility library.
///
/// It contains helper functions.
library;

import 'package:flutter/material.dart';
```

### Pre-commit Checklist
Before committing, ensure:
- [ ] Run `flutter analyze` - zero warnings
- [ ] Check all `context` usage after `await`
- [ ] No unused imports or variables (or documented why kept)
- [ ] No deprecated API usage
- [ ] All mounted checks use `context.mounted` when context follows

## Version Management

- Update `pubspec.yaml` version
- Update `CHANGELOG.md` with categories: Added, Changed, Fixed, Technical
- Format: `## [X.Y.Z] - YYYY-MM-DD`
