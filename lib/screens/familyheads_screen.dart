import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class FamilyHeadsScreen extends StatefulWidget {
  FamilyHeadsScreen({super.key});

  @override
  State<FamilyHeadsScreen> createState() => _FamilyHeadsScreenState();
}

class _FamilyHeadsScreenState extends State<FamilyHeadsScreen> {
  List<Map<String, dynamic>> familyHeads = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchFamilyHeads();
  }

  Future<void> _fetchFamilyHeads() async {
    final data = await SupabaseService().fetchTable('familyheads', orderBy: 'id');
    setState(() {
      familyHeads = data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Family Heads")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : familyHeads.isEmpty
              ? const Center(child: Text("No family heads found"))
              : ListView.builder(
                  itemCount: familyHeads.length,
                  itemBuilder: (context, index) {
                    final fh = familyHeads[index];
                    return Card(
                      child: ListTile(
                        title: Text(fh["name"] ?? ""),
                        subtitle: Text("Phone: ${fh["phone"] ?? ""}, Nakshatram: ${fh["nakshatram"] ?? ""}"),
                      ),
                    );
                  },
                ),
    );
  }
}
