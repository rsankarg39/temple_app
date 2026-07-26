import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supabase/TempleRepository.dart';

class EmployeesTab extends ConsumerWidget {
  const EmployeesTab({this.readOnly = false, super.key});
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<EmployeeEntry>>(
      future: ref.read(repoProvider).getEmployees(),
      builder: (_, snapshot) {
        final employees = snapshot.data ?? [];
        if (employees.isEmpty)
          return const Center(child: Text('No employees found'));
        return ListView.builder(
          itemCount: employees.length,
          itemBuilder: (_, i) {
            final e = employees[i];
            return ListTile(
              title: Text(e.name),
              subtitle: Text(e.designation ?? 'Employee'),
              trailing: readOnly
                  ? const Icon(Icons.visibility_outlined)
                  : IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () async {
                        await ref.read(repoProvider).deleteEmployee(e.id);
                      },
                    ),
            );
          },
        );
      },
    );
  }
}
