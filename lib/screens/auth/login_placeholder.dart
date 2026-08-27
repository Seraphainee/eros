/// Placeholder de login para a Etapa 3.
///
/// Tela completa (com formulário, signup, recovery) será
/// implementada quando o `ProfileService` existir (Etapa 3.5)
/// — antes disso, criar conta de teste direto pelo Firebase
/// Console e logar por aqui já permite testar o chat.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';

class LoginPlaceholder extends ConsumerStatefulWidget {
  const LoginPlaceholder({super.key});

  @override
  ConsumerState<LoginPlaceholder> createState() => _LoginPlaceholderState();
}

class _LoginPlaceholderState extends ConsumerState<LoginPlaceholder> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLogin = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = ref.read(authControllerProvider.notifier);
    if (_isLogin) {
      await controller.signIn(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
    } else {
      await controller.signUp(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        username: _emailCtrl.text.split('@').first,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Entrar' : 'Criar conta')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 32),
                Text(
                  'EROS',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _isLogin
                      ? 'Entre para começar.'
                      : 'Crie sua conta (username provisório = prefixo do e-mail).',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                  validator: Validators.validateEmail,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Senha'),
                  validator: Validators.validatePassword,
                ),
                if (state.errorMessage != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    state.errorMessage!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: state.isLoading ? null : _submit,
                  child: state.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isLogin ? 'Entrar' : 'Criar conta'),
                ),
                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(_isLogin
                      ? 'Não tem conta? Criar'
                      : 'Já tem conta? Entrar'),
                ),
                TextButton(
                  onPressed: state.isLoading
                      ? null
                      : () async {
                          if (_emailCtrl.text.isEmpty) return;
                          await ref
                              .read(authControllerProvider.notifier)
                              .recoverPassword(_emailCtrl.text.trim());
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Se a conta existir, um e-mail foi enviado.',
                              ),
                            ),
                          );
                        },
                  child: const Text('Esqueci minha senha'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
