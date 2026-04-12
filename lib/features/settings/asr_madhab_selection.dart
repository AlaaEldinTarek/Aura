import 'package:flutter/material.dart';

/// Asr prayer calculation methods (Madhab)
enum AsrMadhab {
  shafi(
    value: 'Shafi',
    nameEn: 'Shafi (Maliki, Shafi, Ja\'fari, Hanbali)',
    nameAr: 'شافعي (مالكي، شافعي، جعفري، حنبلي)',
    description: 'Asr prayer time when the shadow of an object is equal to its length',
    descriptionAr: 'وقت صلاة العصر عندما يكون طول الظل مساوياً لطول الجسم',
  ),
  hanafi(
    value: 'Hanafi',
    nameEn: 'Hanafi',
    nameAr: 'حنفي',
    description: 'Asr prayer time when the shadow of an object is twice its length',
    descriptionAr: 'وقت صلاة العصر عندما يكون طول الظل ضعف طول الجسم',
  );

  final String value;
  final String nameEn;
  final String nameAr;
  final String description;
  final String descriptionAr;

  const AsrMadhab({
    required this.value,
    required this.nameEn,
    required this.nameAr,
    required this.description,
    required this.descriptionAr,
  });

  String getLocalizedName(bool isArabic, {bool showDescription = false}) {
    if (showDescription) {
      return isArabic ? descriptionAr : description;
    }
    return isArabic ? nameAr : nameEn;
  }

  static AsrMadhab fromValue(String value) {
    return AsrMadhab.values.firstWhere(
      (madhab) => madhab.value == value,
      orElse: () => AsrMadhab.shafi,
    );
  }
}
