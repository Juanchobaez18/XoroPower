import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xoropower/core/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ApiClient starts without an authenticated session', () async {
    SharedPreferences.setMockInitialValues({});
    final supabase = SupabaseClient(
      'https://example.supabase.co',
      'test-publishable-key',
    );
    final api = ApiClient(supabaseClient: supabase);
    addTearDown(api.dispose);

    await api.init();

    expect(api.isAuthenticated, isFalse);
    expect(api.isAdmin, isFalse);
    expect(api.currentName, 'Estudiante');
    expect(api.currentEmail, isNull);
  });
}
