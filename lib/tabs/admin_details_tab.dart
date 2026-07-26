import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supabase/TempleRepository.dart';

class AdminDetailsTab extends ConsumerWidget {
  const AdminDetailsTab({this.readOnly = false, super.key});
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<UserProfileSummary>>(
      future: ref.read(repoProvider).getAdmins(),
      builder: (_, snapshot) {
        final admins = snapshot.data ?? [];
        if (admins.isEmpty) return const Center(child: Text('No admins found'));
        return ListView.builder(
          itemCount: admins.length,
          itemBuilder: (_, i) {
            final a = admins[i];
            return ListTile(
              title: Text(a.fullName),
              subtitle: Text(a.email ?? 'No email'),
              trailing: readOnly ? const Icon(Icons.visibility_outlined) : null,
            );
          },
        );
      },
    );
  }
}
