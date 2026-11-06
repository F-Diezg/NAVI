import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';

final _day = DateFormat('EEE d MMM', 'es_ES');
final _dayLong = DateFormat("EEEE d 'de' MMMM", 'es_ES');
final _time = DateFormat.Hm('es_ES');

String fmtDay(DateTime d) => _day.format(d);
String fmtDayLong(DateTime d) => capitalize(_dayLong.format(d));
String fmtTime(DateTime d) => _time.format(d);

String fmtDue(NaviItem i) {
  final d = i.dueAt;
  if (d == null) return 'Sin fecha';
  return i.allDay ? fmtDay(d) : '${fmtDay(d)} · ${fmtTime(d)}';
}

String capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// "hoy", "mañana", "en 5 días", "hace 2 días"
String relativeDay(DateTime d, [DateTime? now]) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final diff = DateTime(d.year, d.month, d.day).difference(today).inDays;
  if (diff == 0) return 'hoy';
  if (diff == 1) return 'mañana';
  if (diff == -1) return 'ayer';
  if (diff > 1) return 'en $diff días';
  return 'hace ${-diff} días';
}

String kindLabel(ItemKind k) => switch (k) {
      ItemKind.exam => 'Examen',
      ItemKind.task => 'Tarea',
      ItemKind.event => 'Evento',
    };

IconData kindIcon(ItemKind k) => switch (k) {
      ItemKind.exam => Icons.school_rounded,
      ItemKind.task => Icons.assignment_rounded,
      ItemKind.event => Icons.event_rounded,
    };

Color kindColor(ItemKind k, ColorScheme s) => switch (k) {
      ItemKind.exam => const Color(0xFFF2994A),
      ItemKind.task => s.primary,
      ItemKind.event => s.tertiary,
    };
