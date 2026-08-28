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
    if (value.length < 6) return 'Senha precisa de pelo menos 6 caracteres.';
    return null;
  }

  static String? validateDisplayName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Nome obrigatório.';
    if (value.trim().length < 2) return 'Mínimo de 2 caracteres.';
    if (value.trim().length > 40) return 'Máximo de 40 caracteres.';
    return null;
  }

  /// Idade mínima exigida para uso do app.
  static const int minAge = 18;

  static String? validateBirthDate(DateTime? value) {
    if (value == null) return 'Selecione sua data de nascimento.';
    final now = DateTime.now();
    var age = now.year - value.year;
    final hasHadBirthdayThisYear = (now.month > value.month) ||
        (now.month == value.month && now.day >= value.day);
    if (!hasHadBirthdayThisYear) age -= 1;
    if (age < minAge) return 'Você precisa ter $minAge anos ou mais.';
    if (value.isAfter(now)) return 'Data inválida.';
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