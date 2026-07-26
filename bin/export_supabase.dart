import 'dart:convert';
import 'dart:io';

import 'package:supabase/supabase.dart';
import 'package:temple_book_app/supabase_config.dart';

const _defaultOutputPath = 'supabase_export.json';

Future<void> main(List<String> args) async {
  final outputPath = args.isNotEmpty ? args[0] : _defaultOutputPath;
  final client = SupabaseClient(SupabaseConfig.url, SupabaseConfig.anonKey);

  stdout.writeln('Connecting to Supabase at ${SupabaseConfig.url}');

  try {
    final tables = await _fetchPublicTables(client);
    if (tables.isEmpty) {
      stdout.writeln('No public tables were found in the database.');
      exit(0);
    }

    final export = <Map<String, dynamic>>[];
    for (final tableName in tables) {
      stdout.writeln('Exporting table: $tableName');
      final schema = await _fetchTableSchema(client, tableName);
      final rows = await _fetchTableRows(client, tableName);
      export.add({
        'table_name': tableName,
        'schema': schema,
        'rows': rows,
      });
    }

    final result = {
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'table_count': export.length,
      'tables': export,
    };

    final file = File(outputPath);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(result));

    stdout.writeln('Export complete: ${file.path}');
    stdout.writeln('Total tables exported: ${export.length}');
  } catch (error, stackTrace) {
    stderr.writeln('Export failed: $error');
    stderr.writeln(stackTrace);
    exit(1);
  } finally {
    client.dispose();
  }
}

Future<List<String>> _fetchPublicTables(SupabaseClient client) async {
  final result = await client
      .from('information_schema.tables')
      .select('table_name')
      .eq('table_schema', 'public')
      .eq('table_type', 'BASE TABLE');

  return (result as List)
      .map((row) => row['table_name'] as String)
      .where((name) => name.isNotEmpty)
      .toList();
}

Future<List<Map<String, dynamic>>> _fetchTableSchema(
  SupabaseClient client,
  String tableName,
) async {
  final result = await client
      .from('information_schema.columns')
      .select(
        'column_name,data_type,is_nullable,character_maximum_length,numeric_precision,numeric_scale,ordinal_position',
      )
      .eq('table_schema', 'public')
      .eq('table_name', tableName)
      .order('ordinal_position', ascending: true);

  return (result as List)
      .map((row) => {
            'name': row['column_name'],
            'data_type': row['data_type'],
            'is_nullable': row['is_nullable'] == 'YES',
            'max_length': row['character_maximum_length'],
            'numeric_precision': row['numeric_precision'],
            'numeric_scale': row['numeric_scale'],
          })
      .toList();
}

Future<List<Map<String, dynamic>>> _fetchTableRows(
  SupabaseClient client,
  String tableName,
) async {
  final result = await client.from(tableName).select();
  return List<Map<String, dynamic>>.from(result as List);
}
