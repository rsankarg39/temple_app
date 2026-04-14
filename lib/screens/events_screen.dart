import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

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
    final response = await Supabase.instance.client
        .from('Events')
        .select()
        .order('date', ascending: true);

    setState(() {
      events = List<Map<String, dynamic>>.from(response);
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
    if (loading) {
      return const Scaffold(
        appBar: AppBar(title: Text("Events")),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Events")),
      body: ListView.builder(
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