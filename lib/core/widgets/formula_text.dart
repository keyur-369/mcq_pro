import 'package:flutter/material.dart';

/// Renders chemistry/math formatted text with proper sub/superscripts.
///
/// Supported syntax (as Gemini returns it):
///   C_2H_6O_2   →  C₂H₆O₂   (underscore = subscript)
///   x^2         →  x²        (caret = superscript)
///   mol^{-1}    →  mol⁻¹     (braced superscript)
///   C_{2}H_{6}  →  C₂H₆     (braced subscript)
///
class FormulaText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const FormulaText(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final spans = _parse(text, base);
    return RichText(text: TextSpan(children: spans));
  }

  List<InlineSpan> _parse(String input, TextStyle base) {
    final spans = <InlineSpan>[];
    // Matches: ^{...}, _{...}, ^char, _char
    final regex = RegExp(r'(\^{[^}]+}|_{[^}]+}|\^[^\s^_]|_[^\s^_])');
    int cursor = 0;

    for (final match in regex.allMatches(input)) {
      // Plain text before this match
      if (match.start > cursor) {
        spans.add(TextSpan(
          text: input.substring(cursor, match.start),
          style: base,
        ));
      }

      final token = match.group(0)!;
      final isSup = token.startsWith('^');
      // Extract inner content — strip leading ^/_ and optional braces
      String inner = token.substring(1);
      if (inner.startsWith('{') && inner.endsWith('}')) {
        inner = inner.substring(1, inner.length - 1);
      }

      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Transform.translate(
          offset: Offset(0, isSup ? -4 : 3),
          child: Text(
            inner,
            style: base.copyWith(fontSize: (base.fontSize ?? 14) * 0.65),
          ),
        ),
      ));

      cursor = match.end;
    }

    // Remaining plain text
    if (cursor < input.length) {
      spans.add(TextSpan(text: input.substring(cursor), style: base));
    }

    return spans;
  }
}