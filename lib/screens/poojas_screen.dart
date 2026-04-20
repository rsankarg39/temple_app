import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class PoojasScreen extends StatefulWidget {
  final String role;
  PoojasScreen({super.key, required this.role});

  @override
  State<PoojasScreen> createState() => _PoojasScreenState();
}

class _PoojasScreenState extends State<PoojasScreen> {
  List<Map<String, dynamic>> poojas = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchPoojas();
  }

  Future<void> _fetchPoojas() async {
    final data = await SupabaseService().fetchTable('poojas', orderBy: 'id');
    setState(() {
      poojas = data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Poojas")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : poojas.isEmpty
              ? const Center(child: Text("No poojas found"))
              : ListView.builder(
                  itemCount: poojas.length,
                  itemBuilder: (context, index) {
                    final pooja = poojas[index];
                    return Card(
                      child: ListTile(
                        title: Text(pooja["name"] ?? ""),
                        subtitle: Text(pooja["description"] ?? ""),
                      ),
                    );
                  },
                ),
    );
  }
}
