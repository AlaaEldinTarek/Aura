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

  // Qatar (Umm al-Qura variant with an 18° Fajr)
  qatar,

  // Dubai (The Gulf Region)
  dubai,

  // Diyanet, Turkey
  turkey,

  // Singapore
  singapore,

  // Moonsighting Committee (seasonal Fajr/Isha bounds)
  moonsightingCommittee,
}

/// Maps a stored `calculation_method` pref to its internal method.
///
/// Accepts the picker values saved by the settings screens
/// (`AdhanCalculationMethod.value`, e.g. 'UmmAlQura', 'Qatar') and an exact
/// enum name ('makkah'). Each UI value maps to its own method. Null or unknown
/// → [CalculationMethod.muslimWorldLeague]. The enum names are what native
/// receives as `prayer_calc_method` (contract, see contracts/prefs-keys.md).
CalculationMethod calculationMethodFromPref(String? value) {
  switch (value) {
    case 'MuslimWorldLeague':
      return CalculationMethod.muslimWorldLeague;
    case 'Egyptian':
      return CalculationMethod.egyptian;
    case 'Karachi':
      return CalculationMethod.karachi;
    case 'UmmAlQura':
      return CalculationMethod.makkah;
    case 'NorthAmerica':
      return CalculationMethod.isna;
    case 'Kuwait':
      return CalculationMethod.kuwait;
    case 'Tehran':
      return CalculationMethod.tehran;
    case 'Qatar':
      return CalculationMethod.qatar;
    case 'Dubai':
      return CalculationMethod.dubai;
    case 'Turkey':
      return CalculationMethod.turkey;
    case 'Singapore':
      return CalculationMethod.singapore;
    case 'MoonsightingCommittee':
      return CalculationMethod.moonsightingCommittee;
  }
  for (final m in CalculationMethod.values) {
    if (m.name == value) return m;
  }
  return CalculationMethod.muslimWorldLeague;
}

/// Maps a stored `asr_madhab` pref ('Shafi' / 'Hanafi', any case) to its
/// madhab. Null or unknown → [AsrMadhab.shafi].
AsrMadhab asrMadhabFromPref(String? value) {
  final lower = value?.toLowerCase();
  for (final m in AsrMadhab.values) {
    if (m.name == lower) return m;
  }
  return AsrMadhab.shafi;
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
      case CalculationMethod.qatar:
        return 'Qatar';
      case CalculationMethod.dubai:
        return 'Dubai';
      case CalculationMethod.turkey:
        return 'Turkey';
      case CalculationMethod.singapore:
        return 'Singapore';
      case CalculationMethod.moonsightingCommittee:
        return 'Moonsighting Committee';
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
      case CalculationMethod.qatar:
        return 'قطر';
      case CalculationMethod.dubai:
        return 'دبي';
      case CalculationMethod.turkey:
        return 'تركيا';
      case CalculationMethod.singapore:
        return 'سنغافورة';
      case CalculationMethod.moonsightingCommittee:
        return 'لجنة الرؤية';
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
