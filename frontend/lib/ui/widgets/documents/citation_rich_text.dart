import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../core/models/document_model.dart';
import '../../../core/utils/document_citation_resolver.dart';
import 'paper_citation_sheet.dart';

/// Renders document body text with clickable numbered citations.
class CitationRichText extends StatefulWidget {
  final String content;
  final AIGeneratedDocument document;
  final TextStyle? style;
  final String? documentId;

  const CitationRichText({
    Key? key,
    required this.content,
    required this.document,
    this.style,
    this.documentId,
  }) : super(key: key);

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
      decorationColor: theme.colorScheme.primary.withOpacity(0.5),
    );

    _recognizers.clear();
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\[(\d+)\]');
    var lastIndex = 0;

    for (final match in pattern.allMatches(normalized)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: normalized.substring(lastIndex, match.start),
          style: bodyStyle,
        ));
      }

      final number = int.parse(match.group(1)!);
      final recognizer = TapGestureRecognizer()
        ..onTap = () => showPaperCitationSheet(
              context,
              citationNumber: number,
              resolver: resolver,
              documentId: widget.documentId ?? widget.document.id,
            );
      _recognizers.add(recognizer);

      spans.add(TextSpan(
        text: match.group(0),
        style: citationStyle,
        recognizer: recognizer,
      ));
      lastIndex = match.end;
    }

    if (lastIndex < normalized.length) {
      spans.add(TextSpan(
        text: normalized.substring(lastIndex),
        style: bodyStyle,
      ));
    }

    return SelectableText.rich(TextSpan(children: spans));
  }
}
