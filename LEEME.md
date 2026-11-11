# NAVI · fase 1

Portal personal para el PC de mesa, el portátil (Windows) y el Samsung A54 (Android).

Qué hace ya:

- **Canvas de la UEM**: tareas, exámenes, eventos de calendario y asistencia (si la asignatura usa Roll Call).
- **Tres vistas**: Calendario (mes / 2 semanas / semana), Asignaturas y Exámenes (todos juntos, ordenados por fecha).
- **Casillas**:
  - ✓ verde: la marcaste tú o está entregada en Canvas (se marca sola).
  - ✓ gris: examen o evento cuya fecha ya pasó (se marca solo).
  - ✗ y tachada: tarea que venció sin entregar. Si la hiciste fuera de Canvas, tócala y se marca.
- **Eventos a mano** con el botón “+ Evento”. En la fase 2 se podrán dictar por voz.
- **Avisos “¡Hey, listen!”**:
  - Exámenes: 1 semana, 1 día y 3 h antes.
  - Entregas: 1 día y 3 h antes.
  - Token: aviso 3 días antes de que caduque.
- **Los tres dispositivos ven lo mismo**: todo se guarda en tu base de datos de Supabase (gratis) con tu cuenta.

---

## 0. Antes de nada: el token

El token que pegaste en el chat ya no es secreto. Cuando tengas NAVI funcionando:

1. Ve a Canvas → **Cuenta → Configuración** y borra ese token.
2. Crea uno nuevo.
3. Pégalo **solo en NAVI** (Ajustes). No va en el código ni en ningún archivo.

Como la UEM los hace caducar a los 30 días, NAVI te avisará antes. Cada mes tendrás que repetir este paso.

## 1. Base de datos (Supabase, 5 min)

1. Crea una cuenta en <https://supabase.com> → **New project**. Región: *West EU* o *Central EU*.
2. Abre **SQL Editor → New query**, pega todo `supabase/schema.sql` y pulsa **Run**.
3. Ve a **Authentication → Sign In / Providers → Email** y desactiva **Confirm email**, para no depender del correo de confirmación.
4. Ve a **Project Settings → API Keys** y copia:
   - la **Project URL**;
   - la **Publishable key** (`sb_publishable_…`). Si solo ves claves *legacy*, vale la **anon public**.
5. En la carpeta del proyecto, copia `config.example.json` como `config.json` y pon esos dos valores.
   `config.json` no se sube a ningún sitio (está en `.gitignore`).

Cuando ya hayas creado tu cuenta en NAVI (paso 4), vuelve a **Authentication → Sign In / Providers** y desactiva **Allow new users to sign up**. Así nadie más podrá registrarse en tu NAVI.

## 2. Instalar Flutter en el PC de mesa (una sola vez)

1. Instala Flutter siguiendo la guía oficial para Windows: <https://docs.flutter.dev/get-started/install/windows>.
2. Instala **Visual Studio 2022 Community** (ojo: no es lo mismo que VS Code; VS Code sirve para editar, pero el compilador de C++ solo viene con Visual Studio) con la carga de trabajo **“Desarrollo para el escritorio con C++”**. Hace falta para compilar el `.exe`.
3. Instala **Android Studio** y, desde su *SDK Manager*, el Android SDK. Hace falta para compilar el APK.
4. En una terminal, ejecuta `flutter doctor` y `flutter doctor --android-licenses` hasta que todo salga en verde.

> ¿Prefieres no instalar Visual Studio ni Android Studio? Mira la **opción B** más abajo: GitHub compila por ti.

## 3. Preparar el proyecto (una sola vez)

Abre una terminal dentro de la carpeta `navi` y ejecuta:

```powershell
flutter create . --platforms=android,windows --project-name navi --org com.victordiez
dart run tool/configurar.dart
flutter pub get
dart run flutter_launcher_icons
```

- `flutter create` genera las carpetas `android/` y `windows/` sin tocar el código de NAVI.
- `configurar.dart` añade los permisos de notificaciones, el nombre “NAVI” y lo que pide Android para los avisos programados.
- `flutter_launcher_icons` pone el icono.

## 4. Probar y compilar

**Probar en el PC:**

```powershell
flutter run -d windows --dart-define-from-file=config.json
```

**App de Windows (PC de mesa y portátil):**

```powershell
flutter build windows --release --dart-define-from-file=config.json
```

1. Copia la carpeta entera `build\windows\x64\runner\Release` a `C:\Programas\NAVI` (o donde quieras) en cada PC.
2. Crea un acceso directo a `navi.exe` en el escritorio o anclado a Inicio.
3. Para que se abra al encender el PC, pon el acceso directo en `shell:startup`.

**App de Android (Samsung A54):**

```powershell
flutter build apk --release --dart-define-from-file=config.json
```

1. Pasa `build\app\outputs\flutter-apk\app-release.apk` al móvil (cable, Drive o Telegram a ti mismo).
2. Ábrelo y permite “instalar apps desconocidas” cuando lo pida.

También puedes conectar el A54 por USB con la depuración USB activada y ejecutar `flutter run -d <id-del-móvil> --dart-define-from-file=config.json`.

## 5. Primer uso

1. Abre NAVI → **Primera vez: crear cuenta**, con tu correo y una contraseña.
2. Ve a **Ajustes**:
   - La dirección del Canvas de la UEM (`https://campus.europaeducationgroup.es`) ya viene puesta.
   - Pega el token y pon su fecha de caducidad.
   - Pulsa **Guardar y sincronizar**.
3. En el portátil y en el móvil solo tienes que **entrar con la misma cuenta**: el token ya está guardado en tu cuenta.
4. En Android, acepta el permiso de notificaciones. En Ajustes → **Probar “¡Hey, listen!”** puedes comprobar que llegan.

## Cambiar el icono

Sustituye `assets/icon/navi.png` (1024×1024, con fondo) y `assets/icon/navi_foreground.png` (1024×1024, fondo transparente y el dibujo centrado ocupando ~60 %) por tus imágenes y ejecuta otra vez:

```powershell
dart run flutter_launcher_icons
```

## Clasificar asignaturas

En **Asignaturas**, el menú ⋮ de cada una (o dentro de ella, arriba a la derecha) permite ponerla en **Primer cuatrimestre**, **Segundo cuatrimestre** o **Relleno**. Las de relleno quedan plegadas al final y sus tareas no salen en el calendario, en Exámenes ni en los avisos.

## Cómo decide qué es examen

Canvas no tiene un tipo “examen”, así que NAVI lo deduce:

- **Por el título**: contiene *examen, parcial, prueba, midterm*… “Entrega parcial” o “proyecto” cuentan como tarea.
- **Tests y cuestionarios**: solo cuentan como examen si están en un grupo de tareas llamado *Exámenes, Pruebas* o similar.
- **Eventos del calendario** de la asignatura con esas palabras.

Si alguno sale mal, usa el menú **⋮ → “Es un examen” / “Es una tarea”**. Se recuerda y se sincroniza en los tres dispositivos.

Las tareas que no te interesen se pueden **ocultar** (⋮ → Ocultar). Para verlas otra vez, ve a Ajustes → *Mostrar elementos ocultos*.

**Asistencia**: si la asignatura usa *Roll Call Attendance* (o una tarea llamada “Asistencia”), verás el % en la tarjeta de la asignatura. Si la UEM la lleva en otro sistema, no aparecerá; en ese caso lo vemos aparte.

## Cuándo se sincroniza

- **Con Canvas**: al abrir la app si han pasado más de 2 horas, y siempre que pulses ⟳.
- **Entre dispositivos**: al volver a la app y cada 15 minutos. Si marcas algo en el móvil, el PC lo verá al volver a él.

## Opción B: que GitHub compile por ti (la que usamos)

Cada vez que se sube un cambio a `main`, GitHub compila NAVI y lo publica en la página de descargas del repo:
**<https://github.com/F-Diezg/NAVI/releases/latest>**

Necesita dos secretos en el repo (**Settings → Secrets and variables → Actions**): `SUPABASE_URL` y `SUPABASE_KEY`. Sin ellos la compilación se para con un aviso.

**Instalar en el Samsung A54**
1. Abre ese enlace en Chrome desde el móvil y toca **NAVI.apk**.
2. Cuando Chrome avise de que el archivo puede ser dañino, toca **Descargar de todos modos**.
3. Abre el archivo descargado. La primera vez Android pedirá permiso: **Ajustes → Permitir de esta fuente** (para Chrome) y vuelve atrás.
4. Toca **Instalar**. Si Play Protect avisa de "app no reconocida", toca **Más detalles → Instalar de todos modos**.

**Instalar en Windows**
1. Descarga **NAVI-windows.zip** y descomprímelo en una carpeta fija (por ejemplo `C:\Programas\NAVI`).
2. Abre `navi.exe`. Si sale "Windows protegió su PC", pulsa **Más información → Ejecutar de todas formas**.
3. Clic derecho en `navi.exe` → **Anclar a Inicio** o crea un acceso directo.

**Actualizar**: repite lo mismo. Como cada compilación de GitHub firma el APK con una clave distinta, en Android puede que tengas que desinstalar la versión anterior antes de instalar la nueva. Tus datos no se pierden: están en la nube.

## Problemas frecuentes

- **“requires Android NDK …”**: abre `android/app/build.gradle.kts` y cambia `ndkVersion = flutter.ndkVersion` por la versión que diga el error, entre comillas.
- **“Canvas ha rechazado el token”**: ha caducado o lo has borrado. Crea uno nuevo y pégalo en Ajustes.
- **No aparece nada tras sincronizar**: comprueba la dirección de Canvas en Ajustes. Tiene que ser la que ves en el navegador, sin nada detrás de `.com`.
- **Pantalla “Faltan las claves de Supabase”**: has ejecutado sin `--dart-define-from-file=config.json`.

## Próximas fases

1. **Voz**: dictar “examen de Termodinámica el 12 de diciembre a las 10” y que se cree el evento.
2. **Daily**: política española de medios independientes, sector aeroespacial y defensa.
3. **YouTube**: pestaña con los vídeos nuevos de tus canales (por RSS, sin claves).

## Estructura

```
lib/
  main.dart              arranque, login, tema
  app_state.dart         estado, sincronización, acciones
  canvas_api.dart        API de Canvas + reglas examen/tarea/asistencia
  repo.dart              lectura/escritura en Supabase
  notifications.dart     avisos "¡Hey, listen!"
  models.dart            NaviItem, Course, NaviSettings
  ui/                    pantallas (calendario, asignaturas, exámenes, ajustes…)
supabase/schema.sql      tablas + seguridad por usuario
tool/configurar.dart     ajustes de Android/Windows tras flutter create
test/                    pruebas de las reglas
.github/workflows/       compilación automática (opción B)
```
