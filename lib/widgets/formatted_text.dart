import 'package:flutter/material.dart';

class FormattedText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final TextOverflow overflow;
  final int? maxLines;

  const FormattedText(
    this.text, {
    super.key,
    required this.style,
    this.textAlign = TextAlign.start,
    this.overflow = TextOverflow.clip,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final List<TextSpan> spans = [];
    bool isBold = false;
    bool isUnderline = false;

    // Matches tags: <b>, </b>, <u>, </u>
    final regExp = RegExp(r'(<b>|</b>|<u>|</u>)');
    final matches = regExp.allMatches(text);

    int lastIndex = 0;
    for (final match in matches) {
      if (match.start > lastIndex) {
        final textSegment = text.substring(lastIndex, match.start);
        spans.add(TextSpan(
          text: textSegment,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : style.fontWeight,
            decoration: isUnderline ? TextDecoration.underline : style.decoration,
          ),
        ));
      }

      final tag = match.group(0);
      if (tag == '<b>') {
        isBold = true;
      } else if (tag == '</b>') {
        isBold = false;
      } else if (tag == '<u>') {
        isUnderline = true;
      } else if (tag == '</u>') {
        isUnderline = false;
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      final textSegment = text.substring(lastIndex);
      spans.add(TextSpan(
        text: textSegment,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : style.fontWeight,
          decoration: isUnderline ? TextDecoration.underline : style.decoration,
        ),
      ));
    }

    return RichText(
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines,
      text: TextSpan(
        style: style,
        children: spans,
      ),
    );
  }
}
