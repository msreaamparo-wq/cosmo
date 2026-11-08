/// Supabase URL + PUBLISHABLE key come from --dart-define. Never put a service-role/secret key here.
abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static bool get supabaseConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
  static const privacyPolicyNote =
      'Not legally reviewed. See docs/PRIVACY_AND_SECURITY.md.';
}
