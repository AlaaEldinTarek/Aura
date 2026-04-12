import 'package:flutter/material.dart';

/// Prayer calculation methods available in the app
enum AdhanCalculationMethod {
  muslimWorldLeague(
    value: 'MuslimWorldLeague',
    nameEn: 'Muslim World League',
    nameAr: 'رابطة العالم الإسلامي',
    description: 'Muslim World League (MWL)',
    descriptionAr: 'رابطة العالم الإسلامي',
  ),
  egyptian(
    value: 'Egyptian',
    nameEn: 'Egyptian General Authority',
    nameAr: 'المعهد المصري',
    description: 'Egyptian General Authority of Survey',
    descriptionAr: 'المعهد المصري للمساحة',
  ),
  karachi(
    value: 'Karachi',
    nameEn: 'University of Islamic Sciences, Karachi',
    nameAr: 'جامعة كراتشي',
    description: 'University of Islamic Sciences, Karachi',
    descriptionAr: 'جامعة العلوم الإسلامية في كراتشي',
  ),
  ummAlQura(
    value: 'UmmAlQura',
    nameEn: 'Umm Al-Qura University, Makkah',
    nameAr: 'أم القرى',
    description: 'Umm Al-Qura University, Makkah',
    descriptionAr: 'جامعة أم القرى بمكة المكرمة',
  ),
  dubai(
    value: 'Dubai',
    nameEn: 'Dubai (approximate)',
    nameAr: 'دبي',
    description: 'Dubai calculation method',
    descriptionAr: 'طريقة حساب دبي',
  ),
  moonsightingCommittee(
    value: 'MoonsightingCommittee',
    nameEn: 'Moonsighting Committee',
    nameAr: 'لجنة الرؤية',
    description: 'Moonsighting Committee (global)',
    descriptionAr: 'لجنة الرؤية (عالمية)',
  ),
  northAmerica(
    value: 'NorthAmerica',
    nameEn: 'ISNA (North America)',
    nameAr: 'أمريكا الشمالية',
    description: 'Islamic Society of North America',
    descriptionAr: 'الجمعية الإسلامية في أمريكا الشمالية',
  ),
  kuwait(
    value: 'Kuwait',
    nameEn: 'Kuwait',
    nameAr: 'الكويت',
    description: 'Kuwait calculation method',
    descriptionAr: 'طريقة حساب الكويت',
  ),
  qatar(
    value: 'Qatar',
    nameEn: 'Qatar',
    nameAr: 'قطر',
    description: 'Qatar calculation method',
    descriptionAr: 'طريقة حساب قطر',
  ),
  singapore(
    value: 'Singapore',
    nameEn: 'Singapore',
    nameAr: 'سنغافورة',
    description: 'Singapore calculation method',
    descriptionAr: 'طريقة حساب سنغافورة',
  ),
  tehran(
    value: 'Tehran',
    nameEn: 'Tehran',
    nameAr: 'طهران',
    description: 'Institute of Geophysics, University of Tehran',
    descriptionAr: 'معهد الجيوفيزياء، جامعة طهران',
  ),
  turkey(
    value: 'Turkey',
    nameEn: 'Turkey',
    nameAr: 'تركيا',
    description: 'Diyanet (Turkey) calculation method',
    descriptionAr: 'طريقة حساب رئاسة الشؤون الدينية التركية',
  );

  final String value;
  final String nameEn;
  final String nameAr;
  final String description;
  final String descriptionAr;

  const AdhanCalculationMethod({
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

  static AdhanCalculationMethod fromValue(String value) {
    return AdhanCalculationMethod.values.firstWhere(
      (method) => method.value == value,
      orElse: () => AdhanCalculationMethod.muslimWorldLeague,
    );
  }
}
