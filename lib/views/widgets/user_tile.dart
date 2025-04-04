import 'package:flutter/material.dart';

class UserTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final String trailingText;
  final VoidCallback? onTap;
  final Widget? leading;

  const UserTile({
    super.key,
    required this.name,
    required this.subtitle,
    required this.trailingText,
    this.onTap,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: leading ??
          const CircleAvatar(
            radius: 24,
            backgroundColor: Colors.deepPurple,
            child: Icon(Icons.person, color: Colors.white),
          ),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        trailingText,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
    );
  }
}
