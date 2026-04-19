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
    final data = await SupabaseService().fetchTable('poojas', orderBy: 'date');
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
          : ListView.builder(
              itemCount: poojas.length,
              itemBuilder: (context, index) {
                final pooja = poojas[index];
                return Card(
                  child: ListTile(
                    title: Text(pooja["pooja_name"] ?? ""),
                    subtitle: Text("Date: ${pooja["date"] ?? ""}"),
                    trailing: widget.role == "Admin"
                        ? IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              // TODO: implement delete
                            },
                          )
                        : null,
                  ),
                );
              },
            ),
    );
  }
}
