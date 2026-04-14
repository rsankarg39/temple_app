import 'package:flutter/material.dart';
import 'events_screen.dart';

class CommitteeDashboard extends StatefulWidget {
  const CommitteeDashboard({super.key});

  @override
  State<CommitteeDashboard> createState() => _CommitteeDashboardState();
}

class _CommitteeDashboardState extends State<CommitteeDashboard> {
  String _currentPage = "Events"; // Default page

  void _selectPage(String page) {
    setState(() {
      _currentPage = page;
    });
    Navigator.pop(context); // close drawer after selection
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Committee Dashboard - $_currentPage")),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurple),
              child: Text("Temple App Menu", style: TextStyle(color: Colors.white)),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text("Home (Events)"),
              onTap: () => _selectPage("Events"),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text("Family Heads"),
              onTap: () => _selectPage("Family Heads"),
            ),
            ListTile(
              leading: const Icon(Icons.work),
              title: const Text("Employees"),
              onTap: () => _selectPage("Employees"),
            ),
            ListTile(
              leading: const Icon(Icons.receipt),
              title: const Text("Temple Charges"),
              onTap: () => _selectPage("Temple Charges"),
            ),
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text("Events"),
              onTap: () => _selectPage("Events"),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text("Poojas"),
              onTap: () => _selectPage("Poojas"),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: () {
                Navigator.pop(context); // close drawer
                Navigator.pushReplacementNamed(context, "/"); // back to login
              },
            ),
          ],
        ),
      ),
      body: _currentPage == "Events"
          ? EventsScreen() // show Supabase events
          : Center(child: Text(_currentPage, style: const TextStyle(fontSize: 20))),
    );
  }
}