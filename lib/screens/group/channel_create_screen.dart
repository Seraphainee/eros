/// Tela de criação de canal do EROS — réplica da tela "Criar Canal"
/// da referência: alternância Canal/Seção, nome, modo de voz
/// (Grátis/Admin/Em fila) e visibilidade (Público/membros/Somente
/// avisos/Privado). Quando "Privado" é selecionado, um campo de
/// senha opcional aparece — a senha protege a ENTRADA no canal;
/// nome e presença continuam visíveis a todos.
///
/// Visual: mesmo padrão da `GroupCreateScreen` — fundo preto com
/// partículas em looping (ParticleBackground) e gradiente
/// azul-escuro/roxo nos elementos principais.
///
/// Nesta etapa apenas o tipo "Canal" cria de fato (texto ou voz,
/// escolhido depois pelo dono a partir do contexto — ver TODO no
/// botão de tipo). "Seção" é só o seletor visual da referência;
/// categorias/seções ficam como extensão futura.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/channel_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';

class ChannelCreateScreen extends ConsumerStatefulWidget {
  const ChannelCreateScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<ChannelCreateScreen> createState() =>
      _ChannelCreateScreenState();
}

class _ChannelCreateScreenState extends ConsumerState<ChannelCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  static const Color _deepPurple = Color(0xFF2A1B6E);
  static const Color _deepBlue = Color(0xFF1B2A63);
  static const Color _accent = Color(0xFF6C4DFF);

  /// Tipo de canal a criar. A referência mostra "Canal" (voz+texto
  /// juntos na UI) vs "Seção" (categoria); aqui usamos para decidir
  /// se o canal criado é de voz (com modo/visibilidade) ou de texto.
  ChannelType _channelType = ChannelType.voice;
  VoiceMode _voiceMode = VoiceMode.free;
  ChannelVisibility _visibility = ChannelVisibility.public;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid) return;

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final controller = ref.read(channelCreateControllerProvider.notifier);
    await controller.createChannel(
      groupId: widget.groupId,
      name: _nameCtrl.text.trim(),
      type: _channelType,
      actingUserId: userId,
      voiceMode: _voiceMode,
      visibility: _visibility,
      password: _visibility == ChannelVisibility.private
          ? _passwordCtrl.text.trim()
          : null,
    );

    final state = ref.read(channelCreateControllerProvider);
    if (!mounted) return;
    if (state.createdChannel != null) {
      controller.reset();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(channelCreateControllerProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.6, -0.8),
            radius: 1.4,
            colors: <Color>[Color(0xFF161029), Color(0xFF000000)],
            stops: <double>[0.0, 0.75],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _buildTopBar(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _buildTypeToggle(),
                        const SizedBox(height: 20),
                        _buildTextField(),
                        const SizedBox(height: 20),
                        if (_channelType == ChannelType.voice) ...<Widget>[
                          _buildLabel('MODO DE VOZ'),
                          _buildVoiceModeSelector(),
                          const SizedBox(height: 20),
                        ],
                        _buildLabel('Visibilidade'),
                        _buildVisibilitySelector(),
                        if (_visibility == ChannelVisibility.private) ...<Widget>[
                          const SizedBox(height: 20),
                          _buildLabel('SENHA DO CANAL'),
                          _buildPasswordField(),
                        ],
                        if (state.errorMessage != null) ...<Widget>[
                          const SizedBox(height: 16),
                          Text(
                            state.errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ],
                        const SizedBox(height: 28),
                        _buildSubmitButton(state.isLoading),
                        const SizedBox(height: 24),
                      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const Expanded(
            child: Text(
              'Criar Canal',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 48), // balanceia o IconButton à esquerda
        ],
      ),
    );
  }

  Widget _buildTypeToggle() {
    return Row(
      children: <Widget>[
        Expanded(
          child: _ToggleCard(
            icon: Icons.volume_up,
            label: 'Canal',
            selected: true,
            onTap: () => setState(() {
              // "Canal" é o único tipo criável nesta etapa.
            }),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ToggleCard(
            icon: Icons.folder_outlined,
            label: 'Seção',
            selected: false,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Seções (categorias) em breve.')),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildTextField() {
    return Container(
      decoration: BoxDecoration(
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
      ),
      child: TextFormField(
        controller: _nameCtrl,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Nome',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Digite um nome para o canal.';
          }
          return null;
        },
      ),
    );
  }

  /// Campo de senha do canal — só relevante quando a visibilidade é
  /// "Privado". A senha é enviada em texto puro apenas nesta
  /// requisição; o `ChannelService` transforma em hash SHA-256 antes
  /// de gravar (ver `ChannelService.hashPassword`). Sem senha =
  /// canal privado sem proteção extra (apenas oculto na listagem).
  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
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
      ),
      child: TextFormField(
        controller: _passwordCtrl,
        obscureText: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Opcional — deixe em branco para não usar senha',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 13,
          ),
          prefixIcon: const Icon(Icons.lock_outline, color: Colors.white38, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildVoiceModeSelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        _ChoicePill(
          label: 'GRÁTIS',
          selected: _voiceMode == VoiceMode.free,
          onTap: () => setState(() => _voiceMode = VoiceMode.free),
        ),
        _ChoicePill(
          label: 'Admin',
          selected: _voiceMode == VoiceMode.admin,
          onTap: () => setState(() => _voiceMode = VoiceMode.admin),
        ),
        _ChoicePill(
          label: 'Em fila',
          selected: _voiceMode == VoiceMode.queue,
          onTap: () => setState(() => _voiceMode = VoiceMode.queue),
        ),
      ],
    );
  }

  Widget _buildVisibilitySelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        _ChoicePill(
          label: 'Público',
          selected: _visibility == ChannelVisibility.public,
          onTap: () => setState(() => _visibility = ChannelVisibility.public),
        ),
        _ChoicePill(
          label: 'membros',
          selected: _visibility == ChannelVisibility.membersOnly,
          onTap: () =>
              setState(() => _visibility = ChannelVisibility.membersOnly),
        ),
        _ChoicePill(
          label: 'Somente avisos',
          selected: _visibility == ChannelVisibility.announcementsOnly,
          onTap: () => setState(
              () => _visibility = ChannelVisibility.announcementsOnly),
        ),
        _ChoicePill(
          label: 'Privado',
          selected: _visibility == ChannelVisibility.private,
          onTap: () => setState(() => _visibility = ChannelVisibility.private),
        ),
      ],
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
                    'Criar canal',
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

/// Card grande de alternância Canal/Seção (topo da tela).
class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const Color _deepPurple = Color(0xFF2A1B6E);
  static const Color _accent = Color(0xFF6C4DFF);
  static const Color _deepBlue = Color(0xFF1B2A63);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: selected
                ? const LinearGradient(
                    colors: <Color>[_deepPurple, _accent, _deepBlue],
                  )
                : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            children: <Widget>[
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pílula de seleção única (usada em modo de voz e visibilidade).
class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const Color _accent = Color(0xFF6C4DFF);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _accent : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? _accent
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}