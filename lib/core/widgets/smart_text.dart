import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class SmartText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const SmartText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    if (!text.contains(r'$') && !text.contains('**') && !text.contains('*')) {
      return Text(text, style: style, textAlign: textAlign, maxLines: maxLines, overflow: overflow);
    }

    final spans = <InlineSpan>[];
    final buf = StringBuffer();
    int i = 0;

    void flush() {
      if (buf.isNotEmpty) {
        spans.add(TextSpan(text: buf.toString(), style: style));
        buf.clear();
      }
    }

    while (i < text.length) {
      if (text.startsWith(r'$$', i)) {
        final end = text.indexOf(r'$$', i + 2);
        if (end == -1) { buf.write(text.substring(i)); break; }
        flush();
        final tex = text.substring(i + 2, end).trim();
        spans.add(WidgetSpan(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: LayoutBuilder(
              builder: (_, constraints) => ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth > 0 ? constraints.maxWidth : 200),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Math.tex(tex, textStyle: TextStyle(fontSize: (style?.fontSize ?? 14) + 1, color: style?.color)),
                ),
              ),
            ),
          ),
        ));
        i = end + 2;
      } else if (text.startsWith(r'$', i)) {
        final end = text.indexOf(r'$', i + 1);
        if (end == -1 || text.startsWith(r'$$', i)) { buf.write(text[i]); i++; continue; }
        flush();
        final tex = text.substring(i + 1, end).trim();
        spans.add(WidgetSpan(
          child: LayoutBuilder(
            builder: (_, constraints) => ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth > 0 ? constraints.maxWidth : 200),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Math.tex(tex, textStyle: TextStyle(fontSize: style?.fontSize ?? 14, color: style?.color)),
              ),
            ),
          ),
        ));
        i = end + 1;
      } else if (text.startsWith('**', i)) {
        final end = text.indexOf('**', i + 2);
        if (end == -1) { buf.write(text.substring(i)); break; }
        flush();
        spans.add(TextSpan(text: text.substring(i + 2, end), style: style?.copyWith(fontWeight: FontWeight.w800)));
        i = end + 2;
      } else if (text.startsWith('*', i)) {
        final end = text.indexOf('*', i + 1);
        if (end == -1) { buf.write(text[i]); i++; continue; }
        flush();
        spans.add(TextSpan(text: text.substring(i + 1, end), style: style?.copyWith(fontStyle: FontStyle.italic)));
        i = end + 1;
      } else if (text.startsWith(r'\n', i)) {
        flush();
        spans.add(const TextSpan(text: '\n'));
        i += 2;
      } else {
        buf.write(text[i]);
        i++;
      }
    }
    flush();

    if (spans.isEmpty) return Text(text, style: style, textAlign: textAlign);

    return RichText(
      text: TextSpan(children: spans),
      softWrap: true,
      textAlign: textAlign ?? TextAlign.start,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }
}
