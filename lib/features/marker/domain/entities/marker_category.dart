enum MarkerCategory {
  attraction('景點', 'Attraction', '🏛️'),
  food('美食', 'Food', '🍜'),
  accommodation('住宿', 'Accommodation', '🏨'),
  shopping('購物', 'Shopping', '🛍️'),
  nature('自然', 'Nature', '🌿'),
  culture('文化', 'Culture', '🎭'),
  entertainment('娛樂', 'Entertainment', '🎡'),
  transport('交通', 'Transport', '✈️'),
  other('其他', 'Other', '📍');

  const MarkerCategory(this.label, this.labelEn, this.emoji);

  final String label;
  final String labelEn;
  final String emoji;

  String get display => '$emoji $label';

  String localizedLabel(bool isEn) => isEn ? labelEn : label;
  String localizedDisplay(bool isEn) => '$emoji ${localizedLabel(isEn)}';

  static MarkerCategory fromString(String value) =>
      MarkerCategory.values.firstWhere(
        (c) => c.name == value,
        orElse: () => MarkerCategory.attraction,
      );
}
