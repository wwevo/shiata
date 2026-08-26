import 'dart:math' as math;

import 'package:flutter/material.dart';

enum _TimePickerMode { hour, minute }

/// An inline time picker using direct interactive dials and digital numbers.
/// Operates in-place without triggering any popup dialogs.
class InlineTimePicker extends StatefulWidget {
  const InlineTimePicker({
    super.key,
    required this.initialTime,
    required this.onTimeChanged,
    this.use24HourFormat = true,
  });

  final TimeOfDay initialTime;
  final ValueChanged<TimeOfDay> onTimeChanged;
  final bool use24HourFormat;

  @override
  State<InlineTimePicker> createState() => _InlineTimePickerState();
}

class _InlineTimePickerState extends State<InlineTimePicker> {
  late int _hour;
  late int _minute;
  _TimePickerMode _mode = _TimePickerMode.hour;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
  }

  @override
  void didUpdateWidget(covariant InlineTimePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTime != widget.initialTime) {
      _hour = widget.initialTime.hour;
      _minute = widget.initialTime.minute;
    }
  }

  void _notifyChange() {
    final newTime = TimeOfDay(hour: _hour, minute: _minute);
    widget.onTimeChanged(newTime);
  }

  void _setHour(int h) {
    setState(() {
      _hour = (h % 24 + 24) % 24;
    });
    _notifyChange();
  }

  void _setMinute(int m) {
    setState(() {
      _minute = (m % 60 + 60) % 60;
    });
    _notifyChange();
  }

  void _adjustHours(int delta) {
    _setHour(_hour + delta);
  }

  void _adjustMinutes(int delta) {
    _setMinute(_minute + delta);
  }

  void _setToNow() {
    final now = TimeOfDay.now();
    setState(() {
      _hour = now.hour;
      _minute = now.minute;
    });
    _notifyChange();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hourStr = _hour.toString().padLeft(2, '0');
    final minuteStr = _minute.toString().padLeft(2, '0');

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with digital time numbers and Mode selector
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Hour digital selector
                _DigitalSegment(
                  value: hourStr,
                  label: 'Hour',
                  isSelected: _mode == _TimePickerMode.hour,
                  onTap: () => setState(() => _mode = _TimePickerMode.hour),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    ':',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                // Minute digital selector
                _DigitalSegment(
                  value: minuteStr,
                  label: 'Minute',
                  isSelected: _mode == _TimePickerMode.minute,
                  onTap: () => setState(() => _mode = _TimePickerMode.minute),
                ),
                const SizedBox(width: 12),
                // Quick "Now" button
                IconButton.filledTonal(
                  tooltip: 'Current Time',
                  icon: const Icon(Icons.access_time_filled, size: 20),
                  onPressed: _setToNow,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Quick adjuster buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _QuickAdjustButton(
                  label: '-1h',
                  onPressed: () => _adjustHours(-1),
                ),
                const SizedBox(width: 4),
                _QuickAdjustButton(
                  label: '+1h',
                  onPressed: () => _adjustHours(1),
                ),
                const SizedBox(width: 10),
                _QuickAdjustButton(
                  label: '-15m',
                  onPressed: () => _adjustMinutes(-15),
                ),
                const SizedBox(width: 4),
                _QuickAdjustButton(
                  label: '+15m',
                  onPressed: () => _adjustMinutes(15),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Interactive Radial Dial
            SizedBox(
              height: 170,
              width: 170,
              child: _ClockDial(
                mode: _mode,
                hour: _hour,
                minute: _minute,
                onHourSelected: (h) {
                  _setHour(h);
                  // Auto-switch to minute when hour selected via dial
                  setState(() => _mode = _TimePickerMode.minute);
                },
                onMinuteSelected: (m) {
                  _setMinute(m);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DigitalSegment extends StatelessWidget {
  const _DigitalSegment({
    required this.value,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String value;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAdjustButton extends StatelessWidget {
  const _QuickAdjustButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 28,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(36, 28),
          textStyle: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

class _ClockDial extends StatelessWidget {
  const _ClockDial({
    required this.mode,
    required this.hour,
    required this.minute,
    required this.onHourSelected,
    required this.onMinuteSelected,
  });

  final _TimePickerMode mode;
  final int hour;
  final int minute;
  final ValueChanged<int> onHourSelected;
  final ValueChanged<int> onMinuteSelected;

  void _handleTouch(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;

    // Angle in radians from 12 o'clock clockwise
    var angle = math.atan2(dy, dx) + (math.pi / 2);
    if (angle < 0) {
      angle += 2 * math.pi;
    }

    final dist = math.sqrt(dx * dx + dy * dy);
    final radius = size.width / 2;

    if (mode == _TimePickerMode.hour) {
      // 12 sectors on clock dial
      final sector = (angle / (2 * math.pi / 12)).round() % 12;
      final baseHour = sector == 0 ? 12 : sector;
      // If tapped in inner half of circle (dist < radius * 0.65), select 24h inner ring (13..00)
      if (dist < radius * 0.62) {
        final innerHour = (baseHour % 12) + 12; // 12 -> 0, 1 -> 13, ...
        onHourSelected(innerHour % 24);
      } else {
        // Outer ring: if hour currently >= 12 and tapped outer ring, keep AM/PM or use 1..12
        final isPm = hour >= 12;
        final selected = isPm ? (baseHour % 12) + 12 : (baseHour % 12);
        onHourSelected(selected % 24);
      }
    } else {
      // Minute mode: 60 sectors
      final m = (angle / (2 * math.pi / 60)).round() % 60;
      onMinuteSelected(m);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (details) => _handleTouch(details.localPosition, size),
          onPanUpdate: (details) => _handleTouch(details.localPosition, size),
          child: CustomPaint(
            size: size,
            painter: _ClockDialPainter(
              mode: mode,
              hour: hour,
              minute: minute,
              colorScheme: colorScheme,
              textTheme: theme.textTheme,
            ),
          ),
        );
      },
    );
  }
}

class _ClockDialPainter extends CustomPainter {
  _ClockDialPainter({
    required this.mode,
    required this.hour,
    required this.minute,
    required this.colorScheme,
    required this.textTheme,
  });

  final _TimePickerMode mode;
  final int hour;
  final int minute;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = colorScheme.surfaceContainerHigh
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // Center pivot dot
    final pivotPaint = Paint()
      ..color = colorScheme.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, pivotPaint);

    if (mode == _TimePickerMode.hour) {
      _paintHourDial(canvas, center, radius);
    } else {
      _paintMinuteDial(canvas, center, radius);
    }
  }

  void _paintHourDial(Canvas canvas, Offset center, double radius) {
    final handPaint = Paint()
      ..color = colorScheme.primary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final outerRadius = radius * 0.78;
    final normHour = hour % 12;
    final angle = (normHour * 30 - 90) * (math.pi / 180);

    final handTarget = Offset(
      center.dx + outerRadius * math.cos(angle),
      center.dy + outerRadius * math.sin(angle),
    );

    // Draw hand
    canvas.drawLine(center, handTarget, handPaint);

    // Draw indicator circle around selected number
    final indicatorPaint = Paint()
      ..color = colorScheme.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(handTarget, 14, indicatorPaint);

    // Draw 12 clock numbers
    for (int i = 1; i <= 12; i++) {
      final numAngle = (i * 30 - 90) * (math.pi / 180);
      final numOffset = Offset(
        center.dx + outerRadius * math.cos(numAngle),
        center.dy + outerRadius * math.sin(numAngle),
      );

      final isSelected = (i % 12) == (hour % 12);
      final textSpan = TextSpan(
        text: i.toString(),
        style: textTheme.labelSmall?.copyWith(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        numOffset - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  void _paintMinuteDial(Canvas canvas, Offset center, double radius) {
    final handPaint = Paint()
      ..color = colorScheme.primary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final outerRadius = radius * 0.78;
    final angle = (minute * 6 - 90) * (math.pi / 180);

    final handTarget = Offset(
      center.dx + outerRadius * math.cos(angle),
      center.dy + outerRadius * math.sin(angle),
    );

    // Draw hand
    canvas.drawLine(center, handTarget, handPaint);

    // Indicator circle
    final indicatorPaint = Paint()
      ..color = colorScheme.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(handTarget, 14, indicatorPaint);

    // Draw minute markers (every 5 minutes: 00, 05, 10 ... 55)
    for (int i = 0; i < 60; i += 5) {
      final numAngle = (i * 6 - 90) * (math.pi / 180);
      final numOffset = Offset(
        center.dx + outerRadius * math.cos(numAngle),
        center.dy + outerRadius * math.sin(numAngle),
      );

      final isSelected = (minute / 5).round() * 5 % 60 == i;
      final textSpan = TextSpan(
        text: i.toString().padLeft(2, '0'),
        style: textTheme.labelSmall?.copyWith(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        numOffset - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ClockDialPainter oldDelegate) {
    return oldDelegate.mode != mode ||
        oldDelegate.hour != hour ||
        oldDelegate.minute != minute ||
        oldDelegate.colorScheme != colorScheme;
  }
}
