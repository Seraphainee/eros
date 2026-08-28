/// Tela de cadastro do EROS.
///
/// Campos: nome de exibição, username (@handle), e-mail, senha
/// (com botão de mostrar/ocultar), data de nascimento (checagem de
/// idade mínima) e aceite de Termos de Uso + Política de Privacidade.
///
/// Visual: fundo preto com partículas azul-escuro/roxo em looping
/// (ParticleBackground) e gradiente azul-escuro quase roxo nos
/// elementos principais.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/validators.dart';
import '../../core/widgets/particle_background.dart';
import '../../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.onSwitchToLogin});

  /// Chamado quando o usuário toca em "Já tem conta? Entrar".
  final VoidCallback? onSwitchToLogin;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  DateTime? _birthDate;
  bool _obscurePassword = true;
  bool _acceptedTerms = false;
  String? _birthDateError;
  String? _termsError;

  static const Color _deepPurple = Color(0xFF2A1B6E);
  static const Color _deepBlue = Color(0xFF1B2A63);
  static const Color _accent = Color(0xFF6C4DFF);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initialDate = DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? initialDate,
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: 'Data de nascimento',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: _accent,
                  surface: const Color(0xFF17172A),
                ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _birthDateError = Validators.validateBirthDate(picked);
      });
    }
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  Future<void> _submit() async {
    final formValid = _formKey.currentState?.validate() ?? false;
    final birthDateError = Validators.validateBirthDate(_birthDate);

    setState(() {
      _birthDateError = birthDateError;
      _termsError = _acceptedTerms ? null : 'É necessário aceitar os termos.';
    });

    if (!formValid || birthDateError != null || !_acceptedTerms) return;

    final controller = ref.read(authControllerProvider.notifier);
    await controller.signUp(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      username: _usernameCtrl.text.trim(),
      displayName: _nameCtrl.text.trim(),
      birthDate: _birthDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: ParticleBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _buildHeader(),
                      const SizedBox(height: 32),
                      _buildLabel('Nome'),
                      _buildTextField(
                        controller: _nameCtrl,
                        hint: 'Como devemos te chamar',
                        keyboardType: TextInputType.name,
                        validator: Validators.validateDisplayName,
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),
                      _buildLabel('Username'),
                      _buildTextField(
                        controller: _usernameCtrl,
                        hint: '@seuusuario',
                        keyboardType: TextInputType.text,
                        validator: Validators.validateUsername,
                        prefixText: '@',
                      ),
                      const SizedBox(height: 16),
                      _buildLabel('E-mail'),
                      _buildTextField(
                        controller: _emailCtrl,
                        hint: 'seuemail@exemplo.com',
                        keyboardType: TextInputType.emailAddress,
                        validator: Validators.validateEmail,
                      ),
                      const SizedBox(height: 16),
                      _buildLabel('Senha'),
                      _buildPasswordField(),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 4, top: 4),
                        child: Text(
                          'Mínimo de 6 caracteres — não precisa misturar letras e números.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildLabel('Data de nascimento'),
                      _buildBirthDatePicker(),
                      const SizedBox(height: 20),
                      _buildTermsCheckbox(),
                      if (state.errorMessage != null) ...<Widget>[
                        const SizedBox(height: 16),
                        Text(
                          state.errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ],
                      const SizedBox(height: 24),
                      _buildSubmitButton(state.isLoading),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: widget.onSwitchToLogin,
                          child: const Text(
                            'Já tem conta? Entrar',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: <Widget>[
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: <Color>[_deepPurple, _accent, _deepBlue],
          ).createShader(bounds),
          child: const Text(
            'EROS',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              letterSpacing: 6,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Crie sua conta para começar.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.75),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  BoxDecoration _fieldDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          _deepPurple.withValues(alpha: 0.35),
          _deepBlue.withValues(alpha: 0.35),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required TextInputType keyboardType,
    required String? Function(String?) validator,
    String? prefixText,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Container(
      decoration: _fieldDecoration(),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        textCapitalization: textCapitalization,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
          prefixText: prefixText,
          prefixStyle: const TextStyle(color: Colors.white70),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      decoration: _fieldDecoration(),
      child: TextFormField(
        controller: _passwordCtrl,
        obscureText: _obscurePassword,
        validator: Validators.validatePassword,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Crie uma senha',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: Colors.white54,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
      ),
    );
  }

  Widget _buildBirthDatePicker() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _pickBirthDate,
      child: Container(
        decoration: _fieldDecoration().copyWith(
          border: Border.all(
            color: _birthDateError != null
                ? Colors.redAccent.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: <Widget>[
            const Icon(Icons.cake_outlined, color: Colors.white54, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _birthDate != null ? _formatDate(_birthDate!) : 'Selecione sua data de nascimento',
                style: TextStyle(
                  color: _birthDate != null ? Colors.white : Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ),
            const Icon(Icons.calendar_today_outlined, color: Colors.white38, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Checkbox(
              value: _acceptedTerms,
              activeColor: _accent,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
              onChanged: (value) {
                setState(() {
                  _acceptedTerms = value ?? false;
                  if (_acceptedTerms) _termsError = null;
                });
              },
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      'Li e aceito os ',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
                    ),
                    _linkButton('Termos de Uso', _openTerms),
                    Text(
                      ' e a ',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
                    ),
                    _linkButton('Política de Privacidade', _openPrivacyPolicy),
                    Text(
                      '.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_termsError != null)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              _termsError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _linkButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: const TextStyle(
          color: _accent,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: _accent,
        ),
      ),
    );
  }

  void _openTerms() {
    // TODO: substituir por navegação/URL real dos Termos de Uso quando
    // o link estiver disponível (ex: via url_launcher para o Blogger).
  }

  void _openPrivacyPolicy() {
    // TODO: substituir por navegação/URL real da Política de Privacidade
    // quando o link estiver disponível (ex: via url_launcher para o Blogger).
  }

  Widget _buildSubmitButton(bool isLoading) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[_deepPurple, _accent, _deepBlue],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _accent.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isLoading ? null : _submit,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Criar conta',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}