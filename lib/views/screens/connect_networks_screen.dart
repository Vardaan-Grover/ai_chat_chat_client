import 'package:flutter/material.dart';
import '../widgets/connect_tile.dart';

class ConnectNetworksScreen extends StatelessWidget {
  const ConnectNetworksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.bug_report_outlined),
            color: Colors.deepPurpleAccent,
          ),
        ],
      ),
      body: Column(
        children: [
          Text(
            "Connect Networks",
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w500,
              color: Colors.purple,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              "Tap to connect your networks to chat chat ai.",
              style: TextStyle(color: Colors.grey, fontSize: 20),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                ConnectTile(
                  title: "WhatsApp",
                  assetPath: "assets/icons/whatsapp.svg",
                  onTap: () {},
                ),
                SizedBox(height: 20),
                ConnectTile(
                  title: "Instagram",
                  assetPath: "assets/icons/instagram.svg",
                  onTap: () {},
                ),
                ConnectTile(
                  title: "Messenger",
                  assetPath: "assets/icons/messenger.svg",
                  onTap: () {},
                ),
                ConnectTile(
                  title: "RCS / SMS",
                  assetPath: "assets/icons/sms.svg",
                  onTap: () {},
                ),
                ConnectTile(
                  title: "Signal",
                  assetPath: "assets/icons/signal.svg",
                  onTap: () {},
                ),
                ConnectTile(
                  title: "Discord",
                  assetPath: "assets/icons/discord.svg",
                  onTap: () {},
                ),
                ConnectTile(
                  title: "Telegram",
                  assetPath: "assets/icons/telegram.svg",
                  onTap: () {},
                ),
                ConnectTile(
                  title: "Google Chat",
                  assetPath: "assets/icons/google_chat.svg",
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
