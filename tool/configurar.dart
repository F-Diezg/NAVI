// Ajusta las carpetas android/ y windows/ que genera `flutter create`.
// Ejecutar desde la raíz del proyecto:  dart run tool/configurar.dart
// Se puede ejecutar varias veces: solo cambia lo que falte.

import 'dart:io';

void main() {
  var changes = 0;
  changes += _manifest();
  changes += _gradle();
  changes += _windowsTitle();
  stdout.writeln(changes == 0
      ? 'Todo estaba ya configurado.'
      : 'Listo: $changes ajustes aplicados.');
}

int _manifest() {
  final f = File('android/app/src/main/AndroidManifest.xml');
  if (!f.existsSync()) {
    stdout.writeln('· No hay android/ (¿falta flutter create?). Lo salto.');
    return 0;
  }
  var s = f.readAsStringSync();
  final before = s;

  const perms = [
    'android.permission.INTERNET',
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.RECEIVE_BOOT_COMPLETED',
  ];
  final missing = perms
      .where((p) => !s.contains('android:name="$p"'))
      .map((p) => '    <uses-permission android:name="$p"/>\n')
      .join();
  if (missing.isNotEmpty) {
    final i = s.indexOf('<application');
    s = s.substring(0, i) + missing + s.substring(i);
  }

  s = s.replaceFirst(RegExp(r'android:label="[^"]*"'), 'android:label="NAVI"');

  if (!s.contains('ScheduledNotificationReceiver')) {
    const receivers = '''
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
''';
    final i = s.lastIndexOf('</application>');
    s = s.substring(0, i) + receivers + '    ' + s.substring(i);
  }

  if (s == before) return 0;
  f.writeAsStringSync(s);
  stdout.writeln('· AndroidManifest.xml: permisos, avisos y nombre NAVI');
  return 1;
}

int _gradle() {
  final kts = File('android/app/build.gradle.kts');
  final groovy = File('android/app/build.gradle');
  final isKts = kts.existsSync();
  final f = isKts ? kts : groovy;
  if (!f.existsSync()) return 0;

  var s = f.readAsStringSync();
  if (s.contains('desugar_jdk_libs')) return 0;

  final enable = isKts
      ? 'isCoreLibraryDesugaringEnabled = true'
      : 'coreLibraryDesugaringEnabled true';
  final dep = isKts
      ? 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")'
      : "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'";

  final co = RegExp(r'compileOptions\s*\{');
  final m = co.firstMatch(s);
  if (m != null) {
    s = s.replaceRange(m.end, m.end, '\n        $enable');
  } else {
    final a = RegExp(r'android\s*\{').firstMatch(s);
    if (a == null) {
      stdout.writeln('· No encuentro el bloque android { } en ${f.path}');
      return 0;
    }
    s = s.replaceRange(
        a.end, a.end, '\n    compileOptions {\n        $enable\n    }');
  }

  final d = RegExp(r'^dependencies\s*\{', multiLine: true).firstMatch(s);
  if (d != null) {
    s = s.replaceRange(d.end, d.end, '\n    $dep');
  } else {
    s = '$s\ndependencies {\n    $dep\n}\n';
  }

  f.writeAsStringSync(s);
  stdout.writeln('· ${f.path}: desugaring para las notificaciones');
  return 1;
}

int _windowsTitle() {
  final f = File('windows/runner/main.cpp');
  if (!f.existsSync()) return 0;
  final s = f.readAsStringSync();
  final out = s.replaceFirst(RegExp(r'window\.Create\(L"[^"]*"'),
      'window.Create(L"NAVI"');
  if (out == s) return 0;
  f.writeAsStringSync(out);
  stdout.writeln('· Ventana de Windows titulada NAVI');
  return 1;
}
