import 'package:flutter/material.dart';

import '../../../core/models/document_model.dart';
import 'citation_rich_text.dart';

enum _BlockKind { heading, paragraph, bullet, spacer }

class _MarkdownBlock {
  final _BlockKind kind;
  final int headingLevel;
  final String text;

  const _MarkdownBlock({
    required this.kind,
    this.headingLevel = 0,
    required this.text,
  });
}

/// Renders document section content with basic Markdown structure and citations.
class DocumentMarkdownBody extends StatelessWidget {
  final String content;
  final AIGeneratedDocument document;
  final TextStyle? paragraphStyle;
  final String? documentId;

  const DocumentMarkdownBody({
    super.key,
    required this.content,
    required this.document,
    this.paragraphStyle,
    this.documentId,
  });

  static List<_MarkdownBlock> parseBlocks(String raw) {
    final blocks = <_MarkdownBlock>[];
    final lines = raw.replaceAll('\r\n', '\n').split('\n');
    final paragraphBuffer = <String>[];

    void flushParagraph() {
      if (paragraphBuffer.isEmpty) return;
      final text = paragraphBuffer.join(' ').trim();
      paragraphBuffer.clear();
      if (text.isNotEmpty) {
        blocks.add(_MarkdownBlock(kind: _BlockKind.paragraph, text: text));
      }
    }

    for (final line in lines) {
      final trimmed = line.trimRight();
      if (trimmed.isEmpty) {
        flushParagraph();
        continue;
      }

      final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
      if (heading != null) {
        flushParagraph();
        blocks.add(_MarkdownBlock(
          kind: _BlockKind.heading,
          headingLevel: heading.group(1)!.length,
          text: heading.group(2)!.trim(),
        ));
        continue;
      }

      final bullet = RegExp(r'^[-*•]\s+(.*)$').firstMatch(trimmed);
      if (bullet != null) {
        flushParagraph();
        blocks.add(_MarkdownBlock(
          kind: _BlockKind.bullet,
          text: bullet.group(1)!.trim(),
        ));
        continue;
      }

      paragraphBuffer.add(trimmed);
    }

    flushParagraph();
    return blocks;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyStyle = paragraphStyle ??
        theme.textTheme.bodyLarge?.copyWith(height: 1.65) ??
        const TextStyle(fontSize: 16, height: 1.65);

    final blocks = parseBlocks(content);
    if (blocks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks) ...[
          switch (block.kind) {
            _BlockKind.heading => Padding(
                padding: EdgeInsets.only(
                  top: block.headingLevel <= 2 ? 20 : 12,
                  bottom: 8,
                ),
                child: Text(
                  block.text,
                  style: _headingStyle(theme, block.headingLevel, bodyStyle),
                ),
              ),
            _BlockKind.bullet => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•  ', style: bodyStyle.copyWith(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: CitationRichText(
                        content: block.text,
                        document: document,
                        documentId: documentId ?? document.id,
                        style: bodyStyle,
                      ),
                    ),
                  ],
                ),
              ),
            _BlockKind.paragraph => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CitationRichText(
                  content: block.text,
                  document: document,
                  documentId: documentId ?? document.id,
                  style: bodyStyle,
                ),
              ),
            _BlockKind.spacer => const SizedBox(height: 8),
          },
        ],
      ],
    );
  }

  TextStyle _headingStyle(ThemeData theme, int level, TextStyle bodyStyle) {
    switch (level) {
      case 1:
        return theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              height: 1.25,
            ) ??
            bodyStyle.copyWith(fontSize: 28, fontWeight: FontWeight.bold);
      case 2:
        return theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              height: 1.3,
            ) ??
            bodyStyle.copyWith(fontSize: 22, fontWeight: FontWeight.bold);
      case 3:
        return theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.35,
            ) ??
            bodyStyle.copyWith(fontSize: 18, fontWeight: FontWeight.w600);
      default:
        return bodyStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w600);
    }
  }
}
