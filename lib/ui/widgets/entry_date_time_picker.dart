import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/formatters.dart';
import '../editors/editor_form_support.dart';
import 'inline_time_picker.dart';

final entryTimePickerExpandedProvider = StateProvider<bool>((_) => true);

class EntryDateTimePicker extends ConsumerWidget {
  const EntryDateTimePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.showDateButton = true,
    this.title,
  });

  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final bool showDateButton;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(entryTimePickerExpandedProvider);

    return ExpansionTile(
      title: Text(title ?? 'When: ${fmtMonthDay(value)} · ${fmtTime(value)}'),
      initiallyExpanded: expanded,
      onExpansionChanged: (expanded) {
        ref.read(entryTimePickerExpandedProvider.notifier).state = expanded;
      },
      children: [
        if (showDateButton)
          OutlinedButton.icon(
            onPressed: () async {
              final date = await pickDate(context, value);
              if (date == null || !context.mounted) return;
              onChanged(
                DateTime(
                  date.year,
                  date.month,
                  date.day,
                  value.hour,
                  value.minute,
                ),
              );
            },
            icon: const Icon(Icons.calendar_today),
            label: Text(
              MaterialLocalizations.of(context).formatMediumDate(value),
            ),
          ),
        InlineTimePicker(
          initialTime: TimeOfDay.fromDateTime(value),
          onTimeChanged: (time) {
            onChanged(
              DateTime(
                value.year,
                value.month,
                value.day,
                time.hour,
                time.minute,
              ),
            );
          },
        ),
      ],
    );
  }
}
