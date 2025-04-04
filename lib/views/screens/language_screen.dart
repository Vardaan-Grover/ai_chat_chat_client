import 'package:flutter/material.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String _selectedLanguage = "English";

  final List<String> _languages = [
    "English",
    "Hindi",
    "Spanish",
    "French",
    "German",
    "Chinese",
    "Japanese",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Language"),
        backgroundColor: Colors.deepPurple,
      ),
      body: ListView.separated(
        itemCount: _languages.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          String language = _languages[index];
          return ListTile(
            title: Text(language),
            trailing: _selectedLanguage == language
                ? const Icon(Icons.check, color: Colors.deepPurple)
                : null,
            onTap: () {
              setState(() {
                _selectedLanguage = language;
              });

              // Later: Save language using ViewModel & restart localization
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Language changed to $language")),
              );
            },
          );
        },
      ),
    );
  }
}
