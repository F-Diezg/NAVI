import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models.dart';
import 'format.dart';
import 'widgets.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.onDaySelected});

  /// Para que el botón "+" sepa qué día está seleccionado.
  final ValueChanged<DateTime> onDaySelected;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();
  CalendarFormat _format = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final dayItems = state.itemsForDay(_selected);
    final upcoming = state.upcoming(days: 7);

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        TableCalendar<NaviItem>(
          locale: 'es_ES',
          firstDay: DateTime(now.year - 1, 1, 1),
          lastDay: DateTime(now.year + 2, 12, 31),
          focusedDay: _focused,
          startingDayOfWeek: StartingDayOfWeek.monday,
          calendarFormat: _format,
          availableCalendarFormats: const {
            CalendarFormat.month: 'Mes',
            CalendarFormat.twoWeeks: '2 semanas',
            CalendarFormat.week: 'Semana',
          },
          selectedDayPredicate: (d) => isSameDay(d, _selected),
          eventLoader: state.itemsForDay,
          onDaySelected: (sel, foc) {
            setState(() {
              _selected = sel;
              _focused = foc;
            });
            widget.onDaySelected(sel);
          },
          onFormatChanged: (f) => setState(() => _format = f),
          onPageChanged: (f) => _focused = f,
          headerStyle: const HeaderStyle(titleCentered: true),
          calendarStyle: CalendarStyle(
            outsideDaysVisible: false,
            todayDecoration: BoxDecoration(
              color: s.primary.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            todayTextStyle: TextStyle(color: s.onSurface),
            selectedDecoration:
                BoxDecoration(color: s.primary, shape: BoxShape.circle),
            selectedTextStyle: TextStyle(color: s.onPrimary),
          ),
          calendarBuilders: CalendarBuilders<NaviItem>(
            markerBuilder: (context, day, events) {
              if (events.isEmpty) return null;
              final hasExam = events.any((e) => e.isExam);
              final shown = events.take(4).toList();
              return Positioned(
                bottom: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final e in shown)
                      Container(
                        width: hasExam && e.isExam ? 8 : 6,
                        height: hasExam && e.isExam ? 8 : 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: e.status == ItemStatus.pending
                              ? kindColor(e.effectiveKind, s)
                              : s.outlineVariant,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        SectionHeader(fmtDayLong(_selected)),
        if (dayItems.isEmpty)
          const EmptyHint('Nada para este día')
        else
          for (final i in dayItems) ItemTile(item: i),
        if (isSameDay(_selected, now)) ...[
          SectionHeader('Próximos 7 días'),
          if (upcoming.isEmpty)
            const EmptyHint('Semana despejada ✨', icon: Icons.wb_sunny_rounded)
          else
            for (final i in upcoming.where((i) => !isSameDay(i.dueAt, now)))
              ItemTile(item: i),
        ],
      ],
    );
  }
}
