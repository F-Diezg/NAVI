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

    Widget card(Course c) => _CourseCard(
        key: ValueKey(c.id),
        title: c.name,
        course: c,
        items: state.itemsForCourse(c.id));

    final q1 = state.coursesIn(CourseCategory.q1);
    final q2 = state.coursesIn(CourseCategory.q2);
    final unsorted = state.coursesIn(null);
    final filler = state.coursesIn(CourseCategory.filler);

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      children: [
        if (unsorted.isNotEmpty) ...[
          SectionHeader('Sin clasificar (${unsorted.length})'),
          if (q1.isEmpty && q2.isEmpty && filler.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Usa ⋮ en cada asignatura para ponerla en primer '
                  'cuatrimestre, segundo cuatrimestre o relleno.'),
            ),
          for (final c in unsorted) card(c),
        ],
        if (q1.isNotEmpty) ...[
          SectionHeader('Primer cuatrimestre (${q1.length})'),
          for (final c in q1) card(c),
        ],
        if (q2.isNotEmpty) ...[
          SectionHeader('Segundo cuatrimestre (${q2.length})'),
          for (final c in q2) card(c),
        ],
        if (noCourse.isNotEmpty) ...[
          SectionHeader('Otros'),
          _CourseCard(title: 'Sin asignatura', items: noCourse),
        ],
        if (filler.isNotEmpty)
          ExpansionTile(
            title: Text('Relleno (${filler.length})'),
            subtitle: const Text(
                'No salen en el calendario, en Exámenes ni en los avisos'),
            children: [for (final c in filler) card(c)],
          ),
      ],
    );
  }
}

/// Menú ⋮ para clasificar una asignatura.
class CategoryMenu extends StatelessWidget {
  const CategoryMenu({super.key, required this.course});
  final Course course;

  static const _labels = {
    CourseCategory.q1: 'Primer cuatrimestre',
    CourseCategory.q2: 'Segundo cuatrimestre',
    CourseCategory.filler: 'Relleno',
  };

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return PopupMenuButton<String>(
      tooltip: 'Clasificar',
      onSelected: (v) => state.setCourseCategory(
          course, v == 'none' ? null : categoryFromString(v)),
      itemBuilder: (_) => [
        for (final e in _labels.entries)
          CheckedPopupMenuItem(
            value: e.key.name,
            checked: course.category == e.key,
            child: Text(e.value),
          ),
        if (course.category != null) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'none', child: Text('Quitar clasificación')),
        ],
      ],
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard(
      {super.key, required this.title, required this.items, this.course});
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
                if (course != null) CategoryMenu(course: course!),
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
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: [if (course != null) CategoryMenu(course: course)],
      ),
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
