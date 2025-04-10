import 'package:flutter/material.dart';
import 'package:ai_chat_chat_client/config/app_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

class HomeserverPicker extends ConsumerStatefulWidget {
  final bool addMultiAccount;

  const HomeserverPicker({required this.addMultiAccount, super.key});

  @override
  ConsumerState<HomeserverPicker> createState() => HomeserverPickerController();
}

class HomeserverPickerController extends ConsumerState<HomeserverPicker> {
  final Logger logger = Logger('HomeserverPickerController');

  final TextEditingController homeserverController = TextEditingController(
    text: AppConfig.defaultHomeserver,
  );

  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Placeholder();
  }
}
