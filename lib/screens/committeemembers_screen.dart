import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class CommitteeMembersScreen extends StatefulWidget {
  CommitteeMembersScreen({super.key});

  @override
  State<CommitteeMembersScreen> createState() => _CommitteeMembersScreenState();
}

class _CommitteeMembersScreenState extends State<CommitteeMembersScreen> {
  List<Map<String, dynamic>> members = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    final data = await SupabaseService().fetchTable('committeemembers', orderBy: 'id');
    setState(() {
      members = data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Committee Members")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : members.isEmpty
              ? const Center(child: Text("No members found"))
              : ListView.builder(
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return Card(
                      child: ListTile(
                        title: Text(member["name"] ?? ""),
                        subtitle: Text("Role: ${member["role"] ?? ""}"),
                      ),
                    );
                  },
                ),
    );
  }
}
