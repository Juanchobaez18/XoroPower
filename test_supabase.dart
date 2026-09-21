import 'package:supabase/supabase.dart';

Future<void> main() async {
  final supabase = SupabaseClient(
    'https://yvmxgddtnokpaibcsnkv.supabase.co',
    'sb_publishable_OW6s1SF_Hbj1P2Fk0BXQVA_GfR5WkSC',
  );

  print('Testing Admin Login...');
  try {
    final response = await supabase.auth.signInWithPassword(
      email: 'admin@admin.com',
      password: '123456',
    );
    print('Admin Login Success! User ID: ${response.user?.id}');
  } catch (e) {
    print('Admin Login Failed: $e');
  }

  print('\nTesting Student Registration...');
  final testEmail = 'test_${DateTime.now().millisecondsSinceEpoch}@test.com';
  try {
    final response = await supabase.auth.signUp(
      email: testEmail,
      password: 'password123',
      data: {'name': 'Test User'},
    );
    print('Registration Success! User ID: ${response.user?.id}');
    
    // Test if user is in public.users
    print('\nVerifying user in public.users...');
    final data = await supabase.from('users').select().eq('email', testEmail);
    print('Public users query result: $data');

  } catch (e) {
    print('Registration/Query Failed: $e');
  }
}
