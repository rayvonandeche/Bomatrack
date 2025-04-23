import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static init() async => await Supabase.initialize(
      url: 'https://iodfgbwsxgsiugbvfxbs.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlvZGZnYndzeGdzaXVnYnZmeGJzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzA5MDM4MDYsImV4cCI6MjA0NjQ3OTgwNn0.WF05jQdqovJwCMLeDsa3KVNQByNUdIhwjVsgeRNUkHw');
  
  static SupabaseClient get supabase => Supabase.instance.client;
}
