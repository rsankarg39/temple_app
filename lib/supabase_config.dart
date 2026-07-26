/// Supabase connection settings.
///
/// Production builds should pass secrets via --dart-define (do not commit real keys):
/// ```
/// flutter build appbundle --release \
///   --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJ...
/// ```
class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://rftkomfjwswquxbhxbdc.supabase.co',
  );

  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJmdGtvbWZqd3N3cXV4Ymh4YmRjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYxNjgxOTEsImV4cCI6MjA5MTc0NDE5MX0._JajTp474vS4FP2hPPHk7RayPAObL7QtjWzvD4gqnbo',
  );
}
