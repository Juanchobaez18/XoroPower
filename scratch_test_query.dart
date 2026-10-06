import 'dart:io';
import 'package:supabase/supabase.dart';

Future<void> main() async {
  print('Starting script...');
  final supabase = SupabaseClient(
    'https://yvmxgddtnokpaibcsnkv.supabase.co',
    'sb_publishable_OW6s1SF_Hbj1P2Fk0BXQVA_GfR5WkSC',
  );

  print('Testing Student Login...');
  try {
    final response = await supabase.auth.signInWithPassword(
      email: 'test@test.com', // Try test email from test_supabase.dart
      password: 'password123',
    );
    print('Student login success: ${response.user?.id}');
  } catch (e) {
    print('Student Login Failed: $e');
  }
  
  print('Querying exercises...');
  final data = await supabase.from('exercises').select();
  print('Exercises query result length: ${data.length}');
  if (data.isNotEmpty) {
     print('First exercise: ${data.first}');
  }
  
  print('Done.');
  exit(0);
}
