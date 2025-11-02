# Main Screen - Aufgeteilte Dateien

Die große `main_screen.dart` (1927 Zeilen) wurde in 16 kleinere Dateien aufgeteilt:

## Hauptdatei
- `main_screen.dart` - Haupteinstiegspunkt mit MainScreen Widget (13 Zeilen)

## Provider
- `main_screen_providers.dart` - Alle Provider-Definitionen (Handedness, MiddleMode, etc.)

## Widgets (/widgets)
- `top_sheet_host.dart` - TopSheetHost Widget mit Animation und Drag-Logik
- `calendar_sheet.dart` - CalendarSheet Widget
- `month_calendar.dart` - MonthCalendar Widget mit Kalender-Grid
- `day_details_panel.dart` - DayDetailsPanel mit Entry-Liste und Delete-Logik
- `middle_panel.dart` - MiddlePanel mit Drag-Steuerung
- `bottom_controls.dart` - BottomControls mit Navigation und Menü
- `handle_bar.dart` - HandleBar Widget
- `nested_product_parent_row.dart` - NestedProductParentRow Widget
- `product_child_row.dart` - ProductChildRow Widget
- `search_results.dart` - SearchResults Widget
- `ad_hoc_kind.dart` - AdHocKind Klasse
- `create_action_sheet_content.dart` - CreateActionSheetContent Widget
- `action_sheet_helpers.dart` - Helper-Funktionen für ActionSheets

## Dialogs (/dialogs)
- `recipe_instantiate_dialog.dart` - RecipeInstantiateDialog Widget

## Änderungen
- **Keine Code-Änderungen**: Der Code ist identisch zum Original
- **Nur Aufteilung**: Code wurde in logische Dateien aufgeteilt
- **Imports hinzugefügt**: Jede Datei hat die notwendigen Imports

## Verwendung
Ersetzen Sie die alte `main_screen.dart` durch die neue und fügen Sie die Unterverzeichnisse `/widgets` und `/dialogs` hinzu.
