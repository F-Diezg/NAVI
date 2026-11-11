import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../models.dart';
import 'add_event_sheet.dart';
import 'format.dart';

/// Da acceso al AppState desde cualquier pantalla y repinta al cambiar.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Para usar dentro de callbacks (no se suscribe a cambios).
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

/// Casilla de estado: vacía, ✓ (hecha), ✓ gris (pasó la fecha) o ✗ (vencida).
class StatusCheck extends StatelessWidget {
  const StatusCheck({super.key, required this.item, this.onTap});
  final NaviItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final status = item.status;
    final (IconData icon, Color color, String tip) = switch (status) {
      ItemStatus.done => (
          Icons.check_circle_rounded,
          const Color(0xFF3CCB7F),
          item.submitted ? 'Entregada en Canvas' : 'Hecha'
        ),
      ItemStatus.autoDone => (
          Icons.check_circle_outline_rounded,
          s.outline,
          'Ya pasó'
        ),
      ItemStatus.overdue => (
          Icons.cancel_outlined,
          s.error,
          'Venció sin entregar · toca para marcarla'
        ),
      ItemStatus.pending => (
          Icons.radio_button_unchecked_rounded,
          s.onSurfaceVariant,
          'Marcar como hecha'
        ),
    };
    return Tooltip(
      message: tip,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: color, size: 26),
        ),
      ),
    );
  }
}

class ItemTile extends StatelessWidget {
  const ItemTile({super.key, required this.item, this.showCourse = true});
  final NaviItem item;
  final bool showCourse;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final s = theme.colorScheme;
    final status = item.status;
    final kind = item.effectiveKind;
    final faded =
        status == ItemStatus.done || status == ItemStatus.autoDone || item.hidden;
    final struck = status == ItemStatus.overdue;

    final subtitle = [
      if (showCourse && item.courseName != null) item.courseName!,
      fmtDue(item),
      if (status == ItemStatus.overdue) 'No entregada',
      if (item.isManual) 'Manual',
    ].join(' · ');

    return Card(
      child: ListTile(
        leading: StatusCheck(
          item: item,
          onTap: () {
            if (item.submitted) {
              _snack(context, 'Ya está entregada en Canvas ✓');
            } else {
              state.toggleDone(item);
            }
          },
        ),
        title: Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            decoration: struck ? TextDecoration.lineThrough : null,
            decorationThickness: 2,
            color: faded || struck ? s.onSurfaceVariant : s.onSurface,
          ),
        ),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            KindBadge(kind: kind),
            _ItemMenu(item: item),
          ],
        ),
        onTap: () => showItemDetails(context, item),
      ),
    );
  }
}

class KindBadge extends StatelessWidget {
  const KindBadge({super.key, required this.kind});
  final ItemKind kind;

  @override
  Widget build(BuildContext context) {
    final c = kindColor(kind, Theme.of(context).colorScheme);
    return Tooltip(
      message: kindLabel(kind),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(kindIcon(kind), size: 18, color: c),
      ),
    );
  }
}

class _ItemMenu extends StatelessWidget {
  const _ItemMenu({required this.item});
  final NaviItem item;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return PopupMenuButton<String>(
      tooltip: 'Opciones',
      onSelected: (v) async {
        switch (v) {
          case 'open':
            await openUrl(item.url!);
          case 'exam':
            await state.setKind(item, ItemKind.exam);
          case 'task':
            await state.setKind(item, ItemKind.task);
          case 'event':
            await state.setKind(item, ItemKind.event);
          case 'hide':
            await state.setHidden(item, !item.hidden);
          case 'edit':
            if (context.mounted) await showEventSheet(context, existing: item);
          case 'delete':
            await state.deleteManual(item);
        }
      },
      itemBuilder: (_) => [
        if (item.url != null)
          const PopupMenuItem(value: 'open', child: Text('Abrir en Canvas')),
        if (item.effectiveKind != ItemKind.exam)
          const PopupMenuItem(value: 'exam', child: Text('Es un examen')),
        if (item.effectiveKind != ItemKind.task)
          const PopupMenuItem(value: 'task', child: Text('Es una tarea')),
        if (item.effectiveKind != ItemKind.event)
          const PopupMenuItem(value: 'event', child: Text('Es un evento')),
        if (item.isManual) ...[
          const PopupMenuItem(value: 'edit', child: Text('Editar')),
          const PopupMenuItem(value: 'delete', child: Text('Borrar')),
        ] else
          PopupMenuItem(
              value: 'hide',
              child: Text(item.hidden ? 'Mostrar de nuevo' : 'Ocultar')),
      ],
    );
  }
}

Future<void> openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

void _snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

void showSnack(BuildContext context, String msg) => _snack(context, msg);

Future<void> showItemDetails(BuildContext context, NaviItem item) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  KindBadge(kind: item.effectiveKind),
                  const SizedBox(width: 10),
                  Text(kindLabel(item.effectiveKind),
                      style: theme.textTheme.labelLarge),
                ]),
                const SizedBox(height: 10),
                Text(item.title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 6),
                if (item.courseName != null)
                  Text(item.courseName!, style: theme.textTheme.bodyMedium),
                Text(
                  item.dueAt == null
                      ? 'Sin fecha'
                      : '${fmtDayLong(item.dueAt!)}'
                          '${item.allDay ? '' : ' · ${fmtTime(item.dueAt!)}'}'
                          ' (${relativeDay(item.dueAt!)})',
                  style: theme.textTheme.bodyMedium,
                ),
                if (item.description != null) ...[
                  const SizedBox(height: 16),
                  Text(item.description!),
                ],
                const SizedBox(height: 16),
                if (item.url != null)
                  FilledButton.icon(
                    onPressed: () => openUrl(item.url!),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Abrir en Canvas'),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Cabecera de sección pequeña.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 6),
      child: Row(children: [
        Expanded(
          child: Text(text.toUpperCase(),
              style: t.textTheme.labelMedium?.copyWith(
                  letterSpacing: 1.2, color: t.colorScheme.primary)),
        ),
        ?trailing,
      ]),
    );
  }
}

class EmptyHint extends StatelessWidget {
  const EmptyHint(this.text, {super.key, this.icon = Icons.auto_awesome});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(children: [
        Icon(icon, size: 40, color: s.primary.withValues(alpha: 0.6)),
        const SizedBox(height: 10),
        Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(color: s.onSurfaceVariant)),
      ]),
    );
  }
}
