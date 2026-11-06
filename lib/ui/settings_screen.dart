import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../canvas_api.dart';
import '../config.dart';
import 'format.dart';
import 'widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _url = TextEditingController();
  final _token = TextEditingController();
  DateTime? _expires;
  bool _showToken = false;
  bool _saving = false;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = AppScope.of(context).settings;
    if (!_loaded && s != null) {
      _loaded = true;
      _url.text = s.canvasUrl;
      _token.text = s.canvasToken ?? '';
      _expires = s.tokenExpiresAt;
    }
  }

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final state = AppScope.read(context);
    if (_token.text.trim().isEmpty) {
      showSnack(context, 'Pega el token de Canvas');
      return;
    }
    setState(() => _saving = true);
    try {
      await state.saveCanvasCredentials(
        _url.text.isEmpty ? Config.defaultCanvasUrl : _url.text,
        _token.text,
        _expires ?? DateTime.now().add(const Duration(days: 30)),
      );
      if (mounted) showSnack(context, state.info ?? 'Guardado');
    } on CanvasException catch (e) {
      if (mounted) showSnack(context, e.message);
    } catch (e) {
      if (mounted) showSnack(context, 'No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _expires ?? now.add(const Duration(days: 30)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 400)),
      helpText: 'Fecha de caducidad del token',
    );
    if (d != null) setState(() => _expires = d);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final s = state.settings;
    final user = Supabase.instance.client.auth.currentUser;
    final daysLeft = s?.daysToTokenExpiry(DateTime.now());

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        SectionHeader('Canvas · Universidad Europea'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (daysLeft != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      daysLeft < 0
                          ? 'El token caducó: genera uno nuevo.'
                          : daysLeft == 0
                              ? 'El token caduca hoy.'
                              : 'El token caduca en $daysLeft días.',
                      style: TextStyle(
                        color: daysLeft <= 3
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                TextField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Dirección de Canvas',
                    hintText: Config.defaultCanvasUrl,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _token,
                  obscureText: !_showToken,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Token de acceso',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_showToken
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded),
                      onPressed: () =>
                          setState(() => _showToken = !_showToken),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickExpiry,
                  icon: const Icon(Icons.event_busy_rounded),
                  label: Text(_expires == null
                      ? 'Caduca el… (por defecto, en 30 días)'
                      : 'Caduca el ${fmtDay(_expires!)}'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.link_rounded),
                  label: const Text('Guardar y sincronizar'),
                ),
                const SizedBox(height: 10),
                Text(
                  'Cómo sacar el token: en Canvas → Cuenta → Configuración → '
                  '"+ Nuevo token de acceso". Se guarda en tu cuenta de NAVI, '
                  'así que basta con pegarlo en un dispositivo.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.sync_rounded),
            title: const Text('Sincronizar ahora'),
            subtitle: Text(s?.lastCanvasSync == null
                ? 'Nunca'
                : 'Última: ${fmtDay(s!.lastCanvasSync!)} · '
                    '${fmtTime(s.lastCanvasSync!)}'),
            trailing: state.syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : null,
            onTap: state.syncing ? null : state.syncCanvas,
          ),
        ),
        SectionHeader('Avisos'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.notifications_active_rounded),
            title: const Text('Probar "¡Hey, listen!"'),
            subtitle: const Text(
                'Exámenes: 1 semana, 1 día y 3 h antes · Entregas: 1 día y 3 h antes'),
            onTap: () => state.notifier.test(),
          ),
        ),
        SectionHeader('Vista'),
        Card(
          child: SwitchListTile(
            secondary: const Icon(Icons.visibility_off_outlined),
            title: const Text('Mostrar elementos ocultos'),
            subtitle: Text('${state.hiddenCount} ocultos'),
            value: state.showHidden,
            onChanged: (_) => state.toggleShowHidden(),
          ),
        ),
        SectionHeader('Cuenta'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.person_rounded),
            title: Text(user?.email ?? '—'),
            subtitle: const Text('Usa esta cuenta en tus 3 dispositivos'),
            trailing: TextButton(
              onPressed: () => Supabase.instance.client.auth.signOut(),
              child: const Text('Cerrar sesión'),
            ),
          ),
        ),
      ],
    );
  }
}
