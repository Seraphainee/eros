/// `EditProfileScreen` — edição do perfil do usuário.
///
/// Campos: avatar (placeholder — upload real pendente, ver TODO
/// abaixo), nome de exibição, assinatura curta e "Sobre" (bio longa).
///
/// Visual: mesmo padrão da `RegisterScreen`/`GroupCreateScreen` —
/// fundo preto com partículas (ParticleBackground) e gradiente
/// azul-escuro/roxo nos elementos principais.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/validators.dart';
import '../../core/widgets/particle_background.dart';
import '../../models/user_model.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/common/app_avatar.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, required this.user});

  final UserModel user;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _signatureCtrl;
  late final TextEditingController _bioCtrl;

  static const Color _deepPurple = Color(0xFF2A1B6E);
  static const Color _deepBlue = Color(0xFF1B2A63);
  static const Color _accent = Color(0xFF6C4DFF);

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.displayName ?? widget.user.username);
    _signatureCtrl = TextEditingController(text: widget.user.signature ?? '');
    _bioCtrl = TextEditingController(text: widget.user.bio ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _signatureCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid) return;

    final controller = ref.read(profileEditControllerProvider.notifier);
    await controller.save(
      userId: widget.user.uid,
      displayName: _nameCtrl.text.trim(),
      signature: _signatureCtrl.text.trim(),
      bio: _bioCtrl.text.trim(),
    );

    final state = ref.read(profileEditControllerProvider);
    if (!mounted) return;
    if (state.success) {
      controller.reset();
      Navigator.of(context).pop();
    }
  }

  void _onChangeAvatarTap() {
    // TODO: plugar `avatar_upload_service.dart` aqui — escolher da
    // galeria (image_picker), recortar e subir para firebase_storage,
    // depois chamar ProfileService.updateAvatarUrl com a URL resultante.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Upload de avatar ainda não implementado.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileEditControllerProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: ParticleBackground(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _buildTopBar(context),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _buildHeader(),
                            const SizedBox(height: 24),
                            _buildAvatarSection(),
                            const SizedBox(height: 28),
                            _buildLabel('Nome de exibição'),
                            _buildTextField(
                              controller: _nameCtrl,
                              hint: 'Como devemos te chamar',
                              validator: Validators.validateDisplayName,
                              textCapitalization: TextCapitalization.words,
                              maxLength: 40,
                            ),
                            const SizedBox(height: 16),
                            _buildLabel('Assinatura'),
                            _buildTextField(
                              controller: _signatureCtrl,
                              hint: 'Frase curta exibida no seu perfil',
                              validator: Validators.validateSignature,
                              maxLength: 80,
                            ),
                            const SizedBox(height: 16),
                            _buildLabel('Sobre'),
                            _buildTextField(
                              controller: _bioCtrl,
                              hint: 'Uma descrição mais completa sobre você',
                              validator: Validators.validateBio,
                              maxLines: 4,
                              maxLength: 300,
                            ),
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
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 4),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const Text(
      'Editar perfil',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: Colors.white,
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Center(
      child: GestureDetector(
        onTap: _onChangeAvatarTap,
        child: Stack(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: <Color>[_deepPurple, _accent, _deepBlue],
                ),
              ),
              child: AppAvatar(
                name: widget.user.displayName ?? widget.user.username,
                photoUrl: widget.user.avatarUrl,
                uid: widget.user.uid,
                size: 88,
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: _accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_outlined, size: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
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
    required String? Function(String?) validator,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Container(
      decoration: _fieldDecoration(),
      child: TextFormField(
        controller: controller,
        validator: validator,
        textCapitalization: textCapitalization,
        maxLines: maxLines,
        maxLength: maxLength,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
          border: InputBorder.none,
          counterStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
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
                    'Salvar alterações',
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