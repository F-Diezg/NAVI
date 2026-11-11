import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'models.dart';

/// Todo lo que se lee/escribe en la nube (Supabase).
class Repo {
  SupabaseClient get _db => Supabase.instance.client;

  String get uid {
    final u = _db.auth.currentUser;
    if (u == null) throw StateError('No hay sesión iniciada');
    return u.id;
  }

  Future<NaviSettings> loadSettings() async {
    final rows = await _db.from('navi_settings').select().limit(1);
    if (rows.isEmpty) {
      final created = NaviSettings(canvasUrl: Config.defaultCanvasUrl);
      await _db.from('navi_settings').upsert(
          {'user_id': uid, 'canvas_url': created.canvasUrl},
          onConflict: 'user_id');
      return created;
    }
    return NaviSettings.fromRow(rows.first);
  }

  Future<void> saveCanvasCredentials({
    required String url,
    required String token,
    DateTime? expiresAt,
  }) async {
    await _db.from('navi_settings').upsert({
      'user_id': uid,
      'canvas_url': url,
      'canvas_token': token,
      'token_expires_at': dateOnlyString(expiresAt),
    }, onConflict: 'user_id');
  }

  Future<void> markSynced(String syncId, DateTime at) async {
    await _db.from('navi_settings').update({
      'last_sync_id': syncId,
      'last_canvas_sync': at.toUtc().toIso8601String(),
    }).eq('user_id', uid);
  }

  Future<List<Course>> loadCourses() async {
    final rows = await _db.from('navi_courses').select().order('name');
    return rows.map(Course.fromRow).toList();
  }

  Future<List<NaviItem>> loadItems() async {
    const page = 1000;
    final out = <NaviItem>[];
    for (var from = 0;; from += page) {
      final rows = await _db
          .from('navi_items')
          .select()
          .order('id')
          .range(from, from + page - 1);
      out.addAll(rows.map(NaviItem.fromRow));
      if (rows.length < page) break;
    }
    return out;
  }

  /// Guarda lo que viene de Canvas SIN pisar lo que tú has tocado
  /// (ticks, tipo cambiado a mano, ocultos).
  Future<void> upsertCanvas(List<Course> courses, List<NaviItem> items) async {
    final id = uid;
    final courseRows = [
      for (final c in courses) {...c.toCanvasRow(), 'user_id': id}
    ];
    if (courseRows.isNotEmpty) {
      await _db
          .from('navi_courses')
          .upsert(courseRows, onConflict: 'user_id,id', defaultToNull: false);
    }

    final itemRows = [
      for (final i in items)
        {
          'user_id': id,
          'id': i.id,
          'source': 'canvas',
          'course_id': i.courseId,
          'course_name': i.courseName,
          'title': i.title,
          'kind': i.kind.name,
          'due_at': i.dueAt?.toUtc().toIso8601String(),
          'all_day': i.allDay,
          'url': i.url,
          'description': i.description,
          'submitted': i.submitted,
          'no_submission': i.noSubmission,
          'sync_id': i.syncId,
        }
    ];
    for (var k = 0; k < itemRows.length; k += 200) {
      final chunk = itemRows.sublist(
          k, k + 200 > itemRows.length ? itemRows.length : k + 200);
      await _db
          .from('navi_items')
          .upsert(chunk, onConflict: 'user_id,id', defaultToNull: false);
    }
  }

  Future<void> setCourseCategory(int courseId, CourseCategory? category) async {
    await _db
        .from('navi_courses')
        .update({'category': category?.name})
        .eq('user_id', uid)
        .eq('id', courseId);
  }

  Future<void> updateItem(String itemId, Map<String, dynamic> fields) async {
    await _db
        .from('navi_items')
        .update(fields)
        .eq('user_id', uid)
        .eq('id', itemId);
  }

  Future<void> saveManual(NaviItem item) async {
    await _db.from('navi_items').upsert(
        {...item.toRow(), 'user_id': uid}, onConflict: 'user_id,id');
  }

  Future<void> deleteItem(String itemId) async {
    await _db.from('navi_items').delete().eq('user_id', uid).eq('id', itemId);
  }
}
