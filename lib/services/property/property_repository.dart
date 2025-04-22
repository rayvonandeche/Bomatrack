import 'package:bomatrack/models/property.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PropertyRepository {
  final SupabaseClient supabase;

  PropertyRepository({required this.supabase}) : _supabase = supabase;

  final SupabaseClient _supabase;

  Future<List<Property>> getProperties() async {
    try {
      final res = await _supabase.from('properties').select('*');
      return res.map((e) => Property.fromJson(e)).toList();
    } on PostgrestException catch (e) {
      throw 'Error fetching properties: ${e.message}';
    } catch (e) {
      throw Exception('Error fetching properties: $e');
    }
  }

  Future<Property?> getPropertyDetails(int id) async {
    try {
      final res = await _supabase.from('properties').select('*').eq('id', id);
      if (res.isEmpty) {
        return null;
      }
      return Property.fromJson(res.first);
    } on PostgrestException catch (e) {
      throw 'Error fetching property details: ${e.message}';
    } catch (e) {
      throw Exception('Error fetching property details: $e');
    }
  }

  Future<Property?> get firstProperty async {
    final properties = await getProperties();
    return properties.isNotEmpty ? properties.first : null;
  }
}
