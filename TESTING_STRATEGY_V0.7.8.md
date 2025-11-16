# Testing Strategy v0.7.8 - Children Management System

**Branch**: `claude/centralize-children-management-01LwN22cDGS78onRbs9CGUd2`
**Date**: 2025-11-16

---

## 🟢 Was ist JETZT testbar?

### Test 1: Schema Migration
**Status**: ✅ Ready
**Ziel**: App startet ohne Fehler, Migration läuft sauber

**Schritte**:
1. App starten
2. Prüfen: Keine DB-Fehler in Logs
3. Prüfen: Existierende Daten noch vorhanden

**Erwartetes Ergebnis**:
- App läuft normal
- `recipe_id` column wurde hinzugefügt (alte entries haben NULL, neue bekommen ID)

---

### Test 2: Neue Recipe Instances erhalten recipe_id
**Status**: ✅ Ready
**Ziel**: Neue recipe entries haben recipe_id gesetzt

**Schritte**:
1. Recipe template erstellen/öffnen
2. Recipe instance zum Kalender hinzufügen
3. DB prüfen: `SELECT id, recipe_id FROM entries WHERE widget_kind='recipe' ORDER BY created_at DESC LIMIT 5;`

**Erwartetes Ergebnis**:
- Neue entries haben `recipe_id` != NULL
- `recipe_id` entspricht dem Template-ID

---

### Test 3: Recipe Template Propagation (NON-STATIC)
**Status**: ✅ Ready
**Ziel**: Template-Änderungen werden zu non-static instances propagiert

**Setup**:
1. Recipe "smoothie" erstellen mit: 100g Banana, 50mg Vitamin C
2. 2x Recipe instances erstellen (beide NON-static, default)
3. Template ändern zu: 200g Banana, 100mg Vitamin C
4. Bei "Update existing entries?" → YES klicken

**Erwartetes Ergebnis**:
- Dialog fragt nach Propagation
- Nach YES: "Updated existing recipe instances" snackbar
- Beide instances zeigen neue Werte (200g Banana, 100mg Vitamin C)
- Undo funktioniert (restore alte Werte)

---

### Test 4: Recipe Template Propagation (STATIC überspringen)
**Status**: ⚠️ **PROBLEM** - Keine UI um static instances zu erstellen!
**Ziel**: Static instances werden NICHT aktualisiert

**Setup**:
1. Recipe template erstellen
2. 1x NON-static instance erstellen
3. 1x STATIC instance erstellen ⚠️ **GEHT NICHT - KEIN UI!**
4. Template ändern → propagieren

**Erwartetes Ergebnis**:
- Nur non-static instance wird aktualisiert
- Static instance bleibt unverändert

**Problem**:
- ❌ Recipe instances haben aktuell KEIN UI für static toggle
- ❌ Alle recipe instances sind derzeit static=true (hardcoded in RecipeService.createRecipeEntry)

---

### Test 5: Product Template Propagation
**Status**: ✅ Ready (existierte schon vorher)
**Ziel**: Product template changes propagieren

**Setup**:
1. Product "banana" erstellen mit: 5mg Vitamin C per 100g
2. 1x NON-static product instance (100g) erstellen
3. Template ändern zu: 10mg Vitamin C per 100g
4. Propagation bestätigen

**Erwartetes Ergebnis**:
- Product instance zeigt 10mg Vitamin C (statt 5mg)

---

### Test 6: Recursive Aggregation (Recipe → Product → Nutrients)
**Status**: ✅ Ready (wurde schon in v0.7.7 implementiert)
**Ziel**: Recipe summaries zeigen alle Nährstoffe (auch aus Products)

**Setup**:
1. Product "banana" mit: 10mg Vitamin C, 5g Protein
2. Recipe "smoothie" mit: 100g banana + 50mg extra Vitamin C
3. Recipe instance erstellen

**Erwartetes Ergebnis**:
- Recipe summary zeigt: "100g • Vitamin C: 60mg • Protein: 5g"
- (10mg aus banana + 50mg direkt = 60mg gesamt)

---

## 🔴 Was ist NICHT testbar?

### ❌ Static Toggle UI für Recipes
**Problem**: Recipe instances werden aktuell alle als static=true erstellt (hardcoded).
**Fehlt**:
- Toggle in Recipe Instance Editor (analog zu Product Instance Editor)
- Visuelle Anzeige ob instance static ist

### ❌ Reset to Template
**Problem**: Keine UI zum Zurücksetzen von static instances.
**Service existiert**: `RecipeHierarchyService.resetToTemplate()` und `ProductHierarchyService.resetToTemplate()`
**Fehlt**: Button in Instance Editors

### ❌ Visual Indicator für Static Instances
**Problem**: User sieht nicht, welche entries static sind.
**Fehlt**: Badge/Icon in:
- day_details_panel.dart
- weekly_overview_panel.dart
- Search results

---

## 📋 Empfohlene Test-Reihenfolge

### Phase A: Basis-Funktionalität (JETZT)
1. ✅ Test 1: Schema Migration
2. ✅ Test 2: recipe_id wird gesetzt
3. ✅ Test 3: Recipe template propagation (alle instances sind static, also KEINER sollte updaten!)
4. ✅ Test 5: Product template propagation
5. ✅ Test 6: Recursive aggregation

### Phase B: Static Toggle UI hinzufügen (NEXT)
1. Recipe Instance Editor: Static toggle (analog zu Product)
2. Test 4 wiederholen: Static vs non-static propagation

### Phase C: Visual Indicators (LATER)
1. Badge/Icon für static instances
2. Reset-to-template button

---

## 🐛 Bekannte Probleme

### Problem 1: Alle Recipe Instances sind static
**Datei**: `lib/data/repo/recipe_service.dart:40`
**Code**:
```dart
final parent = await entries.create(
  widgetKind: 'recipe',
  // ...
  isStatic: true,  // ⚠️ HARDCODED!
);
```

**Auswirkung**:
- Template propagation funktioniert NICHT für recipes
- Alle recipe instances werden übersprungen (weil static)

**Fix**:
- Recipe instance editor braucht static toggle
- Default sollte `false` sein (wie bei products)

### Problem 2: Keine UI für Static Toggle bei Recipes
**Fehlt**: Analog zu `product_editor_dialog.dart` Zeile 89-96

**Wo**: `lib/ui/recipes/` - recipe instance editor

---

## 🎯 Kritische Sofort-Tests

**Vor allem anderen**: Prüfen ob die App überhaupt noch startet!

```bash
# Test starten
flutter run
```

**Checklist**:
- [ ] App startet ohne Fehler
- [ ] Keine DB migration errors in logs
- [ ] Bestehende entries noch sichtbar
- [ ] Neue recipe instance erstellen funktioniert
- [ ] Recipe template editor öffnet sich
- [ ] Product template editor funktioniert noch

**Wenn das funktioniert**:
→ Schema migration ist OK ✅

**Wenn Fehler**:
→ Logs teilen, dann fixen wir das sofort!

---

## 🤖 AUTOMATISIERTE TESTS (NEU!)

**Datei**: `test/propagation_test.dart`

Alle manuellen Tests sind jetzt automatisiert! Run mit:
```bash
flutter test test/propagation_test.dart
```

### Test Coverage

1. ✅ **Product template propagation**
   - Dynamic instances update
   - Static instances unchanged
   - Small values NOT nulled (regression test)

2. ✅ **Recipe template propagation**
   - Dynamic instances update
   - Static instances unchanged
   - Recursive propagation (recipe → product → nutrients)

3. ✅ **Schema verification**
   - recipe_id column populated
   - listParentsByRecipeId works

### Vorteile

- **Schnell**: Alle Tests in ~2 Sekunden
- **Reproduzierbar**: Gleiche Ergebnisse jeden Run
- **Regression-Schutz**: Bugs wie integer division (~/) werden sofort gefangen
- **CI-Ready**: Kann in GitHub Actions laufen

---

## 📊 Test-Ergebnisse (LEER - zum Ausfüllen)

### Manuelle Tests (optional, nach automatisierten Tests)

| Test | Status | Notizen |
|------|--------|---------|
| Test 1: Schema Migration | ⬜ | |
| Test 2: recipe_id gesetzt | ⬜ | |
| Test 3: Recipe propagation | ⬜ | |
| Test 5: Product propagation | ⬜ | |
| Test 6: Recursive aggregation | ⬜ | |

Legende: ✅ Pass | ❌ Fail | ⬜ Not tested

**Hinweis**: Automatisierte Tests (`flutter test`) sind jetzt verfügbar und sollten zuerst laufen!
