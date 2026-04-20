import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class EmployeesScreen extends StatefulWidget {
  EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  List<Map<String, dynamic>> employees = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    final data = await SupabaseService().fetchTable('employees', orderBy: 'id');
    setState(() {
      employees = data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Employees")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : employees.isEmpty
              ? const Center(child: Text("No employees found"))
              : ListView.builder(
                  itemCount: employees.length,
                  itemBuilder: (context, index) {
                    final employee = employees[index];
                    return Card(
                      child: ListTile(
                        title: Text(employee["name"] ?? ""),
                        subtitle: Text("Designation: ${employee["designation"] ?? ""}"),
                      ),
                    );
                  },
                ),
    );
  }
}
