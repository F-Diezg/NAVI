import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

const heyListen = '¡Hey, listen!';

/// Avisos "¡Hey, listen!".
///
/// - Android: se programan con antelación (7 días, 1 día y 3 h antes de un
///   examen; 1 día y 3 h antes de una tarea) y suenan aunque la app esté cerrada.
/// - Windows: Windows no deja cancelar avisos programados sin instalar la app
///   como MSIX, así que se muestran al abrir NAVI y cada 15 min mientras esté
///   abierta, sin repetir ninguno.
class Notifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channel = AndroidNotificationDetails(
    'navi_reminders',
    'Recordatorios de NAVI',
    channelDescription: 'Exámenes y entregas próximas',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const _details = NotificationDetails(
    android: _channel,
    windows: WindowsNotificationDetails(),
  );

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;
  bool get _isWindows => !kIsWeb && Platform.isWindows;

  Future<void> init() async {
    if (!(_isAndroid || _isWindows)) return;
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Europe/Madrid'));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          windows: WindowsInitializationSettings(
            appName: 'NAVI',
            appUserModelId: 'Victor.Navi.App',
            guid: '6f1c2a9e-3b7d-4e58-9a41-2c8d5e7f0b13',
          ),
        ),
      );
      if (_isAndroid) {
        await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
      _ready = true;
    } catch (e) {
      debugPrint('Notificaciones no disponibles: $e');
    }
  }

  Future<void> test() async {
    if (!_ready) return;
    await _plugin.show(
      id: 1,
      title: heyListen,
      body: 'Las notificaciones de NAVI funcionan ✨',
      notificationDetails: _details,
    );
  }

  /// Llamar después de cada carga/sincronización.
  Future<void> refresh(List<NaviItem> items, NaviSettings? settings) async {
    if (!_ready) return;
    try {
      if (_isAndroid) {
        await _scheduleAndroid(items, settings);
      } else if (_isWindows) {
        await _digest(items, settings);
      }
    } catch (e) {
      debugPrint('Error programando avisos: $e');
    }
  }

  Future<void> canvasTokenRejected() async {
    if (!_ready) return;
    await _plugin.show(
      id: 2,
      title: heyListen,
      body: 'Canvas ha rechazado tu token. Genera uno nuevo y pégalo en Ajustes.',
      notificationDetails: _details,
    );
  }

  // ---------------------------------------------------------------- Android

  Future<void> _scheduleAndroid(
      List<NaviItem> items, NaviSettings? settings) async {
    await _plugin.cancelAllPendingNotifications();
    final now = DateTime.now();
    final alerts = <_Alert>[
      ..._tokenAlerts(settings, now),
      ..._itemAlerts(items, now),
    ]..sort((a, b) => a.at.compareTo(b.at));

    // Android limita el número de alarmas: nos quedamos con las 60 más próximas.
    for (final a in alerts.where((a) => a.at.isAfter(now)).take(60)) {
      await _plugin.zonedSchedule(
        id: a.key.hashCode & 0x7fffffff,
        title: heyListen,
        body: a.body,
        scheduledDate: tz.TZDateTime.from(a.at, tz.local),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  // ---------------------------------------------------------------- Windows

  Future<void> _digest(List<NaviItem> items, NaviSettings? settings) async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getStringList('navi_shown_alerts')?.toSet() ?? <String>{};
    final now = DateTime.now();
    final due = <_Alert>[
      ..._tokenAlerts(settings, now),
      ..._itemAlerts(items, now),
    ].where((a) => !a.at.isAfter(now) && !shown.contains(a.key)).toList()
      ..sort((a, b) => a.at.compareTo(b.at));

    // Solo el aviso más reciente de cada elemento (no 3 seguidos del mismo).
    final latestPerItem = <String, _Alert>{};
    for (final a in due) {
      latestPerItem[a.itemKey] = a;
    }
    var n = 0;
    for (final a in latestPerItem.values) {
      if (n++ < 5) {
        await _plugin.show(
          id: 100 + n,
          title: heyListen,
          body: a.item == null ? a.body : _liveText(a.item!, now),
          notificationDetails: _details,
        );
      }
    }
    for (final a in due) {
      shown.add(a.key);
    }
    // Evita que la lista crezca sin fin.
    final trimmed = shown.length > 800 ? shown.skip(shown.length - 800) : shown;
    await prefs.setStringList('navi_shown_alerts', trimmed.toList());
  }

  // ---------------------------------------------------------------- reglas

  Iterable<_Alert> _itemAlerts(List<NaviItem> items, DateTime now) sync* {
    final horizon = now.add(const Duration(days: 30));
    for (final i in items) {
      final due = i.dueAt;
      if (due == null || i.hidden) continue;
      if (i.status != ItemStatus.pending) continue;
      if (due.isAfter(horizon) || due.isBefore(now)) continue;
      final when = _whenText(i);
      final course = i.courseName == null ? '' : ' · ${i.courseName}';
      switch (i.effectiveKind) {
        case ItemKind.exam:
          yield _Alert.item(i, '${i.id}|7d', i.id, _morning(due, 7),
              'Examen en una semana: ${i.title}$course ($when)');
          yield _Alert.item(i, '${i.id}|1d', i.id, _morning(due, 1),
              'Mañana tienes examen: ${i.title}$course ($when)');
          if (!i.allDay) {
            yield _Alert.item(i, '${i.id}|3h', i.id,
                due.subtract(const Duration(hours: 3)),
                'Examen en 3 horas: ${i.title}$course');
          }
        case ItemKind.task:
          yield _Alert.item(i, '${i.id}|1d', i.id,
              due.subtract(const Duration(days: 1)),
              'Entrega mañana: ${i.title}$course ($when)');
          yield _Alert.item(i, '${i.id}|3h', i.id,
              due.subtract(const Duration(hours: 3)),
              'Quedan 3 horas para entregar: ${i.title}$course');
        case ItemKind.event:
          yield _Alert.item(i, '${i.id}|1d', i.id, _morning(due, 1),
              'Mañana: ${i.title}$course ($when)');
      }
    }
  }

  Iterable<_Alert> _tokenAlerts(NaviSettings? s, DateTime now) sync* {
    final exp = s?.tokenExpiresAt;
    if (exp == null) return;
    final key = 'token|${dateOnlyString(exp)}';
    yield _Alert('$key|3d', key, _morning(exp, 3),
        'Tu token de Canvas caduca en 3 días. Genera uno nuevo y pégalo en Ajustes.');
    yield _Alert('$key|0d', key, _morning(exp, 0),
        'Tu token de Canvas caduca hoy. Renuévalo en Ajustes.');
  }

  /// Texto calculado en el momento de mostrarse (para Windows).
  static String _liveText(NaviItem i, DateTime now) {
    final d = i.dueAt!;
    final course = i.courseName == null ? '' : ' · ${i.courseName}';
    final today = DateTime(now.year, now.month, now.day);
    final days = DateTime(d.year, d.month, d.day).difference(today).inDays;
    final hours = d.difference(now).inHours;
    final rel = days <= 0
        ? (i.allDay || hours < 1 ? 'hoy' : 'en $hours h')
        : days == 1
            ? 'mañana'
            : 'en $days días';
    final what = switch (i.effectiveKind) {
      ItemKind.exam => 'Examen $rel',
      ItemKind.task => 'Entrega $rel',
      ItemKind.event => 'Evento $rel',
    };
    return '$what: ${i.title}$course (${_whenText(i)})';
  }

  /// 09:00 del día [daysBefore] días antes de [d].
  static DateTime _morning(DateTime d, int daysBefore) =>
      DateTime(d.year, d.month, d.day - daysBefore, 9);

  static String _whenText(NaviItem i) {
    final d = i.dueAt!;
    final day = DateFormat('EEE d MMM', 'es_ES').format(d);
    return i.allDay ? day : '$day, ${DateFormat.Hm('es_ES').format(d)}';
  }
}

class _Alert {
  _Alert(this.key, this.itemKey, this.at, this.body) : item = null;
  _Alert.item(NaviItem this.item, this.key, this.itemKey, this.at, this.body);
  final NaviItem? item;
  final String key;
  final String itemKey;
  final DateTime at;
  final String body;
}
