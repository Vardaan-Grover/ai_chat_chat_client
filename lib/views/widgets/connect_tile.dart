import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ConnectTile extends StatelessWidget {
  final String title;
  final String assetPath;
  final VoidCallback onTap;

  const ConnectTile({
    super.key,
    required this.title,
    required this.assetPath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: SvgPicture.asset(assetPath, width: 48, height: 48),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
      trailing: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade900,
          foregroundColor: Colors.blue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          minimumSize: const Size(90, 40),
          elevation: 0,
        ),
        child: const Text(
          "Connect",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
