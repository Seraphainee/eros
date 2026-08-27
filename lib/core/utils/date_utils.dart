/// Utilitários de data e hora.
///
/// Funções de formatação e comparação de datas used throughout the app.
import 'package:intl/intl.dart';

class DateUtils {
  DateUtils._();

  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static final _timeFormat = DateFormat('HH:mm');
  static final _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final _relativeFormat = DateFormat('dd MMM');

  /// Formata uma data para exibição amigável.
  static String formatDate(DateTime date) => _dateFormat.format(date);

  /// Formata hora (HH:mm).
  static String formatTime(DateTime date) => _timeFormat.format(date);

  /// Formata data e hora completos.
  static String formatDateTime(DateTime date) => _dateTimeFormat.format(date);

  /// Formata data relativa: "Hoje", "Ontem", "27 ago" ou data completa.
  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(dateDay).inDays;

    if (diff == 0) return 'Hoje ${_timeFormat.format(date)}';
    if (diff == 1) return 'Ontem ${_timeFormat.format(date)}';
    if (diff < 7) return DateFormat('EEEE HH:mm').format(date); // Terça-feira 14:30
    return '${_relativeFormat.format(date)} ${_timeFormat.format(date)}';
  }

  /// Formata duração em formato legível: "2h 15min", "45min", "1min 30s".
  static String formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}min';
    }
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}min';
    }
    return '${duration.inSeconds}s';
  }

  /// Retorna data de hoje às 23:59:59 (útil para limites diários).
  static DateTime endOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  /// Verifica se duas datas são no mesmo dia.
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Timestamp do Firestore (DateTime -> int millisecondsSinceEpoch).
  static int toTimestamp(DateTime date) => date.millisecondsSinceEpoch;

  /// Timestamp -> DateTime.
  static DateTime fromTimestamp(int timestamp) =>
      DateTime.fromMillisecondsSinceEpoch(timestamp);
}