import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import 'format.dart';
import 'widgets.dart';

class ExamsScreen extends StatelessWidget {
  const ExamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final all = state.exams;
    final upcoming =
        all.where((e) => e.status == ItemStatus.pending).toList();
    final past = all
        .where((e) => e.status != ItemStatus.pending)
        .toList()
        .reversed
        .toList();

    if (all.isEmpty) {
      return const EmptyHint(
          'No hay exámenes todavía.\nSi Canvas no los marca como examen, '
          'usa ⋮ → "Es un examen" en cualquier tarea o evento.',
          icon: Icons.school_rounded);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        SectionHeader('Próximos (${upcoming.length})'),
        if (upcoming.isEmpty)
          const EmptyHint('Ningún examen a la vista 🎉')
        else
          for (final e in upcoming) _ExamCard(item: e),
        if (past.isNotEmpty)
          ExpansionTile(
            title: Text('Pasados (${past.length})'),
            children: [for (final e in past) ItemTile(item: e)],
          ),
      ],
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.item});
  final NaviItem item;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final s = theme.colorScheme;
    final d = item.dueAt;
    final accent = kindColor(ItemKind.exam, s);
    final days = d == null
        ? null
        : DateTime(d.year, d.month, d.day)
            .difference(DateTime(DateTime.now().year, DateTime.now().month,
                DateTime.now().day))
            .inDays;
    final urgent = days != null && days <= 3;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: urgent ? BorderSide(color: accent, width: 1.5) : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showItemDetails(context, item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(
              width: 58,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(children: [
                Text(d == null ? '?' : '${d.day}',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(color: accent, fontWeight: FontWeight.w700)),
                Text(
                    d == null
                        ? ''
                        : DateFormat('MMM', 'es_ES').format(d).toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(color: accent)),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (item.courseName != null)
                    Text(item.courseName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: s.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(
                    d == null
                        ? 'Sin fecha'
                        : '${capitalize(relativeDay(d))}'
                            '${item.allDay ? '' : ' · ${fmtTime(d)}'}',
                    style: theme.textTheme.labelLarge?.copyWith(
                        color: urgent ? accent : s.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            StatusCheck(
              item: item,
              onTap: () => state.toggleDone(item),
            ),
          ]),
        ),
      ),
    );
  }
}
