/// Utility class to format scientific text, chemical formulas,
/// superscripts, subscripts, and reaction equations for MCQs and PDFs.
class ScientificFormatter {
  static const Map<String, String> _subscriptMap = {
    '0': '\u2080',
    '1': '\u2081',
    '2': '\u2082',
    '3': '\u2083',
    '4': '\u2084',
    '5': '\u2085',
    '6': '\u2086',
    '7': '\u2087',
    '8': '\u2088',
    '9': '\u2089',
    '+': '\u208A',
    '-': '\u208B',
  };

  static const Map<String, String> _superscriptMap = {
    '0': '\u2070',
    '1': '\u00B9',
    '2': '\u00B2',
    '3': '\u00B3',
    '4': '\u2074',
    '5': '\u2075',
    '6': '\u2076',
    '7': '\u2077',
    '8': '\u2078',
    '9': '\u2079',
    '+': '\u207A',
    '-': '\u207B',
  };

  /// Converts a string of digits/signs to Unicode subscripts (e.g., "2" -> "₂")
  static String toSubscript(String input) {
    return input.split('').map((char) => _subscriptMap[char] ?? char).join();
  }

  /// Converts a string of digits/signs to Unicode superscripts (e.g., "2" -> "²")
  static String toSuperscript(String input) {
    return input.split('').map((char) => _superscriptMap[char] ?? char).join();
  }

  /// Primary formatter for scientific questions and options.
  /// Formats chemical formulas (H2SO4 -> H₂SO₄), hybridizations (sp3 -> sp³),
  /// powers (x^2 -> x²), common ions (H+ -> H⁺, OH- -> OH⁻), and reaction arrows (-> -> →).
  static String format(String? input) {
    if (input == null || input.isEmpty) return '';

    String text = input;

    // 1. Explicit caret superscripts: e.g. x^2 -> x², ^3 -> ³, 10^-3 -> 10⁻³, sp^2 -> sp²
    text = text.replaceAllMapped(
      RegExp(r'\^(\{?([\d\+\-]+)\}?)'),
      (match) => toSuperscript(match.group(2) ?? ''),
    );

    // 2. Explicit underscore subscripts: e.g. H_2 -> H₂, _{2} -> ₂
    text = text.replaceAllMapped(
      RegExp(r'_(\{?([\d\+\-]+)\}?)'),
      (match) => toSubscript(match.group(2) ?? ''),
    );

    // 3. Hybridization notation: sp, sp2, sp3, dsp2, d2sp3, sp3d, sp3d2
    text = text.replaceAllMapped(
      RegExp(r'\b(sp|dsp|d2sp|sp3d|sp3d2)([1-9])?\b', caseSensitive: false),
      (match) {
        final prefix = match.group(1)!;
        final digit = match.group(2);
        // Normalize hybridization formatting
        String formatted = prefix
            .replaceAll('d2sp3', 'd²sp³')
            .replaceAll('d2sp', 'd²sp')
            .replaceAll('dsp2', 'dsp²')
            .replaceAll('sp3d2', 'sp³d²')
            .replaceAll('sp3d', 'sp³d');
        if (digit != null && !formatted.contains('²') && !formatted.contains('³')) {
          formatted += toSuperscript(digit);
        }
        return formatted;
      },
    );

    // Also match standalone "sp2", "sp3", "sp" in lists like "sp2, sp3"
    text = text.replaceAll(RegExp(r'\bsp2\b', caseSensitive: false), 'sp²');
    text = text.replaceAll(RegExp(r'\bsp3\b', caseSensitive: false), 'sp³');
    text = text.replaceAll(RegExp(r'\bsp1\b', caseSensitive: false), 'sp');

    // 4. Common chemical ions
    text = text.replaceAllMapped(
      RegExp(r'\b(H|H3O|NH4|Na|K|Ag)\s*\+'),
      (match) => '${match.group(1)}⁺',
    );
    text = text.replaceAllMapped(
      RegExp(r'\b(OH|Cl|Br|I|NO3|NO2|F)\s*\-'),
      (match) => '${match.group(1)}⁻',
    );
    text = text.replaceAll(RegExp(r'H2O\s*/\s*H\+'), 'H₂O/H⁺');
    text = text.replaceAll(RegExp(r'H2O\s*/\s*OH\-'), 'H₂O/OH⁻');

    // 5. Reaction arrows: -> or --> to →, <=> or <-> to ⇌
    text = text.replaceAll(RegExp(r'\s*<[=\-]>+\s*'), ' ⇌ ');
    text = text.replaceAll(RegExp(r'(?<!<)-{1,3}>\s*'), ' → ');

    // 6. Automatic chemical formula conversion for tokens
    // Tokens containing chemical elements followed by digits (e.g. H2SO4, KMnO4, CH3-CH2-OH)
    text = _formatChemicalFormulasInText(text);

    return text;
  }

  /// Finds chemical formula patterns and subscriptizes their stoichiometric/atom counts
  static String _formatChemicalFormulasInText(String text) {
    // Regex matching chemical elements followed by digits, e.g. H2, SO4, CH3, C6H5, PCl5, AlCl3
    // We avoid words like Std 12, Q43, 2-methyl, etc. by requiring valid chemical patterns.
    const chemicalElementRegex =
        r'(?:H|He|Li|Be|B|C|N|O|F|Ne|Na|Mg|Al|Si|P|S|Cl|Ar|K|Ca|Sc|Ti|V|Cr|Mn|Fe|Co|Ni|Cu|Zn|Ga|Ge|As|Se|Br|Kr|Rb|Sr|Y|Zr|Nb|Mo|Tc|Ru|Rh|Pd|Ag|Cd|In|Sn|Sb|Te|I|Xe|Cs|Ba|Pt|Au|Hg|Pb|Bi|U)';

    // Pattern A: Element followed by number (e.g., H2, O4, C6, Cl2)
    final formulaPattern = RegExp(
      '($chemicalElementRegex|\\))([0-9]+)',
    );

    // Apply only to parts of text that resemble chemical formulas
    // Split into words/tokens so we don't mess up standard Gujarati or English words
    return text.replaceAllMapped(
      RegExp(r'([A-Za-z0-9_\-\(\)\+/]{2,})'),
      (tokenMatch) {
        final token = tokenMatch.group(0)!;

        // Skip if token looks like standard numbers or dates (e.g. "12th", "2026", "2-", "1-")
        if (RegExp(r'^\d+(st|nd|rd|th)?$').hasMatch(token) ||
            RegExp(r'^\d+\-').hasMatch(token) && !token.contains('CH')) {
          return token;
        }

        // Check if token contains chemical formula elements
        if (RegExp(chemicalElementRegex).hasMatch(token)) {
          return token.replaceAllMapped(formulaPattern, (match) {
            final elem = match.group(1)!;
            final count = match.group(2)!;
            return '$elem${toSubscript(count)}';
          });
        }

        return token;
      },
    );
  }
}
