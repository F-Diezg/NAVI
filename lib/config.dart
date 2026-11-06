/// Claves de Supabase. Se pasan al compilar con:
///   flutter run --dart-define-from-file=config.json
/// (copia config.example.json a config.json y rellénalo).
class Config {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseKey = String.fromEnvironment('SUPABASE_KEY');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  /// Canvas de la Universidad Europea (se puede cambiar en Ajustes).
  static const defaultCanvasUrl = 'https://campus.europaeducationgroup.es';
}
