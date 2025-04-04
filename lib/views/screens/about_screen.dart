import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("About"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Icon & Name
            Row(
              children: const [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.deepPurple,
                  child: Icon(Icons.message, color: Colors.white, size: 30),
                ),
                SizedBox(width: 16),
                Text(
                  "Chat Chat Ai",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Description
            const Text(
              "Beeper is a fast, secure and beautifully designed ai messaging app built using Flutter. It allows real-time chat, group messaging, and more with a simple user interface.",
              style: TextStyle(fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 24),

            // Version Info
            const Text(
              "App Version",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text("1.0.0"),

            const SizedBox(height: 24),

            // Developer Info
            const Text(
              "Developed By",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text("Vansh Saini"),
            const Text("flutterdev.vansh@gmail.com"),

            const Spacer(),

            // License
            Center(
              child: TextButton(
                onPressed: () {
                  showLicensePage(
                    context: context,
                    applicationName: "Beeper",
                    applicationVersion: "1.0.0",
                    applicationLegalese: "© 2025 Vansh Saini",
                  );
                },
                child: const Text("View Licenses"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
