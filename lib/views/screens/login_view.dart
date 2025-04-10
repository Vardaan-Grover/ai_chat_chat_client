import 'package:ai_chat_chat_client/services/matrix/matrix_providers.dart';
import 'package:ai_chat_chat_client/viewmodels/login.dart';
import 'package:ai_chat_chat_client/views/layouts/login_scaffold.dart';
import 'package:flutter/material.dart';

class LoginView extends StatelessWidget {
  final LoginController controller;

  const LoginView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matrix = controller.ref.read(matrixServiceProvider);

    final homeserver = matrix
        .getLoginClient()
        .homeserver
        .toString()
        .replaceFirst('https://', '');
    final title = 'Log in to $homeserver';
    final titleParts = title.split(homeserver);

    return LoginScaffold(
      enforceMobileMode: matrix.client.isLogged(),
      appBar: AppBar(
        leading:
            controller.isLoading ? null : const Center(child: BackButton()),
        automaticallyImplyLeading: !controller.isLoading,
        titleSpacing: !controller.isLoading ? 0 : null,
        title: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: titleParts.first),
              TextSpan(
                text: homeserver,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(text: titleParts.last),
            ]),
            style: const TextStyle(fontSize: 18),
        ),
      ),
      body: Builder(builder: (context) {
        return AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: <Widget>[
              Hero(
                tag: 'info-logo',
                child: Text("AI CHAT CHAT"),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: TextField(
                  controller: controller.usernameController,
                  readOnly: controller.isLoading,
                  decoration: InputDecoration(
                    labelText: 'Username or email',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: TextField(
                  controller: controller.passwordController,
                  readOnly: controller.isLoading,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: !controller.showPassword,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed:
                    controller.isLoading ? null : controller.login,
                child:
                    Text(controller.isLoading ? 'Loading...' : 'Log in'),
              ),
            ],
          ),
        );
      })
    );
  }
}
