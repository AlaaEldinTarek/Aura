/// Calculation methods for prayer times
enum CalculationMethod {
  // Muslim World League (default)
  muslimWorldLeague,

  // Islamic Society of North America (ISNA)
  isna,

  // Egyptian General Authority of Survey
  egyptian,

  // Umm Al-Qura University, Makkah
  makkah,

  // University of Islamic Sciences, Karachi
  karachi,

  // Institute of Geophysics, University of Tehran
  tehran,

  // Kuwaiti Ministry of Awqaf and Islamic Affairs
  kuwait,

  // Fixed angle method (12 degrees)
  fixedAngle,

  // Proportional method
  proportional,
}

/// Madhab (school of thought) for Asr prayer calculation
enum AsrMadhab {
  /// Shafi school (earlier Asr time)
  shafi,

  /// Hanafi school (later Asr time)
  hanafi,
}

/// Extension to get display name for calculation method
extension CalculationMethodExtension on CalculationMethod {
  String get displayName {
    switch (this) {
      case CalculationMethod.muslimWorldLeague:
        return 'Muslim World League';
      case CalculationMethod.isna:
        return 'ISNA (North America)';
      case CalculationMethod.egyptian:
        return 'Egyptian';
      case CalculationMethod.makkah:
        return 'Makkah (Umm Al-Qura)';
      case CalculationMethod.karachi:
        return 'Karachi (University)';
      case CalculationMethod.tehran:
        return 'Tehran (Institute of Geophysics)';
      case CalculationMethod.kuwait:
        return 'Kuwait';
      case CalculationMethod.fixedAngle:
        return 'Fixed Angle (12°)';
      case CalculationMethod.proportional:
        return 'Proportional';
    }
  }

  String get displayNameAr {
    switch (this) {
      case CalculationMethod.muslimWorldLeague:
        return 'رابطة العالم الإسلامي';
      case CalculationMethod.isna:
        return 'أمريكا الشمالية (ISNA)';
      case CalculationMethod.egyptian:
        return 'المصري العام';
      case CalculationMethod.makkah:
        return 'مكة (أم القرى)';
      case CalculationMethod.karachi:
        return 'كاراشي (جامعة)';
      case CalculationMethod.tehran:
        return 'طهران (معهد الجيوفيزياء)';
      case CalculationMethod.kuwait:
        return 'الكويت';
      case CalculationMethod.fixedAngle:
        return 'زاوية ثابتة (12°)';
      case CalculationMethod.proportional:
        return 'نسبي';
    }
  }
}

/// Extension to get display name for Asr Madhab
extension AsrMadhabExtension on AsrMadhab {
  String get displayName {
    switch (this) {
      case AsrMadhab.shafi:
        return 'Shafi (Standard)';
      case AsrMadhab.hanafi:
        return 'Hanafi (Later)';
    }
  }

  String get displayNameAr {
    switch (this) {
      case AsrMadhab.shafi:
        return 'الشافعي (المبكر)';
      case AsrMadhab.hanafi:
        return 'الحنفي (المؤخر)';
    }
  }
}
