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

    return LoginScaffold(
      enforceMobileMode: matrix.client.isLogged(),
      appBar: AppBar(
        automaticallyImplyLeading: !controller.isLoading,
        titleSpacing: !controller.isLoading ? 0 : null,
        title: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Login to '),
              TextSpan(
                text: 'AI Chat Chat',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ]),
            style: const TextStyle(fontSize: 18),
        ),
      ),
      body: Builder(builder: (context) {
        return AutofillGroup(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              children: <Widget>[
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
                      suffixIcon: IconButton(
                        icon: Icon(
                          controller.showPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: controller.toggleShowPassword,
                      ),
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
          ),
        );
      })
    );
  }
}
