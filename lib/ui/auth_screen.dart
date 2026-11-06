import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'navi_mark.dart';

/// Inicio de sesión: la misma cuenta en el PC, el portátil y el móvil.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _msg;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = Supabase.instance.client.auth;
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      if (_register) {
        final r = await auth.signUp(
            email: _email.text.trim(), password: _pass.text);
        if (r.session == null) {
          _msg = 'Cuenta creada. Revisa tu correo para confirmarla y luego entra.';
          _register = false;
        }
      } else {
        await auth.signInWithPassword(
            email: _email.text.trim(), password: _pass.text);
      }
    } on AuthException catch (e) {
      _msg = e.message;
    } catch (e) {
      _msg = 'Error: $e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: NaviMark(size: 96)),
                const SizedBox(height: 16),
                Text('NAVI',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800, letterSpacing: 6)),
                const SizedBox(height: 4),
                Text('Tu portal personal',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 32),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                      labelText: 'Correo', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pass,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                      labelText: 'Contraseña', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_register ? 'Crear cuenta' : 'Entrar'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _register = !_register),
                  child: Text(_register
                      ? 'Ya tengo cuenta'
                      : 'Primera vez: crear cuenta'),
                ),
                if (_msg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_msg!, textAlign: TextAlign.center),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
