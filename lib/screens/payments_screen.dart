import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class PaymentsScreen extends StatefulWidget {
  PaymentsScreen({super.key});

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
    final data = await SupabaseService().fetchTable('payments', orderBy: 'id');
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
          : payments.isEmpty
              ? const Center(child: Text("No payments found"))
              : ListView.builder(
                  itemCount: payments.length,
                  itemBuilder: (context, index) {
                    final pay = payments[index];
                    return Card(
                      child: ListTile(
                        title: Text("Payer: ${pay["payer"] ?? ""}"),
                        subtitle: Text("Amount: ${pay["amount"] ?? ""}, Purpose: ${pay["purpose"] ?? ""}"),
                      ),
                    );
                  },
                ),
    );
  }
}
