# Static Instance UI Indicators - Implementation Plan

**Ziel**: User soll sofort sehen, welche Entries static (frozen) oder dynamic (auto-update) sind.

---

## Visuelle Konzepte

### Option A: Badge/Icon (EMPFOHLEN)
**Pro**: Klar, kompakt, nicht invasiv
**Beispiel**:
```
┌─────────────────────────────────┐
│ 🔒 Smoothie • 250g • Protein... │ ← Static (Lock icon)
│    Banana (100g)                 │
│    Vitamin C (50mg)              │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│ 🔄 Smoothie • 250g • Protein... │ ← Dynamic (Sync icon)
│    Banana (100g)                 │
│    Vitamin C (50mg)              │
└─────────────────────────────────┘
```

Icons:
- Static: 🔒 `Icons.lock_outline` oder 📌 `Icons.push_pin`
- Dynamic: 🔄 `Icons.sync` oder 🔗 `Icons.link`

### Option B: Background Color
**Pro**: Sehr auffällig
**Con**: Kann mit theme colors konfligieren
**Beispiel**:
- Static: Leicht gräulicher Background
- Dynamic: Normaler Background

### Option C: Text Badge
**Pro**: Explizit, verständlich
**Con**: Nimmt mehr Platz
**Beispiel**:
```
Smoothie • 250g • [STATIC]
Smoothie • 250g • [SYNCED]
```

---

## Implementierungs-Orte

### 1. Day Details Panel (Kalender Tag-Ansicht)
**Datei**: `lib/ui/widgets/day_details_panel.dart`
**Zeilen**: ~180-200 (bei recipe title)

**Aktuell**:
```dart
subtitle: Text(_recipeTitleFromPayload(...))
```

**Neu**:
```dart
subtitle: Row(
  children: [
    if (e.isStatic)
      Icon(Icons.lock_outline, size: 14, color: Colors.grey),
    SizedBox(width: 4),
    Expanded(child: Text(_recipeTitleFromPayload(...))),
  ],
)
```

### 2. Weekly Overview Panel (7-Tage Übersicht)
**Datei**: `lib/ui/widgets/weekly_overview_panel.dart`
**Zeilen**: ~370-400 (recipe list items)

**Ähnlicher Ansatz**: Icon vor dem Text

### 3. Search Results
**Datei**: `lib/ui/widgets/search_results.dart`
**Zeilen**: ~100-150

**Ähnlicher Ansatz**: Icon in der ListTile

### 4. Product Instances (ebenfalls)
**Wichtig**: Products können auch static sein!
**Gleiche Behandlung** wie recipes.

---

## Implementierungs-Reihenfolge

### Phase 1: Helper Widget erstellen (REUSABLE)
**Datei**: `lib/ui/widgets/static_indicator.dart` (NEU)

```dart
import 'package:flutter/material.dart';

class StaticIndicator extends StatelessWidget {
  const StaticIndicator({
    super.key,
    required this.isStatic,
    this.size = 14,
  });

  final bool isStatic;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (!isStatic) return const SizedBox.shrink();

    return Tooltip(
      message: 'Static instance (won\'t auto-update)',
      child: Icon(
        Icons.lock_outline,
        size: size,
        color: Colors.grey.shade600,
      ),
    );
  }
}
```

**Verwendung**:
```dart
Row(
  children: [
    StaticIndicator(isStatic: entry.isStatic),
    const SizedBox(width: 4),
    Expanded(child: Text('...')),
  ],
)
```

### Phase 2: In Day Details Panel einbauen
**Datei**: `lib/ui/widgets/day_details_panel.dart`

### Phase 3: In Weekly Overview einbauen
**Datei**: `lib/ui/widgets/weekly_overview_panel.dart`

### Phase 4: In Search Results einbauen
**Datei**: `lib/ui/widgets/search_results.dart`

---

## Alternative: Kombiniert mit Text

```dart
class EntryTitle extends StatelessWidget {
  const EntryTitle({
    super.key,
    required this.title,
    required this.isStatic,
  });

  final String title;
  final bool isStatic;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isStatic) ...[
          Icon(Icons.lock_outline, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(
            title,
            style: isStatic
              ? TextStyle(color: Colors.grey.shade700)
              : null,
          ),
        ),
      ],
    );
  }
}
```

---

## Zusätzlich: Recipe Instance Editor Static Toggle

**Aktuell fehlt**: Recipe instances haben kein Static toggle
**Muss hinzugefügt werden**: In recipe instance editor

**Wo**: Analog zu Product Editor
**Datei**: Vermutlich `lib/ui/recipes/` (recipe instance editor dialog)

**Beispiel aus Product Editor** (`product_editor_dialog.dart:89-96`):
```dart
SwitchListTile(
  title: const Text('Static'),
  subtitle: const Text('Lock values, ignore template updates'),
  value: _isStatic,
  onChanged: (val) => setState(() => _isStatic = val),
)
```

**Wichtig**: Default sollte `false` sein (dynamic), nicht `true`!

---

## Schätzung

**Aufwand**:
- Helper widget: 15 min
- Day details panel: 15 min
- Weekly overview: 15 min
- Search results: 10 min
- Testing: 15 min

**Gesamt**: ~1 Stunde

**Priorität**: HOCH
- Ohne visual indicator kann user nicht sehen was static ist
- Ohne static toggle kann user keine dynamic recipe instances erstellen
- → Template propagation für recipes funktioniert derzeit nicht richtig!
