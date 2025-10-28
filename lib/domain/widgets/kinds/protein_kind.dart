import 'package:flutter/material.dart';

import '../../widgets/create_action.dart';
import '../../widgets/widget_kind.dart';
import '../../../ui/editors/protein_editor.dart';

class ProteinKind extends WidgetKind {
  const ProteinKind();

  @override
  String get id => 'protein';

  @override
  String get displayName => 'Protein';

  @override
  IconData get icon => Icons.fitness_center;

  @override
  Color get accentColor => Colors.indigo;

  @override
  List<CreateAction> createActions(BuildContext context, DateTime targetDate) {
    return [
      CreateAction(
        id: 'custom',
        label: 'Custom grams',
        icon: Icons.edit,
        priority: 10,
        color: accentColor,
        run: (ctx, date) async {
          // For now, navigate to the placeholder ProteinScreen. Later this will
          // open the real create editor with prefilled date/time.
          await Navigator.of(ctx).push(
            MaterialPageRoute(builder: (_) => const ProteinEditorScreen()),
          );
        },
      ),
    ];
  }
}
