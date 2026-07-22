import 'package:flutter/material.dart';
import 'package:litreview_app/core/theme/app_fonts.dart';
import '../../../core/models/document_model.dart';
import '../../../core/services/document_service.dart';
import '../../../core/theme/colors.dart';

/// Renders stored paper full text with readable typography (not plain truncated text).
class PaperFullTextView extends StatefulWidget {
  final PaperInstanse paper;
  final String? documentId;
  final bool compact;

  const PaperFullTextView({
    Key? key,
    required this.paper,
    this.documentId,
    this.compact = false,
  }) : super(key: key);

  @override
  State<PaperFullTextView> createState() => _PaperFullTextViewState();
}

class _PaperFullTextViewState extends State<PaperFullTextView> {
  String? _loadedText;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadedText = widget.paper.fullText ?? widget.paper.fullTextPreview;
    if (_needsFetch()) {
      _fetchFullText();
    }
  }

  bool _needsFetch() {
    final preview = widget.paper.fullTextPreview;
    final hasPreview = preview != null && preview.isNotEmpty;
    final hasFull = widget.paper.fullText?.isNotEmpty ?? false;
    return widget.paper.hasFullText &&
        !hasFull &&
        widget.documentId != null &&
        (hasPreview == false || (preview!.length >= 2990));
  }

  Future<void> _fetchFullText() async {
    if (widget.documentId == null || widget.paper.pmid.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final text = await DocumentService().getPaperFullText(
        widget.documentId!,
        widget.paper.pmid,
      );
      if (mounted) {
        setState(() {
          _loadedText = text;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final text = _loadedText;
    if (text == null || text.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Text(
          _error ??
              (widget.paper.pmcId != null
                  ? 'Full text could not be loaded for PMC ${widget.paper.pmcId}.'
                  : 'No open-access full text is available for this paper.'),
          style: AppFonts.inter(fontSize: 14, height: 1.5),
        ),
      );
    }

    final paragraphs = _splitParagraphs(text);
    final displayParagraphs = widget.compact ? paragraphs.take(6).toList() : paragraphs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.paper.pmcId != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(Icons.verified_outlined, size: 16, color: Colors.green.shade700),
                const SizedBox(width: 6),
                Text(
                  'PubMed Central · ${widget.paper.pmcId}',
                  style: AppFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ...displayParagraphs.map((p) => _paragraphCard(p)),
        if (widget.compact && paragraphs.length > displayParagraphs.length)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '+ ${paragraphs.length - displayParagraphs.length} more paragraphs',
              style: AppFonts.inter(
                fontSize: 12,
                color: AppColors.secondaryText,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  List<String> _splitParagraphs(String text) {
    return text
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim().replaceAll(RegExp(r'\s+'), ' '))
        .where((p) => p.isNotEmpty)
        .toList();
  }

  Widget _paragraphCard(String paragraph) {
    final isHeading = paragraph.length < 80 &&
        (paragraph == paragraph.toUpperCase() ||
            RegExp(r'^(Introduction|Methods|Results|Discussion|Conclusion|Background|Abstract)\b',
                    caseSensitive: false)
                .hasMatch(paragraph));

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(isHeading ? 12 : 14),
      decoration: BoxDecoration(
        color: isHeading
            ? AppColors.accentBlue.withOpacity(0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHeading
              ? AppColors.accentBlue.withOpacity(0.25)
              : Colors.grey.shade200,
        ),
      ),
      child: SelectableText(
        paragraph,
        style: AppFonts.inter(
          fontSize: isHeading ? 15 : 14,
          height: 1.65,
          fontWeight: isHeading ? FontWeight.w700 : FontWeight.w400,
          color: AppColors.primaryText,
        ),
      ),
    );
  }
}
