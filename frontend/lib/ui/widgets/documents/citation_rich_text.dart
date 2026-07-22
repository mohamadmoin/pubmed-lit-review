import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../core/models/document_model.dart';
import '../../../core/utils/document_citation_resolver.dart';
import 'paper_citation_sheet.dart';

/// Renders document body text with markdown inline styles and clickable citations.
class CitationRichText extends StatefulWidget {
  final String content;
  final AIGeneratedDocument document;
  final TextStyle? style;
  final String? documentId;

  const CitationRichText({
    super.key,
    required this.content,
    required this.document,
    this.style,
    this.documentId,
  });

  @override
  State<CitationRichText> createState() => _CitationRichTextState();
}

class _CitationRichTextState extends State<CitationRichText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyStyle = widget.style ??
        theme.textTheme.bodyLarge?.copyWith(height: 1.65) ??
        const TextStyle(fontSize: 16, height: 1.65);

    final resolver = DocumentCitationResolver(widget.document);
    final normalized = resolver.normalizeContent(widget.content);
    final citationStyle = bodyStyle.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: theme.colorScheme.primary.withValues(alpha: 0.5),
    );

    _recognizers.clear();
    final spans = _buildInlineSpans(normalized, bodyStyle, citationStyle, resolver);

    return SelectableText.rich(TextSpan(children: spans));
  }

  List<InlineSpan> _buildInlineSpans(
    String text,
    TextStyle bodyStyle,
    TextStyle citationStyle,
    DocumentCitationResolver resolver,
  ) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'(\[\d+\]|\*\*.+?\*\*|(?<!\*)\*([^*]+?)\*(?!\*))');
    var lastIndex = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: bodyStyle,
        ));
      }

      final token = match.group(0)!;
      if (token.startsWith('[') && token.endsWith(']')) {
        final number = int.parse(token.substring(1, token.length - 1));
        final recognizer = TapGestureRecognizer()
          ..onTap = () => showPaperCitationSheet(
                context,
                citationNumber: number,
                resolver: resolver,
                documentId: widget.documentId ?? widget.document.id,
              );
        _recognizers.add(recognizer);
        spans.add(TextSpan(
          text: token,
          style: citationStyle,
          recognizer: recognizer,
        ));
      } else if (token.startsWith('**') && token.endsWith('**')) {
        spans.add(TextSpan(
          text: token.substring(2, token.length - 2),
          style: bodyStyle.copyWith(fontWeight: FontWeight.bold),
        ));
      } else if (token.startsWith('*') && token.endsWith('*') && !token.startsWith('**')) {
        spans.add(TextSpan(
          text: token.substring(1, token.length - 1),
          style: bodyStyle.copyWith(fontStyle: FontStyle.italic),
        ));
      } else {
        spans.add(TextSpan(text: token, style: bodyStyle));
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: bodyStyle,
      ));
    }

    return spans;
  }
}
