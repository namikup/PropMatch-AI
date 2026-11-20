/// Normalization and sanitization utilities tailored for Malaysian CRM prospect data.
class CRMDataNormalizer {
  CRMDataNormalizer._();

  static const Set<String> _emptyPlaceholders = {
    'n/a',
    'na',
    'none',
    'nil',
    '-',
    '--',
    'null',
    'undefined',
    'tbc',
    'tba',
    'unknown',
  };

  static bool isPlaceholderOrEmpty(dynamic raw) {
    if (raw == null) return true;
    final str = raw.toString().trim().toLowerCase();
    return str.isEmpty || _emptyPlaceholders.contains(str);
  }

  // --- 1. MALAYSIAN PHONE NUMBER NORMALIZATION ---

  /// Normalizes Malaysian contact numbers into standard canonical E.164-compatible format: `+601xxxxxxxx`
  static NormalizedPhone normalizePhone(dynamic raw) {
    if (isPlaceholderOrEmpty(raw)) {
      return const NormalizedPhone(canonical: '', isValid: false, error: 'Phone number is empty.');
    }

    String rawStr = raw.toString().trim();
    // Strip trailing .0 from Excel floating-point numeric cells (e.g. 123456789.0)
    if (RegExp(r'^\d+\.0+$').hasMatch(rawStr)) {
      rawStr = rawStr.split('.').first;
    }

    // Strip all non-digit characters
    final String digitsOnly = rawStr.replaceAll(RegExp(r'\D'), '');

    if (digitsOnly.isEmpty) {
      return const NormalizedPhone(canonical: '', isValid: false, error: 'Phone number contains no digits.');
    }

    String canonical;

    // Handle various Malaysian prefixes including redundant trunk '0' after country code '+60(0)12...'
    if (digitsOnly.startsWith('00600') && digitsOnly.length >= 13) {
      canonical = '+60${digitsOnly.substring(5)}';
    } else if (digitsOnly.startsWith('0060')) {
      canonical = '+60${digitsOnly.substring(4)}';
    } else if (digitsOnly.startsWith('600') && digitsOnly.length >= 11) {
      canonical = '+60${digitsOnly.substring(3)}';
    } else if (digitsOnly.startsWith('60') && digitsOnly.length >= 10) {
      canonical = '+$digitsOnly';
    } else if (digitsOnly.startsWith('0')) {
      canonical = '+60${digitsOnly.substring(1)}';
    } else if ((digitsOnly.length == 8 || digitsOnly.length == 9 || digitsOnly.length == 10) &&
        !digitsOnly.startsWith('0')) {
      // Missing leading 0 e.g. 123456789 -> +60123456789
      canonical = '+60$digitsOnly';
    } else {
      canonical = '+$digitsOnly';
    }

    // Validate Malaysian phone structure
    final afterPrefix = canonical.startsWith('+60') ? canonical.substring(3) : '';
    // Standard Malaysian mobile numbers start with 1 (010..019) and have 9-10 digits after +60
    // Landlines start with 3..9 and have 8-9 digits after +60
    final isValidStructure = canonical.startsWith('+60') &&
        RegExp(r'^[1-9]\d{7,9}$').hasMatch(afterPrefix);

    if (!isValidStructure) {
      return const NormalizedPhone(
        canonical: '',
        isValid: false,
        error: 'Invalid phone length or format for Malaysia.',
      );
    }

    final isMobile = afterPrefix.startsWith('1');
    return NormalizedPhone(
      canonical: canonical,
      isValid: true,
      isMobile: isMobile,
    );
  }

  // --- 2. EMAIL NORMALIZATION ---

  /// Normalizes and validates email addresses.
  static NormalizedEmail normalizeEmail(dynamic raw) {
    if (isPlaceholderOrEmpty(raw)) {
      return const NormalizedEmail(canonical: '', isValid: false, error: 'Email is empty.');
    }

    final rawStr = raw.toString().trim().toLowerCase();

    // Standard RFC-compliant email regex
    final emailRegex = RegExp(r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$');
    if (!emailRegex.hasMatch(rawStr)) {
      return const NormalizedEmail(
        canonical: '',
        isValid: false,
        error: 'Invalid email address syntax.',
      );
    }

    return NormalizedEmail(canonical: rawStr, isValid: true);
  }

  // --- 3. BUDGET NORMALIZATION ---

  /// Parses a single Malaysian Ringgit currency expression into a double, or null if invalid.
  static double? parseRinggit(dynamic val) {
    final parsed = _parseCurrencyValue(val);
    return parsed > 0 ? parsed : null;
  }

  /// Parses Malaysian Ringgit budget expressions into numeric min and max bounds.
  static NormalizedBudget normalizeBudget({dynamic minRaw, dynamic maxRaw, dynamic singleRaw}) {
    double min = _parseCurrencyValue(minRaw);
    double max = _parseCurrencyValue(maxRaw);

    // If minRaw or maxRaw itself contains a range string (e.g. "RM 500k - 700k")
    if (min <= 0 && max <= 0) {
      if (singleRaw != null && !isPlaceholderOrEmpty(singleRaw)) {
        final range = _parseBudgetRangeString(singleRaw.toString());
        min = range.$1;
        max = range.$2;
      } else if (minRaw != null && !isPlaceholderOrEmpty(minRaw) && _containsRangeSeparator(minRaw.toString())) {
        final range = _parseBudgetRangeString(minRaw.toString());
        min = range.$1;
        max = range.$2;
      } else if (maxRaw != null && !isPlaceholderOrEmpty(maxRaw) && _containsRangeSeparator(maxRaw.toString())) {
        final range = _parseBudgetRangeString(maxRaw.toString());
        min = range.$1;
        max = range.$2;
      }
    }

    // If only one bound is provided, create a sensible 20% bracket
    if (min > 0 && max <= 0) {
      max = (min * 1.20).roundToDouble();
    } else if (max > 0 && min <= 0) {
      min = (max * 0.80).roundToDouble();
    }

    // Validate bounds
    if (min <= 0 && max <= 0) {
      return const NormalizedBudget(min: 400000.0, max: 750000.0, isValid: true, isDefaulted: true);
    }

    if (min > max) {
      // Swap inverted values
      final temp = min;
      min = max;
      max = temp;
    }

    return NormalizedBudget(min: min, max: max, isValid: true, isDefaulted: false);
  }

  static bool _containsRangeSeparator(String str) {
    return RegExp(r'(?:[-–—~]|\bTO\b)', caseSensitive: false).hasMatch(str);
  }

  static double _parseCurrencyValue(dynamic val) {
    if (isPlaceholderOrEmpty(val)) return 0.0;
    if (val is num) return val > 0 ? val.toDouble() : 0.0;

    String str = val.toString().trim().toUpperCase();
    if (str.isEmpty) return 0.0;

    // If the string has a range separator, _parseCurrencyValue shouldn't parse it as a single value
    if (_containsRangeSeparator(str)) return 0.0;

    // Remove RM, currency symbols, and commas
    str = str.replaceAll('RM', '').replaceAll('MYR', '').replaceAll('\$', '').replaceAll(',', '').trim();

    double multiplier = 1.0;
    if (str.endsWith('K')) {
      multiplier = 1000.0;
      str = str.substring(0, str.length - 1).trim();
    } else if (str.endsWith('MILLION') || str.endsWith('MIL') || str.endsWith('M')) {
      multiplier = 1000000.0;
      str = str.replaceAll(RegExp(r'[A-Z]'), '').trim();
    }

    final parsed = double.tryParse(str);
    if (parsed == null || parsed <= 0 || parsed.isNaN || parsed.isInfinite) {
      return 0.0;
    }
    return parsed * multiplier;
  }

  static (double, double) _parseBudgetRangeString(String str) {
    final clean = str.toUpperCase().replaceAll('RM', '').replaceAll('MYR', '').trim();
    final parts = clean.split(RegExp(r'\s*(?:[-–—~]|\bTO\b)\s*', caseSensitive: false));
    if (parts.length >= 2) {
      final min = _parseCurrencyValue(parts[0]);
      final max = _parseCurrencyValue(parts[1]);
      return (min, max);
    }
    final single = _parseCurrencyValue(clean);
    return (single * 0.85, single * 1.15);
  }

  // --- 4. LOCATION & STATE INFERENCE ---

  /// Infers Malaysian state based on common city/district names.
  static String inferStateFromLocation(String location, [String fallback = 'Penang']) {
    final loc = location.toLowerCase().trim();

    const locationToState = {
      // Penang
      'batu kawan': 'Penang',
      'george town': 'Penang',
      'georgetown': 'Penang',
      'bayan lepas': 'Penang',
      'tanjung tokong': 'Penang',
      'bukit mertajam': 'Penang',
      'butterworth': 'Penang',
      'gurney': 'Penang',
      'pulau tikus': 'Penang',
      'gelugor': 'Penang',
      'seberang perai': 'Penang',
      'jelutong': 'Penang',
      'simpang ampat': 'Penang',

      // Selangor
      'petaling jaya': 'Selangor',
      'pj': 'Selangor',
      'subang jaya': 'Selangor',
      'subang': 'Selangor',
      'shah alam': 'Selangor',
      'cyberjaya': 'Selangor',
      'puchong': 'Selangor',
      'klang': 'Selangor',
      'bangi': 'Selangor',
      'damansara': 'Selangor',
      'rawang': 'Selangor',
      'kajang': 'Selangor',
      'ampang': 'Selangor',
      'sunway': 'Selangor',
      'sepang': 'Selangor',

      // Kuala Lumpur
      'klcc': 'Kuala Lumpur',
      'mont kiara': 'Kuala Lumpur',
      'bangsar': 'Kuala Lumpur',
      'cheras': 'Kuala Lumpur',
      'bukit bintang': 'Kuala Lumpur',
      'setapak': 'Kuala Lumpur',
      'kepong': 'Kuala Lumpur',
      'sentul': 'Kuala Lumpur',
      'kuala lumpur': 'Kuala Lumpur',
      'kl': 'Kuala Lumpur',
      'sri petaling': 'Kuala Lumpur',

      // Putrajaya
      'putrajaya': 'Putrajaya',

      // Johor
      'johor bahru': 'Johor',
      'jb': 'Johor',
      'iskandar puteri': 'Johor',
      'medini': 'Johor',
      'mount austin': 'Johor',
      'skudai': 'Johor',
      'kulai': 'Johor',
      'tebrau': 'Johor',

      // Kedah
      'kulim': 'Kedah',
      'sungai petani': 'Kedah',
      'alor setar': 'Kedah',
      'langkawi': 'Kedah',

      // Perak
      'ipoh': 'Perak',
      'taiping': 'Perak',
      'kampar': 'Perak',

      // Sarawak
      'kuching': 'Sarawak',
      'miri': 'Sarawak',
      'sibu': 'Sarawak',
      'bintulu': 'Sarawak',

      // Sabah
      'kota kinabalu': 'Sabah',
      'kk': 'Sabah',
      'sandakan': 'Sabah',
      'tawau': 'Sabah',

      // Melaka
      'melaka': 'Melaka',
      'malacca': 'Melaka',
      'ayer keroh': 'Melaka',

      // Negeri Sembilan
      'seremban': 'Negeri Sembilan',
      'nilai': 'Negeri Sembilan',
      'port dickson': 'Negeri Sembilan',

      // Pahang
      'kuantan': 'Pahang',
      'genting': 'Pahang',
      'cameron highlands': 'Pahang',
    };

    for (final entry in locationToState.entries) {
      if (loc.contains(entry.key)) {
        return entry.value;
      }
    }

    return fallback;
  }

  /// Convenience wrapper accepting nullable location and explicit state fallback.
  static String inferMalaysianState(String? location, [String? explicitState]) {
    if (explicitState != null && explicitState.trim().isNotEmpty) {
      return explicitState.trim();
    }
    return inferStateFromLocation(location ?? '', 'Penang');
  }

  // --- 5. PRIVACY & DATA MINIMIZATION HELPERS ---

  /// Scrubs accidental Malaysian NRIC (e.g. 880412-14-5567) from free-text notes
  /// to enforce data minimization during CRM imports.
  static String scrubSensitiveIdentifiers(String text) {
    if (text.isEmpty) return text;
    return text.replaceAll(
      RegExp(r'\b\d{6}-\d{2}-\d{4}\b'),
      '[NRIC-REDACTED]',
    );
  }
}

class NormalizedPhone {
  final String canonical;
  final bool isValid;
  final bool isMobile;
  final String? error;

  const NormalizedPhone({
    required this.canonical,
    required this.isValid,
    this.isMobile = true,
    this.error,
  });
}

class NormalizedEmail {
  final String canonical;
  final bool isValid;
  final String? error;

  const NormalizedEmail({
    required this.canonical,
    required this.isValid,
    this.error,
  });
}

class NormalizedBudget {
  final double min;
  final double max;
  final bool isValid;
  final bool isDefaulted;

  const NormalizedBudget({
    required this.min,
    required this.max,
    required this.isValid,
    this.isDefaulted = false,
  });
}
