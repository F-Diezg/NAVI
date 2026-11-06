import 'package:flutter/material.dart';

import '../models.dart';
import 'format.dart';
import 'widgets.dart';

class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final courses = state.courses;
    final noCourse = state.itemsForCourse(null);

    if (courses.isEmpty && noCourse.isEmpty) {
      return const EmptyHint(
          'Aún no hay asignaturas.\nConecta Canvas en Ajustes y sincroniza.',
          icon: Icons.menu_book_rounded);
    }

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      children: [
        for (final c in courses)
          _CourseCard(
            title: c.name,
            course: c,
            items: state.itemsForCourse(c.id),
          ),
        if (noCourse.isNotEmpty)
          _CourseCard(title: 'Sin asignatura', items: noCourse),
      ],
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.title, required this.items, this.course});
  final String title;
  final Course? course;
  final List<NaviItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = theme.colorScheme;
    final pending = items.where((i) => i.status == ItemStatus.pending).toList();
    final overdue = items.where((i) => i.status == ItemStatus.overdue).length;
    NaviItem? nextExam;
    for (final i in pending) {
      if (i.isExam && i.dueAt != null) {
        nextExam = i;
        break;
      }
    }
    final pct = course?.attendancePct;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CourseDetailScreen(title: title, courseId: course?.id),
        )),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
                if (pct != null) _AttendanceChip(pct: pct),
              ]),
              if (course?.code != null && course?.code != title)
                Text(course?.code ?? '',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: s.onSurfaceVariant)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 6, children: [
                _Pill(Icons.pending_actions_rounded,
                    '${pending.length} pendientes', s.primary),
                if (overdue > 0)
                  _Pill(Icons.cancel_outlined, '$overdue sin entregar', s.error),
                if (nextExam != null)
                  _Pill(
                      Icons.school_rounded,
                      'Examen ${relativeDay(nextExam.dueAt!)}',
                      kindColor(ItemKind.exam, s)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceChip extends StatelessWidget {
  const _AttendanceChip({required this.pct});
  final double pct;

  @override
  Widget build(BuildContext context) {
    final color = pct >= 85
        ? const Color(0xFF3CCB7F)
        : pct >= 75
            ? const Color(0xFFF2C94C)
            : Theme.of(context).colorScheme.error;
    return Tooltip(
      message: 'Asistencia según Canvas',
      child: Chip(
        avatar: Icon(Icons.how_to_reg_rounded, size: 18, color: color),
        label: Text('${pct.toStringAsFixed(0)} %'),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.icon, this.text, this.color);
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(color: color, fontSize: 13)),
      ]),
    );
  }
}

class CourseDetailScreen extends StatelessWidget {
  const CourseDetailScreen({super.key, required this.title, this.courseId});
  final String title;
  final int? courseId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final items = state.itemsForCourse(courseId);
    final course = state.courseById(courseId);
    final pct = course?.attendancePct;

    final exams = items.where((i) => i.isExam && i.dueAt != null).toList();
    final pending = items
        .where((i) =>
            !i.isExam && i.dueAt != null && i.status == ItemStatus.pending)
        .toList();
    final past = items
        .where((i) =>
            !i.isExam && i.dueAt != null && i.status != ItemStatus.pending)
        .toList()
        .reversed
        .toList();
    final undated = items.where((i) => i.dueAt == null).toList();

    return Scaffold(
      appBar: AppBar(title: Text(title, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          if (pct != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.how_to_reg_rounded),
                title: Text('Asistencia: ${pct.toStringAsFixed(1)} %'),
                subtitle: Text(course?.attendanceLabel ?? 'Según Canvas'),
              ),
            ),
          SectionHeader('Exámenes'),
          if (exams.isEmpty)
            const EmptyHint('No hay exámenes detectados.\n'
                'Si falta alguno, márcalo con ⋮ → "Es un examen".')
          else
            for (final i in exams) ItemTile(item: i, showCourse: false),
          SectionHeader('Pendientes'),
          if (pending.isEmpty)
            const EmptyHint('Todo al día ✨')
          else
            for (final i in pending) ItemTile(item: i, showCourse: false),
          if (undated.isNotEmpty) ...[
            SectionHeader('Sin fecha'),
            for (final i in undated) ItemTile(item: i, showCourse: false),
          ],
          if (past.isNotEmpty)
            ExpansionTile(
              title: Text('Hechas y pasadas (${past.length})'),
              children: [
                for (final i in past) ItemTile(item: i, showCourse: false),
              ],
            ),
        ],
      ),
    );
  }
}
