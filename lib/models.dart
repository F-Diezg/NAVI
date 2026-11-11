enum ItemKind { task, exam, event }

ItemKind kindFromString(String? s) => switch (s) {
      'exam' => ItemKind.exam,
      'event' => ItemKind.event,
      _ => ItemKind.task,
    };

/// Estado visible de un elemento.
enum ItemStatus {
  /// Sin hacer y aún no ha pasado la fecha.
  pending,

  /// Marcado a mano o entregado en Canvas.
  done,

  /// Examen/evento cuya fecha ya pasó: se da por hecho automáticamente.
  autoDone,

  /// Tarea cuya fecha pasó sin entregarse ni marcarse: se tacha.
  overdue,
}

class NaviItem {
  NaviItem({
    required this.id,
    required this.source,
    required this.title,
    required this.kind,
    this.courseId,
    this.courseName,
    this.kindOverride,
    this.dueAt,
    this.allDay = false,
    this.url,
    this.description,
    this.submitted = false,
    this.noSubmission = false,
    this.done = false,
    this.doneAt,
    this.hidden = false,
    this.syncId,
  });

  final String id;
  final String source; // 'canvas' | 'manual'
  String title;
  ItemKind kind;
  int? courseId;
  String? courseName;
  ItemKind? kindOverride;
  DateTime? dueAt; // en hora local
  bool allDay;
  String? url;
  String? description;
  bool submitted;
  bool noSubmission;
  bool done;
  DateTime? doneAt;
  bool hidden;
  String? syncId;

  bool get isManual => source == 'manual';
  ItemKind get effectiveKind => kindOverride ?? kind;
  bool get isExam => effectiveKind == ItemKind.exam;

  ItemStatus statusAt(DateTime now) {
    if (submitted || done) return ItemStatus.done;
    final due = dueAt;
    if (due == null) return ItemStatus.pending;
    final passed = allDay
        ? DateTime(due.year, due.month, due.day + 1).isBefore(now)
        : due.isBefore(now);
    if (!passed) return ItemStatus.pending;
    if (effectiveKind != ItemKind.task || noSubmission) {
      return ItemStatus.autoDone;
    }
    return ItemStatus.overdue;
  }

  ItemStatus get status => statusAt(DateTime.now());

  factory NaviItem.fromRow(Map<String, dynamic> r) => NaviItem(
        id: r['id'] as String,
        source: r['source'] as String,
        title: (r['title'] as String?) ?? '(sin título)',
        kind: kindFromString(r['kind'] as String?),
        kindOverride: r['kind_override'] == null
            ? null
            : kindFromString(r['kind_override'] as String?),
        courseId: (r['course_id'] as num?)?.toInt(),
        courseName: r['course_name'] as String?,
        dueAt: _parseDate(r['due_at']),
        allDay: (r['all_day'] as bool?) ?? false,
        url: r['url'] as String?,
        description: r['description'] as String?,
        submitted: (r['submitted'] as bool?) ?? false,
        noSubmission: (r['no_submission'] as bool?) ?? false,
        done: (r['done'] as bool?) ?? false,
        doneAt: _parseDate(r['done_at']),
        hidden: (r['hidden'] as bool?) ?? false,
        syncId: r['sync_id'] as String?,
      );

  Map<String, dynamic> toRow() => {
        'id': id,
        'source': source,
        'title': title,
        'kind': kind.name,
        'kind_override': kindOverride?.name,
        'course_id': courseId,
        'course_name': courseName,
        'due_at': dueAt?.toUtc().toIso8601String(),
        'all_day': allDay,
        'url': url,
        'description': description,
        'submitted': submitted,
        'no_submission': noSubmission,
        'done': done,
        'done_at': doneAt?.toUtc().toIso8601String(),
        'hidden': hidden,
        'sync_id': syncId,
      };
}

/// Cómo has clasificado una asignatura.
enum CourseCategory { q1, q2, filler }

CourseCategory? categoryFromString(String? s) => switch (s) {
      'q1' => CourseCategory.q1,
      'q2' => CourseCategory.q2,
      'filler' => CourseCategory.filler,
      _ => null,
    };

class Course {
  Course({
    required this.id,
    required this.name,
    this.code,
    this.attendancePct,
    this.attendanceLabel,
    this.syncId,
    this.category,
  });

  final int id;
  final String name;
  final String? code;
  final double? attendancePct;
  final String? attendanceLabel;
  final String? syncId;
  CourseCategory? category;

  bool get isFiller => category == CourseCategory.filler;

  factory Course.fromRow(Map<String, dynamic> r) => Course(
        id: (r['id'] as num).toInt(),
        name: r['name'] as String,
        code: r['code'] as String?,
        attendancePct: (r['attendance_pct'] as num?)?.toDouble(),
        attendanceLabel: r['attendance_label'] as String?,
        syncId: r['sync_id'] as String?,
        category: categoryFromString(r['category'] as String?),
      );

  /// Lo que viene de Canvas (sin tu clasificación, para no pisarla).
  Map<String, dynamic> toCanvasRow() => {
        'id': id,
        'name': name,
        'code': code,
        'attendance_pct': attendancePct,
        'attendance_label': attendanceLabel,
        'sync_id': syncId,
      };

  /// Para la caché local (incluye tu clasificación).
  Map<String, dynamic> toRow() => {...toCanvasRow(), 'category': category?.name};
}

class NaviSettings {
  NaviSettings({
    required this.canvasUrl,
    this.canvasToken,
    this.tokenExpiresAt,
    this.lastCanvasSync,
    this.lastSyncId,
  });

  String canvasUrl;
  String? canvasToken;
  DateTime? tokenExpiresAt;
  DateTime? lastCanvasSync;
  String? lastSyncId;

  bool get hasToken => (canvasToken ?? '').trim().isNotEmpty;

  int? daysToTokenExpiry(DateTime now) {
    final e = tokenExpiresAt;
    if (e == null) return null;
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(e.year, e.month, e.day).difference(today).inDays;
  }

  factory NaviSettings.fromRow(Map<String, dynamic> r) => NaviSettings(
        canvasUrl: r['canvas_url'] as String,
        canvasToken: r['canvas_token'] as String?,
        tokenExpiresAt: _parseDate(r['token_expires_at']),
        lastCanvasSync: _parseDate(r['last_canvas_sync']),
        lastSyncId: r['last_sync_id'] as String?,
      );

  /// Para la caché local: nunca guardamos el token en el dispositivo.
  Map<String, dynamic> toCacheRow() => {
        'canvas_url': canvasUrl,
        'canvas_token': null,
        'token_expires_at': _dateOnly(tokenExpiresAt),
        'last_canvas_sync': lastCanvasSync?.toUtc().toIso8601String(),
        'last_sync_id': lastSyncId,
      };
}

DateTime? _parseDate(Object? v) {
  if (v is! String || v.isEmpty) return null;
  return DateTime.tryParse(v)?.toLocal();
}

String? _dateOnly(DateTime? d) => d == null
    ? null
    : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String? dateOnlyString(DateTime? d) => _dateOnly(d);
