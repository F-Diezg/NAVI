import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'canvas_api.dart';
import 'models.dart';
import 'notifications.dart';
import 'repo.dart';

/// Estado de la app compartido por todas las pantallas.
class AppState extends ChangeNotifier {
  AppState(this.repo, this.notifier);

  final Repo repo;
  final Notifier notifier;

  NaviSettings? settings;
  List<Course> courses = [];
  List<NaviItem> _items = [];
  bool syncing = false;
  bool loading = false;
  bool showHidden = false;
  String? error;
  String? info;

  Timer? _timer;

  // ------------------------------------------------------------ consultas

  /// Lo que se ve: manuales + lo que vino en la última sincronización de Canvas.
  /// Las asignaturas de "relleno" no aparecen en el calendario, en Exámenes
  /// ni en los avisos (salvo con "Mostrar elementos ocultos").
  List<NaviItem> get items => _visible(includeFiller: showHidden);

  List<NaviItem> _visible({required bool includeFiller}) {
    final last = settings?.lastSyncId;
    final filler = includeFiller
        ? const <int>{}
        : {for (final c in courses) if (c.isFiller) c.id};
    return _items.where((i) {
      if (i.hidden && !showHidden) return false;
      if (i.courseId != null && filler.contains(i.courseId)) return false;
      if (i.isManual) return true;
      return last == null || i.syncId == last;
    }).toList();
  }

  int get hiddenCount => _items.where((i) => i.hidden).length;

  List<NaviItem> itemsForDay(DateTime day) {
    final list = items.where((i) {
      final d = i.dueAt;
      return d != null &&
          d.year == day.year &&
          d.month == day.month &&
          d.day == day.day;
    }).toList();
    list.sort(_byDue);
    return list;
  }

  List<NaviItem> get exams => items.where((i) => i.isExam).toList()..sort(_byDue);

  /// Dentro de una asignatura se ven sus cosas aunque sea de relleno.
  List<NaviItem> itemsForCourse(int? courseId) =>
      _visible(includeFiller: true)
          .where((i) => i.courseId == courseId)
          .toList()
        ..sort(_byDue);

  List<Course> coursesIn(CourseCategory? category) =>
      courses.where((c) => c.category == category).toList();

  List<NaviItem> upcoming({int days = 7}) {
    final now = DateTime.now();
    final until = now.add(Duration(days: days));
    return items
        .where((i) =>
            i.dueAt != null &&
            i.status == ItemStatus.pending &&
            i.dueAt!.isBefore(until))
        .toList()
      ..sort(_byDue);
  }

  Course? courseById(int? id) {
    for (final c in courses) {
      if (c.id == id) return c;
    }
    return null;
  }

  static int _byDue(NaviItem a, NaviItem b) {
    final x = a.dueAt, y = b.dueAt;
    if (x == null && y == null) return a.title.compareTo(b.title);
    if (x == null) return 1;
    if (y == null) return -1;
    return x.compareTo(y);
  }

  // ------------------------------------------------------------ ciclo de vida

  Future<void> start() async {
    await _loadCache();
    await refresh();
    if (_canvasIsStale) unawaited(syncCanvas());
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 15), (_) => onResume());
  }

  /// Al volver a la app: trae cambios de otros dispositivos y, si hace falta,
  /// vuelve a consultar Canvas.
  Future<void> onResume() async {
    if (Supabase.instance.client.auth.currentUser == null) return;
    await refresh(quiet: true);
    if (_canvasIsStale) await syncCanvas();
  }

  bool get _canvasIsStale {
    final s = settings;
    if (s == null || !s.hasToken) return false;
    final last = s.lastCanvasSync;
    return last == null ||
        DateTime.now().difference(last) > const Duration(hours: 2);
  }

  /// Al cerrar sesión. No avisa a los listeners (se llama durante un build).
  void reset() {
    _timer?.cancel();
    _timer = null;
    settings = null;
    courses = [];
    _items = [];
    error = null;
    info = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------ datos

  /// Descarga de la nube lo último (lo que hayas marcado en otro dispositivo).
  Future<void> refresh({bool quiet = false}) async {
    if (!quiet) {
      loading = true;
      notifyListeners();
    }
    try {
      final s = await repo.loadSettings();
      final c = await repo.loadCourses();
      final i = await repo.loadItems();
      settings = s;
      courses = c;
      _items = i;
      error = null;
      await _saveCache();
      unawaited(notifier.refresh(items, settings));
    } catch (e) {
      error = 'Sin conexión con la nube: muestro lo último guardado.';
      debugPrint('refresh: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Consulta Canvas y guarda el resultado en la nube.
  Future<void> syncCanvas() async {
    if (syncing) return;
    final s = settings;
    if (s == null || !s.hasToken) {
      error = 'Falta el token de Canvas: ponlo en Ajustes.';
      notifyListeners();
      return;
    }
    syncing = true;
    notifyListeners();
    try {
      final syncId = '${DateTime.now().millisecondsSinceEpoch}'
          '-${Random().nextInt(1 << 20)}';
      final snap =
          await CanvasClient(s.canvasUrl, s.canvasToken!.trim()).fetchAll(syncId);
      await repo.upsertCanvas(snap.courses, snap.items);
      await repo.markSynced(syncId, DateTime.now());
      final pending = snap.items
          .where((i) => i.status == ItemStatus.pending && i.dueAt != null)
          .length;
      info = 'Canvas al día · ${snap.courses.length} asignaturas · '
          '$pending pendientes';
      error = null;
      await refresh(quiet: true);
    } on CanvasException catch (e) {
      error = e.message;
      if (e.isAuthError) unawaited(notifier.canvasTokenRejected());
    } catch (e) {
      error = 'Error al sincronizar: $e';
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> saveCanvasCredentials(
      String url, String token, DateTime? expiresAt) async {
    final normalized = CanvasClient.normalizeUrl(url);
    // Probamos el token antes de guardarlo.
    final name = await CanvasClient(normalized, token.trim()).whoAmI();
    await repo.saveCanvasCredentials(
        url: normalized, token: token.trim(), expiresAt: expiresAt);
    info = '¡Conectado a Canvas como $name!';
    await refresh(quiet: true);
    await syncCanvas();
  }

  // ------------------------------------------------------------ acciones

  Future<void> toggleDone(NaviItem item) async {
    final before = (item.done, item.doneAt);
    item.done = !item.done;
    item.doneAt = item.done ? DateTime.now() : null;
    notifyListeners();
    await _persist(item, {
      'done': item.done,
      'done_at': item.doneAt?.toUtc().toIso8601String(),
    }, undo: () {
      item.done = before.$1;
      item.doneAt = before.$2;
    });
  }

  Future<void> setKind(NaviItem item, ItemKind kind) async {
    final before = item.kindOverride;
    if (item.isManual) {
      final prevKind = item.kind;
      item.kind = kind;
      item.kindOverride = null;
      notifyListeners();
      await _persist(item, {'kind': kind.name, 'kind_override': null},
          undo: () => item.kind = prevKind);
      return;
    }
    item.kindOverride = kind == item.kind ? null : kind;
    notifyListeners();
    await _persist(item, {'kind_override': item.kindOverride?.name},
        undo: () => item.kindOverride = before);
  }

  Future<void> setCourseCategory(Course course, CourseCategory? category) async {
    final before = course.category;
    course.category = category;
    notifyListeners();
    try {
      await repo.setCourseCategory(course.id, category);
      await _saveCache();
      unawaited(notifier.refresh(items, settings));
    } catch (e) {
      course.category = before;
      error = 'No se pudo guardar la clasificación. ¿Has ejecutado el SQL '
          'de la columna "category" en Supabase?';
      notifyListeners();
    }
  }

  Future<void> setHidden(NaviItem item, bool hidden) async {
    item.hidden = hidden;
    notifyListeners();
    await _persist(item, {'hidden': hidden}, undo: () => item.hidden = !hidden);
  }

  Future<void> saveManual(NaviItem item) async {
    final idx = _items.indexWhere((i) => i.id == item.id);
    if (idx >= 0) {
      _items[idx] = item;
    } else {
      _items.add(item);
    }
    notifyListeners();
    try {
      await repo.saveManual(item);
      await _saveCache();
      unawaited(notifier.refresh(items, settings));
    } catch (e) {
      error = 'No se pudo guardar: $e';
      notifyListeners();
    }
  }

  Future<void> deleteManual(NaviItem item) async {
    _items.removeWhere((i) => i.id == item.id);
    notifyListeners();
    try {
      await repo.deleteItem(item.id);
      await _saveCache();
    } catch (e) {
      error = 'No se pudo borrar: $e';
      _items.add(item);
      notifyListeners();
    }
  }

  void toggleShowHidden() {
    showHidden = !showHidden;
    notifyListeners();
  }

  void clearMessages() {
    error = null;
    info = null;
    notifyListeners();
  }

  static String newManualId() =>
      'm:${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(9999)}';

  Future<void> _persist(NaviItem item, Map<String, dynamic> fields,
      {required void Function() undo}) async {
    try {
      await repo.updateItem(item.id, fields);
      await _saveCache();
      unawaited(notifier.refresh(items, settings));
    } catch (e) {
      undo();
      error = 'No se pudo guardar el cambio (¿sin conexión?)';
      notifyListeners();
    }
  }

  // ------------------------------------------------------------ caché local

  String get _cacheKey =>
      'navi_cache_${Supabase.instance.client.auth.currentUser?.id ?? 'anon'}';

  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _cacheKey,
          jsonEncode({
            'settings': settings?.toCacheRow(),
            'courses': courses.map((c) => c.toRow()).toList(),
            'items': _items.map((i) => i.toRow()).toList(),
          }));
    } catch (e) {
      debugPrint('cache: $e');
    }
  }

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final s = m['settings'] as Map<String, dynamic>?;
      if (s != null) settings = NaviSettings.fromRow(s);
      courses = (m['courses'] as List)
          .map((e) => Course.fromRow(e as Map<String, dynamic>))
          .toList();
      _items = (m['items'] as List)
          .map((e) => NaviItem.fromRow(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('cache: $e');
    }
  }
}
