# Claude Code Guidelines for Shiata

**Premium experience standards**: This is not a quickly-hacked-together app. Every feature must be tight, clean, and congruent. Follow established patterns religiously.

## Core Principles

1. **Consistency is king**: Users recognize visual patterns (colors, icons) better than text
2. **No half-measures**: Clipboard-only exports, incomplete flows = bad UX
3. **Follow the pattern**: If a pattern exists, use it everywhere - no exceptions
4. **Show, don't hide**: File paths, actions, state changes - make them visible

## Workflow

### Branch Management
- **Start from master**: Create new branches from current master each session
- **Branch naming**: `claude/<description>-<session-id>`
- **Push when complete**: All changes to feature branch

### Development Cycle
1. User tests → User updates master → New branch → Implement → User tests → Repeat

## Code Style

### List Items (MANDATORY PATTERN)
**ALL list items** (display or selection) must follow this pattern:

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

**Why**: Users recognize items by visual patterns, not text. Consistency across all pages is critical.

### Edit Dialogs
- **Two save buttons**: "Save" (OutlinedButton) + "Save & Close" (FilledButton)
- **Cancel**: TextButton

### Navigation
- **Section-based**: Use `currentSectionProvider` - NO `Navigator.push` for main sections
- **Bottom bar**: Always visible
- **ViewMode**: Persists across section switches

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

## Common Pitfalls

### ❌ DON'T
- Use different list styles across pages
- Use clipboard-only for file exports
- Hardcode units, colors, or icons
- Use `Navigator.push` for main sections
- Show generic labels instead of actual names

### ✅ DO
- Use the established list item pattern everywhere
- Show full file paths or let user choose location
- Extract metadata from actual data sources
- Use section-based navigation
- Display actual item names from payloadJson

## File Exports

**Rule**: Users must know where files are saved or choose the location themselves.

Good patterns:
1. Save to file → Show dialog with **full path**
2. Show JSON dialog → User copies and saves where they want

Bad patterns:
- ❌ "Saved to backup.json" (where??)
- ❌ Clipboard-only (too many steps, users won't do it)

## Testing Checklist

Before marking complete:
- [ ] All sections accessible via bottom bar
- [ ] List items match established pattern (colors, icons, Card layout)
- [ ] File operations show full paths
- [ ] Names/units extracted correctly (not hardcoded)
- [ ] Navigation works without stack buildup
- [ ] Edit dialogs have Save + Save & Close

## Version Management

- Update `pubspec.yaml` version
- Update `CHANGELOG.md` with categories: Added, Changed, Fixed, Technical
- Format: `## [X.Y.Z] - YYYY-MM-DD`

