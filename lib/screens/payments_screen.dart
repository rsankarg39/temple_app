import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class PaymentsScreen extends StatefulWidget {
  final String role;
  final String userId; // pass from login
  PaymentsScreen({super.key, required this.role, required this.userId});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  List<Map<String, dynamic>> payments = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchPayments();
  }

  Future<void> _fetchPayments() async {
    final data = await SupabaseService().fetchTable('payments', orderBy: 'date', ascending: false);
    setState(() {
      payments = data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Payments")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: payments.length,
              itemBuilder: (context, index) {
                final pay = payments[index];
                if (widget.role == "User" && pay["payer_id"] != widget.userId) {
                  return const SizedBox.shrink(); // hide other users' payments
                }
                return Card(
                  child: ListTile(
                    title: Text("Payer: ${pay["payer"] ?? ""}"),
                    subtitle: Text("Amount: ${pay["amount"] ?? ""}, Date: ${pay["date"] ?? ""}"),
                  ),
                );
              },
            ),
    );
  }
}
