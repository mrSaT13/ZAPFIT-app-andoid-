class PowerZonesCalculator {
  PowerZonesCalculator._();

  /// Calculate Coggan 7-zone power zones from FTP
  static Map<String, String> calculateZones(double ftp) {
    if (ftp <= 0) return {};
    return {
      'Z1 Активное восстановление': '0–55% FTP (${(ftp * 0).round()}–${(ftp * 0.55).round()} Вт)',
      'Z2 Выносливость': '56–75% FTP (${(ftp * 0.56).round()}–${(ftp * 0.75).round()} Вт)',
      'Z3 Темп': '76–90% FTP (${(ftp * 0.76).round()}–${(ftp * 0.90).round()} Вт)',
      'Z4 Пороговый': '91–105% FTP (${(ftp * 0.91).round()}–${(ftp * 1.05).round()} Вт)',
      'Z5 VO2max': '106–120% FTP (${(ftp * 1.06).round()}–${(ftp * 1.20).round()} Вт)',
      'Z6 Анаэробный': '121–150% FTP (${(ftp * 1.21).round()}–${(ftp * 1.50).round()} Вт)',
      'Z7 Невообразимый': '>150% FTP (${(ftp * 1.51).round()}+ Вт)',
    };
  }
}
