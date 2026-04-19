import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class FamilyHeadsScreen extends StatefulWidget {
  final String role; // pass role from dashboard
  FamilyHeadsScreen({super.key, required this.role});

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
    final data = await SupabaseService().fetchTable('familyheads', orderBy: 'name');
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
          : ListView.builder(
              itemCount: familyHeads.length,
              itemBuilder: (context, index) {
                final fh = familyHeads[index];
                return Card(
                  child: ListTile(
                    title: Text(fh["name"] ?? ""),
                    subtitle: Text(_maskData(fh)),
                  ),
                );
              },
            ),
    );
  }

  String _maskData(Map<String, dynamic> fh) {
    if (widget.role == "Admin") {
      return "Phone: ${fh["phone"] ?? ""}, Address: ${fh["address"] ?? ""}";
    } else if (widget.role == "Committee") {
      return "Phone: ****${fh["phone"]?.toString().substring(fh["phone"].length - 2)}";
    } else {
      return "Details hidden";
    }
  }
}
