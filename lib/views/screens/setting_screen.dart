import 'package:flutter/material.dart';

import '../widgets/language_selector_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedLanguage = "English";

  void _openLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => LanguageSelectorDialog(
        currentLanguage: _selectedLanguage,
        onSelected: (lang) {
          setState(() {
            _selectedLanguage = lang;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Language set to $lang")),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: Colors.deepPurple,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 20),

          SwitchListTile(
            value: false,
            title: const Text("Dark Mode"),
            
            onChanged: (value) => {
              value = !value,
              // Handle dark mode toggle
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Dark Mode ${value ? 'Enabled' : 'Disabled'}")),
              ),
            },
            secondary: const Icon(Icons.dark_mode),
          ),
          const Divider(),

          ListTile(
            leading: const Icon(Icons.language),
            title: const Text("Language"),
            subtitle: Text(_selectedLanguage),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _openLanguageDialog,
          ),
          const Divider(),

          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("About App"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.pushNamed(context, '/about');
            },
          ),
          const Divider(),
        ],
      ),
    );
  }
}
