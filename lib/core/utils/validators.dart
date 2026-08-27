/// Validadores de formulário reutilizáveis.
///
/// Mantém validações de UI separadas da lógica de negócio.
class Validators {
  Validators._();

  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'E-mail obrigatório.';
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) return 'E-mail inválido.';
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Senha obrigatória.';
    if (value.length < 8) return 'Senha precisa de pelo menos 8 caracteres.';
    if (!value.contains(RegExp(r'[A-Z]'))) return 'Inclua uma letra maiúscula.';
    if (!value.contains(RegExp(r'[a-z]'))) return 'Inclua uma letra minúscula.';
    if (!value.contains(RegExp(r'[0-9]'))) return 'Inclua um número.';
    return null;
  }

  static String? validateUsername(String? value) {
    if (value == null || value.isEmpty) return 'Nome de usuário obrigatório.';
    if (value.length < 3) return 'Mínimo de 3 caracteres.';
    if (value.length > 32) return 'Máximo de 32 caracteres.';
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!usernameRegex.hasMatch(value)) {
      return 'Apenas letras, números e _ (sublinhado).';
    }
    return null;
  }

  static String? validateGroupName(String? value) {
    if (value == null || value.isEmpty) return 'Nome do grupo obrigatório.';
    if (value.length < 3) return 'Mínimo de 3 caracteres.';
    if (value.length > 64) return 'Máximo de 64 caracteres.';
    return null;
  }

  static String? validateMessage(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (value.length > 4096) return 'Mensagem muito longa (máx. 4096 caracteres).';
    return null;
  }
}