import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import 'format.dart';
import 'widgets.dart';

/// Formulario para añadir (o editar) un evento manual.
/// En la fase 2 se rellenará también por voz.
Future<void> showEventSheet(BuildContext context,
    {NaviItem? existing, DateTime? day}) {
  final state = AppScope.read(context);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _EventForm(state: state, existing: existing, day: day),
    ),
  );
}

class _EventForm extends StatefulWidget {
  const _EventForm({required this.state, this.existing, this.day});
  final AppState state;
  final NaviItem? existing;
  final DateTime? day;

  @override
  State<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<_EventForm> {
  late final TextEditingController _title;
  late ItemKind _kind;
  int? _courseId;
  late DateTime _date;
  TimeOfDay? _time;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _kind = e?.effectiveKind ?? ItemKind.event;
    _courseId = e?.courseId;
    final base = e?.dueAt ?? widget.day ?? DateTime.now();
    _date = DateTime(base.year, base.month, base.day);
    _time = (e != null && !e.allDay && e.dueAt != null)
        ? TimeOfDay.fromDateTime(e.dueAt!)
        : null;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 3),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (t != null) setState(() => _time = t);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      showSnack(context, 'Ponle un título');
      return;
    }
    final course = widget.state.courseById(_courseId);
    final due = _time == null
        ? _date
        : DateTime(
            _date.year, _date.month, _date.day, _time!.hour, _time!.minute);
    final e = widget.existing;
    final item = NaviItem(
      id: e?.id ?? AppState.newManualId(),
      source: 'manual',
      title: title,
      kind: _kind,
      courseId: course?.id,
      courseName: course?.name,
      dueAt: due,
      allDay: _time == null,
      done: e?.done ?? false,
      doneAt: e?.doneAt,
    );
    await widget.state.saveManual(item);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final courses = widget.state.courses;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? 'Nuevo evento' : 'Editar evento',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: widget.existing == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Título',
                hintText: 'Ej.: Examen de Termodinámica',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            SegmentedButton<ItemKind>(
              segments: [
                for (final k in ItemKind.values)
                  ButtonSegment(
                      value: k,
                      label: Text(kindLabel(k)),
                      icon: Icon(kindIcon(k))),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int?>(
              initialValue: courses.any((c) => c.id == _courseId)
                  ? _courseId
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Asignatura (opcional)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Ninguna')),
                for (final c in courses)
                  DropdownMenuItem<int?>(
                      value: c.id,
                      child: Text(c.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _courseId = v),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_rounded),
                  label: Text(fmtDay(_date)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text(_time == null
                      ? 'Todo el día'
                      : _time!.format(context)),
                ),
              ),
              if (_time != null)
                IconButton(
                  tooltip: 'Quitar hora',
                  onPressed: () => setState(() => _time = null),
                  icon: const Icon(Icons.close_rounded),
                ),
            ]),
            const SizedBox(height: 20),
            FilledButton(onPressed: _save, child: const Text('Guardar')),
          ],
        ),
      ),
    );
  }
}
