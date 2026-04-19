import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchTable(String table,
      {String orderBy = 'id', bool ascending = true}) async {
    final response = await client
        .from(table)
        .select()
        .order(orderBy, ascending: ascending);

    return (response as List)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }
}
