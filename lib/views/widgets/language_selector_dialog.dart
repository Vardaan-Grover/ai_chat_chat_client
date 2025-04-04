import 'package:flutter/material.dart';

class LanguageSelectorDialog extends StatefulWidget {
  final String currentLanguage;
  final void Function(String selectedLanguage) onSelected;

  const LanguageSelectorDialog({
    super.key,
    required this.currentLanguage,
    required this.onSelected,
  });

  @override
  State<LanguageSelectorDialog> createState() => _LanguageSelectorDialogState();
}

class _LanguageSelectorDialogState extends State<LanguageSelectorDialog> {
  late String _selectedLanguage;

  final List<String> _languages = [
    "English",
    "Hindi",
    "Spanish",
    "French",
    "German",
  ];

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.currentLanguage;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Select Language"),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _languages.length,
          itemBuilder: (context, index) {
            String language = _languages[index];
            return RadioListTile(
              title: Text(language),
              value: language,
              groupValue: _selectedLanguage,
              onChanged: (value) {
                setState(() {
                  _selectedLanguage = value!;
                });
                widget.onSelected(value!);
                Navigator.pop(context);
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
      ],
    );
  }
}
