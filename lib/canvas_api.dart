import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class CanvasException implements Exception {
  CanvasException(this.message, {this.status});
  final String message;
  final int? status;

  bool get isAuthError => status == 401;

  @override
  String toString() => message;
}

/// Resultado de una sincronización con Canvas, listo para guardar.
class CanvasSnapshot {
  CanvasSnapshot(this.courses, this.items);
  final List<Course> courses;
  final List<NaviItem> items;
}

class CanvasClient {
  CanvasClient(String baseUrl, this.token) : baseUrl = normalizeUrl(baseUrl);

  final String baseUrl;
  final String token;

  static String normalizeUrl(String url) {
    var u = url.trim();
    if (u.isEmpty) return u;
    if (!u.startsWith('http://') && !u.startsWith('https://')) u = 'https://$u';
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  Future<List<dynamic>> _getAll(String pathAndQuery) async {
    Uri? uri = Uri.parse('$baseUrl$pathAndQuery');
    final out = <dynamic>[];
    var pages = 0;
    while (uri != null && pages < 50) {
      pages++;
      final http.Response r;
      try {
        r = await http.get(uri, headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        }).timeout(const Duration(seconds: 30));
      } catch (e) {
        throw CanvasException('No se pudo conectar con Canvas ($e)');
      }
      if (r.statusCode == 401) {
        throw CanvasException(
            'Canvas ha rechazado el token (caducado o revocado).',
            status: 401);
      }
      if (r.statusCode == 403) {
        // Asignaturas cerradas o sin permiso: no rompemos la sincronización.
        return out;
      }
      if (r.statusCode >= 400) {
        throw CanvasException('Canvas respondió ${r.statusCode} en $pathAndQuery',
            status: r.statusCode);
      }
      var body = utf8.decode(r.bodyBytes);
      if (body.startsWith('while(1);')) body = body.substring(9);
      final decoded = jsonDecode(body);
      if (decoded is List) {
        out.addAll(decoded);
      } else {
        out.add(decoded);
      }
      uri = _nextLink(r.headers['link']);
    }
    return out;
  }

  static Uri? _nextLink(String? header) {
    if (header == null) return null;
    final m = RegExp(r'<([^>]+)>;\s*rel="next"').firstMatch(header);
    return m == null ? null : Uri.parse(m.group(1)!);
  }

  /// Comprueba el token y devuelve el nombre del usuario.
  Future<String> whoAmI() async {
    final me = await _getAll('/api/v1/users/self');
    final m = me.isEmpty ? null : me.first as Map<String, dynamic>;
    return (m?['short_name'] ?? m?['name'] ?? 'estudiante').toString();
  }

  Future<CanvasSnapshot> fetchAll(String syncId) async {
    final rawCourses = await _getAll(
        '/api/v1/courses?enrollment_state=active&per_page=100');

    final courses = <Course>[];
    final items = <NaviItem>[];

    for (final rc in rawCourses.cast<Map<String, dynamic>>()) {
      final name = rc['name'] as String?;
      if (name == null || rc['access_restricted_by_date'] == true) continue;
      final courseId = (rc['id'] as num).toInt();

      final groups = await _getAll('/api/v1/courses/$courseId/assignment_groups'
          '?include[]=assignments&include[]=submission&per_page=100');

      double? attendancePct;
      String? attendanceLabel;

      for (final g in groups.cast<Map<String, dynamic>>()) {
        final groupName = (g['name'] ?? '').toString();
        final assignments =
            (g['assignments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        for (final a in assignments) {
          if (a['published'] == false) continue;
          final title = (a['name'] ?? '').toString();

          // Asistencia (p. ej. Roll Call): no es una tarea, es un porcentaje.
          if (Classifier.isAttendance(title)) {
            final pct = _attendanceFrom(a);
            if (pct != null) {
              attendancePct = pct;
              attendanceLabel = title;
            }
            continue;
          }

          final sub = a['submission'] as Map<String, dynamic>?;
          final types =
              (a['submission_types'] as List?)?.map((e) => '$e').toList() ??
                  const <String>[];
          final isQuiz = a['is_quiz_assignment'] == true ||
              types.contains('online_quiz');

          items.add(NaviItem(
            id: 'a:${a['id']}',
            source: 'canvas',
            title: title,
            kind: Classifier.assignmentKind(
                title: title, groupName: groupName, isQuiz: isQuiz),
            courseId: courseId,
            courseName: name,
            dueAt: _date(a['due_at']),
            url: a['html_url'] as String?,
            description: Classifier.plainText(a['description'] as String?),
            submitted: _isSubmitted(sub),
            noSubmission: types.isEmpty ||
                types.every((t) =>
                    t == 'none' || t == 'on_paper' || t == 'not_graded'),
            syncId: syncId,
          ));
        }
      }

      courses.add(Course(
        id: courseId,
        name: name,
        code: rc['course_code'] as String?,
        attendancePct: attendancePct,
        attendanceLabel: attendanceLabel,
        syncId: syncId,
      ));
    }

    // Eventos del calendario de cada asignatura (muchos exámenes se publican así).
    final now = DateTime.now().toUtc();
    final start = now.subtract(const Duration(days: 150)).toIso8601String();
    final end = now.add(const Duration(days: 300)).toIso8601String();
    final byId = {for (final c in courses) c.id: c};
    final ids = byId.keys.toList();
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.skip(i).take(10);
      final ctx = chunk.map((id) => 'context_codes[]=course_$id').join('&');
      final events = await _getAll('/api/v1/calendar_events?type=event'
          '&start_date=${Uri.encodeQueryComponent(start)}'
          '&end_date=${Uri.encodeQueryComponent(end)}'
          '&per_page=100&$ctx');
      for (final e in events.cast<Map<String, dynamic>>()) {
        final code = (e['context_code'] ?? '').toString();
        final cid = int.tryParse(code.replaceFirst('course_', ''));
        final title = (e['title'] ?? '').toString();
        if (Classifier.isAttendance(title)) continue;
        items.add(NaviItem(
          id: 'e:${e['id']}',
          source: 'canvas',
          title: title,
          kind: Classifier.eventKind(title),
          courseId: cid,
          courseName: byId[cid]?.name,
          dueAt: _date(e['start_at']),
          allDay: e['all_day'] == true,
          url: e['html_url'] as String?,
          description: Classifier.plainText(e['description'] as String?),
          syncId: syncId,
        ));
      }
    }

    return CanvasSnapshot(courses, items);
  }

  static DateTime? _date(Object? v) =>
      v is String ? DateTime.tryParse(v)?.toLocal() : null;

  static bool _isSubmitted(Map<String, dynamic>? sub) {
    if (sub == null) return false;
    if (sub['excused'] == true) return true;
    if (sub['submitted_at'] != null) return true;
    final state = sub['workflow_state'];
    return state == 'submitted' ||
        state == 'pending_review' ||
        (state == 'graded' && sub['score'] != null);
  }

  static double? _attendanceFrom(Map<String, dynamic> a) {
    final sub = a['submission'] as Map<String, dynamic>?;
    final score = (sub?['score'] as num?)?.toDouble();
    final possible = (a['points_possible'] as num?)?.toDouble();
    if (score == null || possible == null || possible <= 0) return null;
    return (score / possible * 100).clamp(0, 100).toDouble();
  }
}

/// Reglas para decidir qué es examen, tarea o asistencia.
class Classifier {
  static final _attendance =
      RegExp(r'(roll call|asistencia|attendance|presencialidad)');
  static final _examStrong = RegExp(
      r'\b(examen|examenes|exam|exams|parcial|parciales|midterm|prueba|pruebas)\b');
  static final _examWeak =
      RegExp(r'\b(test|tests|control|controles|cuestionario|quiz)\b');
  static final _examGroup =
      RegExp(r'(examen|exam|prueba|parcial|evaluacion final|final exam)');
  static final _delivery = RegExp(r'\b(entrega|entregable|proyecto|trabajo)\b');

  static String normalize(String s) {
    const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
    const to = 'aaaaaeeeeiiiiooooouuuunc';
    final lower = s.toLowerCase();
    final b = StringBuffer();
    for (final ch in lower.split('')) {
      final i = from.indexOf(ch);
      b.write(i >= 0 ? to[i] : ch);
    }
    return b.toString();
  }

  static bool isAttendance(String title) =>
      _attendance.hasMatch(normalize(title));

  static ItemKind assignmentKind({
    required String title,
    required String groupName,
    required bool isQuiz,
  }) {
    final t = normalize(title);
    final g = normalize(groupName);
    final strong = _examStrong.hasMatch(t);
    // "Entrega parcial del proyecto" es una tarea, no un examen.
    if (strong && _delivery.hasMatch(t) && !t.contains('examen')) {
      return ItemKind.task;
    }
    if (strong) return ItemKind.exam;
    if (_examWeak.hasMatch(t) && _examGroup.hasMatch(g)) return ItemKind.exam;
    if (isQuiz && _examGroup.hasMatch(g)) return ItemKind.exam;
    return ItemKind.task;
  }

  static ItemKind eventKind(String title) {
    final t = normalize(title);
    if (_examStrong.hasMatch(t) && !_delivery.hasMatch(t)) return ItemKind.exam;
    if (t.contains('examen')) return ItemKind.exam;
    return ItemKind.event;
  }

  static String? plainText(String? html) {
    if (html == null || html.isEmpty) return null;
    var s = html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    if (s.length > 1200) s = '${s.substring(0, 1200)}…';
    return s.isEmpty ? null : s;
  }
}
