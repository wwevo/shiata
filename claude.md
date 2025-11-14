# Claude Code Guidelines for Shiata

This document contains guidelines and best practices for working with Claude Code on the Shiata project.

## Workflow

### Branch Management
- **Always work from master**: Create new branches from the current master branch for each work session
- **Branch naming**: Use format `claude/<description>-<session-id>` (e.g., `claude/weekly-overview-018WndKAKB4iJCe6fLhV9fqY`)
- **Clean branches**: Each session should start with a clean branch from master, not continuing from previous session branches
- **Push when complete**: Push all changes to the feature branch when work is complete

### Development Cycle
1. User tests locally and updates master branch when satisfied
2. Create new feature branch from master for next task
3. Implement changes
4. User tests locally
5. User pushes to master when satisfied
6. Repeat for next task

## Code Style

### List Displays
All list pages (Products, Kinds, Recipes) should follow this consistent style:
- **Wrap in Card**: Each list item in a Card with `margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6)`
- **Leading icon**: CircleAvatar with appropriate color and icon
  - Products: purple basket (`Colors.purple`, `Icons.shopping_basket`)
  - Recipes: brown menu (`Colors.brown`, `Icons.restaurant_menu`)
  - Kinds: kind's accent color and icon from metadata
- **Non-clickable**: No `onTap` on the ListTile
- **Explicit actions**: Edit and Delete buttons in trailing section
- **Use ListView.builder**: Not ListView.separated

### Edit Dialogs
- **Two save buttons**: "Save" (keeps dialog open) and "Save & Close" (closes after save)
- **Save behavior**: Use `closeAfter` parameter to control dialog closure
- **Button styles**:
  - Cancel: TextButton
  - Save: OutlinedButton
  - Save & Close: FilledButton (primary action)

### Navigation
- **Section-based**: Use `currentSectionProvider` to switch between app sections
- **No Navigator.push**: For main sections (Calendar, Products, Kinds, Recipes)
- **ViewMode persistence**: Calendar section's overview/calendar state persists across section switches
- **Bottom bar**: Always visible, defined once at root level

## Architecture

### State Management
- **Riverpod**: Use StateProvider for simple state, StreamBuilder for reactive data
- **Providers**:
  - `currentSectionProvider`: Current app section (calendar, products, kinds, recipes)
  - `viewModeProvider`: Overview vs calendar view within calendar section
  - `searchQueryProvider`: Current search query
  - `selectedDayProvider`: Selected day for day details

### File Organization
- **UI**: `lib/ui/` - All UI components
  - `lib/ui/editors/` - Dialog editors for creating/editing entries
  - `lib/ui/kinds/` - Kinds page
  - `lib/ui/products/` - Products page
  - `lib/ui/recipes/` - Recipes page
  - `lib/ui/widgets/` - Reusable widgets
- **Data**: `lib/data/` - Repositories, services, database
- **Domain**: `lib/domain/` - Domain models and business logic

### Key Patterns
- **Product/Recipe names**: Extract from `payloadJson` using `jsonDecode`, not from kind metadata
- **Date handling**: Use `DateTime.toUtc().millisecondsSinceEpoch` for storage, convert to local for display
- **StreamBuilder**: Handle Map<DateTime, List<>> from `watchByDayRange`, flatten to list when needed
- **Unit display**: Extract units from kind metadata, never hardcode

## Common Pitfalls

### Navigation Issues
- ❌ Don't use Navigator.push for main sections
- ❌ Don't duplicate Scaffold/bottomNavigationBar in individual pages
- ✅ Use section-based navigation with providers

### Display Issues
- ❌ Don't show generic "Product" or "Recipe" labels
- ✅ Extract actual names from payloadJson: `map['name'] as String?`
- ❌ Don't hardcode units (e.g., always showing 'g')
- ✅ Get unit from kind metadata: `kind?.unit ?? ''`

### Date Range Issues
- ❌ Don't use exclusive end dates without adding 1 day
- ✅ Add `Duration(days: 1)` to include the end day: `today.add(const Duration(days: 1))`

## Testing Checklist

Before marking work complete:
- [ ] All main sections (Calendar, Products, Kinds, Recipes) accessible via bottom bar
- [ ] Bottom bar visible on all pages
- [ ] Navigation doesn't create stack buildup (no back button maze)
- [ ] Product/recipe names show correctly in all lists
- [ ] Search works in calendar mode
- [ ] Edit dialogs have both Save and Save & Close buttons
- [ ] Pie chart shows correct units (not always 'g')
- [ ] Today's entries appear in weekly overview
- [ ] Filter chips in overview actually filter the chart

## Version Management

- Update `pubspec.yaml` version for each release
- Update `CHANGELOG.md` with detailed changes organized by category:
  - Added: New features
  - Changed: Modifications to existing features
  - Fixed: Bug fixes
  - Technical: Implementation details
- Format: `## [X.Y.Z] - YYYY-MM-DD`
