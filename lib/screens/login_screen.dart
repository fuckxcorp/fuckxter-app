import 'package:flutter/material.dart';

import '../models/account.dart';
import '../services/fuckxter_api.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.api});

  final FuckXterApi api;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final code = TextEditingController();
  bool loading = false;
  bool needsCode = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final account = await widget.api.signIn(
        email.text.trim(),
        password.text,
        code: needsCode ? code.text.trim() : null,
      );
      if (mounted) Navigator.pop(context, account);
    } on ApiException catch (e) {
      if (e.code == 'TWO_FACTOR_REQUIRED') {
        setState(() => needsCode = true);
      } else {
        setState(() => error = e.message);
      }
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('登录 FuckXter')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 36),
                const Text('FuckXter',
                    style:
                        TextStyle(fontSize: 42, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text('未注册邮箱会自动创建账号',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 28),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username],
                  decoration: const InputDecoration(
                      labelText: '邮箱', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(
                      labelText: '密码', border: OutlineInputBorder()),
                ),
                if (needsCode) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: code,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: '动态验证码', border: OutlineInputBorder()),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: loading ? null : submit,
                  child: Text(loading
                      ? '登录中…'
                      : needsCode
                          ? '验证并登录'
                          : '登录 / 注册'),
                ),
              ],
            ),
          ),
        ),
      );
}
