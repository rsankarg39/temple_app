import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class EventsScreen extends StatefulWidget {
  EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  List<Map<String, dynamic>> events = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    try {
      final data = await SupabaseService().fetchTable('events', orderBy: 'date');
      setState(() {
        events = data;
        loading = false;
      });
    } catch (e) {
      debugPrint("Error fetching events: $e");
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Events")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : events.isEmpty
              ? const Center(child: Text("No events found"))
              : ListView.builder(
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return Card(
                      child: ListTile(
                        title: Text(event["title"] ?? ""),
                        subtitle: Text("Date: ${event["date"] ?? ""}"),
                      ),
                    );
                  },
                ),
    );
  }
}
