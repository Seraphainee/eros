/// `ProfileScreen` — visualização do perfil do próprio usuário.
///
/// Mostra avatar, nome de exibição, @username, assinatura curta,
/// seção "Sobre" (bio) e um bloco de informações gerais.
///
/// Visual: mesmo padrão de login/registro — fundo preto com
/// partículas em looping (ParticleBackground) e gradiente
/// azul-escuro/roxo nos elementos de destaque.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_utils.dart' as app_date;
import '../../core/widgets/particle_background.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/common/app_avatar.dart';
import '../../widgets/common/loading_indicator.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const Color _deepPurple = Color(0xFF2A1B6E);
  static const Color _deepBlue = Color(0xFF1B2A63);
  static const Color _accent = Color(0xFF6C4DFF);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authControllerProvider).user;
    if (authUser == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: LoadingIndicator(label: 'Autenticando…'),
      );
    }

    final profileAsync = ref.watch(profileStreamProvider(authUser.uid));

    return Scaffold(
      backgroundColor: Colors.black,
      body: ParticleBackground(
        child: SafeArea(
          child: profileAsync.when(
            loading: () => const LoadingIndicator(),
            error: (e, _) => Center(
              child: Text('Erro: $e', style: const TextStyle(color: Colors.white70)),
            ),
            data: (profile) {
              // Enquanto o documento de perfil ainda não existe no
              // Firestore (ver TODO em auth_service.dart), cai para
              // os dados básicos vindos do Firebase Auth.
              final user = profile ?? authUser;
              return _ProfileContent(user: user);
            },
          ),
        ),
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.user});
  final UserModel user;

  static const Color _deepPurple = Color(0xFF2A1B6E);
  static const Color _deepBlue = Color(0xFF1B2A63);
  static const Color _accent = Color(0xFF6C4DFF);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildTopBar(context),
            const SizedBox(height: 8),
            _buildAvatarAndName(context),
            const SizedBox(height: 24),
            if (user.signature != null && user.signature!.trim().isNotEmpty) ...<Widget>[
              Text(
                user.signature!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 24),
            ],
            _buildSectionLabel('INFORMAÇÕES GERAIS'),
            _buildInfoCard(context),
            if (user.bio != null && user.bio!.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 24),
              _buildSectionLabel('SOBRE'),
              _buildBioCard(),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.edit_outlined, color: Colors.white70),
          tooltip: 'Editar perfil',
          onPressed: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => EditProfileScreen(user: user),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAvatarAndName(BuildContext context) {
    return Column(
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
            name: user.displayName ?? user.username,
            photoUrl: user.avatarUrl,
            uid: user.uid,
            size: 96,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          user.displayName ?? user.username,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '@${user.username}',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.55),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          _deepPurple.withValues(alpha: 0.25),
          _deepBlue.withValues(alpha: 0.25),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: <Widget>[
          _infoRow('Nome de exibição', user.displayName ?? user.username),
          _divider(),
          _infoRow('Nome de usuário', user.username),
          _divider(),
          _infoRow('E-mail', user.email),
          if (user.birthDate != null) ...<Widget>[
            _divider(),
            _infoRow(
              'Data de nascimento',
              '${app_date.DateUtils.formatDate(user.birthDate!)} (${_calculateAge(user.birthDate!)} anos)',
            ),
          ],
        ],
      ),
    );
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    final hasHadBirthdayThisYear = (now.month > birthDate.month) ||
        (now.month == birthDate.month && now.day >= birthDate.day);
    if (!hasHadBirthdayThisYear) age -= 1;
    return age;
  }

  Widget _buildBioCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Text(
        user.bio!,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), height: 1.4),
      ),
    );
  }

  Widget _divider() {
    return Divider(height: 1, color: Colors.white.withValues(alpha: 0.06));
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}