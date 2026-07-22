import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/document_model.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/document_citation_resolver.dart';
import 'paper_full_text_view.dart';

/// Bottom sheet shown when the user taps an in-text citation.
Future<void> showPaperCitationSheet(
  BuildContext context, {
  required int citationNumber,
  required DocumentCitationResolver resolver,
  String? documentId,
}) async {
  final target = resolver.targetForNumber(citationNumber);
  if (target == null) return;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _PaperCitationSheet(
      citationNumber: citationNumber,
      target: target,
      documentId: documentId,
    ),
  );
}

class _PaperCitationSheet extends StatelessWidget {
  final int citationNumber;
  final CitationTarget target;
  final String? documentId;

  const _PaperCitationSheet({
    required this.citationNumber,
    required this.target,
    this.documentId,
  });

  PaperInstanse? get _paper => target.paper;

  @override
  Widget build(BuildContext context) {
    final paper = _paper;
    final reference = target.reference;
    final title = paper?.title.isNotEmpty == true
        ? paper!.title
        : reference?.formattedReference ?? 'Reference $citationNumber';

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.accentPurple.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '[$citationNumber]',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentPurple,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    if (reference != null) ...[
                      _infoBlock('Reference', reference.formattedReference),
                      const SizedBox(height: 16),
                    ],
                    if (paper != null) ...[
                      if (paper.authorString.isNotEmpty)
                        _metaRow(Icons.person_outline, paper.authorString),
                      if (paper.journal.isNotEmpty)
                        _metaRow(Icons.menu_book_outlined, paper.journal),
                      if (paper.publicationDate.isNotEmpty)
                        _metaRow(Icons.calendar_today_outlined, paper.publicationDate),
                      if (paper.pmid.isNotEmpty)
                        _metaRow(Icons.tag, 'PMID: ${paper.pmid}'),
                      const SizedBox(height: 16),
                      if (paper.abstract.isNotEmpty)
                        _infoBlock('Abstract', paper.abstract),
                      if (paper.summary?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 16),
                        _infoBlock('AI Summary', paper.summary!),
                      ],
                      if (paper.hasFullText ||
                          (paper.fullTextPreview?.isNotEmpty ?? false)) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Full text',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentBlue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        PaperFullTextView(
                          paper: paper,
                          documentId: documentId,
                          compact: true,
                        ),
                      ],
                    ] else if (reference != null && reference.pmid.isNotEmpty) ...[
                      _metaRow(Icons.tag, 'PMID: ${reference.pmid}'),
                      const SizedBox(height: 12),
                      Text(
                        'Paper metadata is not stored for this reference. Open PubMed to read the abstract.',
                        style: GoogleFonts.inter(color: AppColors.secondaryText),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if ((paper?.pmid.isNotEmpty ?? false) ||
                        (reference?.pmid.isNotEmpty ?? false))
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final pmid = paper?.pmid ?? reference!.pmid;
                            _openPubMed(pmid);
                          },
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Open in PubMed'),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _metaRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.secondaryText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.secondaryText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBlock(String label, String body) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: AppColors.accentBlue,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: GoogleFonts.inter(fontSize: 14, height: 1.55),
          ),
        ],
      ),
    );
  }

  Future<void> _openPubMed(String pmid) async {
    final uri = Uri.parse('https://pubmed.ncbi.nlm.nih.gov/$pmid/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
