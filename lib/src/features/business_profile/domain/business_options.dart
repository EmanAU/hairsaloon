/// Shared business type and city choices for setup / profile screens.
class BusinessOptions {
  const BusinessOptions._();

  static const List<String> businessTypes = <String>[
    'Hair Salon',
    'Barber Shop',
    'Beauty Parlour',
    'Aesthetic Clinic',
    'Spa & Wellness',
    'Nail Salon',
    'Skin Care Clinic',
    'Makeup Studio',
    'Unisex Salon',
    'Grooming Lounge',
  ];

  static const List<String> cities = <String>[
    'Islamabad',
    'Lahore',
    'Rawalpindi',
  ];

  static const String defaultBusinessType = 'Hair Salon';
  static const String defaultCity = 'Islamabad';

  /// Returns [value] if it is a known option, otherwise [fallback].
  static String resolve(String? value, List<String> options, String fallback) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return fallback;
    for (final option in options) {
      if (option.toLowerCase() == trimmed.toLowerCase()) return option;
    }
    return fallback;
  }
}
