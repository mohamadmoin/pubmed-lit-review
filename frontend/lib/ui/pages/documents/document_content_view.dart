import 'package:flutter/material.dart';
import 'package:glass_kit/glass_kit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/models/document_model.dart';
import '../../../core/providers/document_provider.dart';
import '../../../core/theme/colors.dart';
import '../../widgets/documents/citation_rich_text.dart';
import '../../widgets/documents/paper_citation_sheet.dart';
import '../../../core/utils/document_citation_resolver.dart';

class DocumentContentView extends StatelessWidget {
  final AIGeneratedDocument document;

  const DocumentContentView({
    Key? key,
    required this.document,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: _buildDocumentContent(context),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 2,
          child: _buildDetailPanel(context),
        ),
      ],
    );
  }

  Widget _buildDocumentContent(BuildContext context) {
    return GlassContainer.clearGlass(
      height: double.infinity,
      width: double.infinity,
      color: Colors.white.withOpacity(0.3),
      borderRadius: BorderRadius.circular(18),
      elevation: 20,
      blur: 0.5,
      borderColor: Colors.white.withOpacity(0.6),
      borderGradient: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.6),
          Colors.white.withOpacity(0.3),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: document.sections.map((section) => _buildSection(context, section)).toList(),
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, DocumentSection section) {
    final provider = Provider.of<DocumentProvider>(context);
    final isSelected = provider.selectedSectionId == section.id;

    return GestureDetector(
      onTap: () => provider.selectSection(isSelected ? null : section.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentPurple.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: AppColors.accentPurple.withOpacity(0.3), width: 1.5)
              : null,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.title,
              style: GoogleFonts.poppins(
                color: AppColors.primaryText,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            CitationRichText(
              content: section.content,
              document: document,
              documentId: document.id,
              style: GoogleFonts.inter(
                color: AppColors.primaryText,
                fontSize: 16,
                height: 1.6,
              ),
            ),
            if (isSelected) const SizedBox(height: 16),
            if (isSelected)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildSectionActionButton(
                    icon: Icons.info_outline,
                    label: 'View Sources',
                    onTap: () {
                      provider.setViewingSectionSources(true);
                      provider.setActiveTab('sources');
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildSectionActionButton(
                    icon: Icons.edit_outlined,
                    label: 'Edit',
                    onTap: () {
                      // Edit functionality would be implemented here
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.accentPurple.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: AppColors.accentPurple,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                color: AppColors.accentPurple,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailPanel(BuildContext context) {
    final provider = Provider.of<DocumentProvider>(context);
    final selectedSectionId = provider.selectedSectionId;

    if (selectedSectionId == null) {
      return _buildReferencesPanel();
    }

    final section = provider.getSectionById(selectedSectionId);
    if (section == null) {
      return _buildReferencesPanel();
    }

    final references = provider.getReferencesForSection(selectedSectionId);

    return GlassContainer.clearGlass(
      height: double.infinity,
      width: double.infinity,
      color: Colors.white.withOpacity(0.2),
      borderRadius: BorderRadius.circular(18),
      elevation: 15,
      blur: 0.5,
      borderColor: Colors.white.withOpacity(0.5),
      borderGradient: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.5),
          Colors.white.withOpacity(0.2),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Section Details',
              style: GoogleFonts.poppins(
                color: AppColors.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              title: 'Section Information',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoItem('Title', section.title),
                  const SizedBox(height: 8),
                  _buildInfoItem('Word Count', '${section.content.split(' ').length} words'),
                  const SizedBox(height: 8),
                  _buildInfoItem('Citations', '${references.length} references'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (references.isNotEmpty) ...[
              Text(
                'Sources Used',
                style: GoogleFonts.poppins(
                  color: AppColors.primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ...references.map((ref) => _buildReferenceItem(context, ref)).toList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required Widget content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: AppColors.accentBlue,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: AppColors.secondaryText,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              color: AppColors.primaryText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReferenceItem(BuildContext context, DocumentReference reference) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentPurple.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.accentPurple.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.article_outlined,
                size: 16,
                color: AppColors.accentPurple,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'PMID: ${reference.pmid}',
                  style: GoogleFonts.inter(
                    color: AppColors.accentPurple,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            reference.formattedReference,
            style: GoogleFonts.inter(
              color: AppColors.primaryText,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: () {
                  final resolver = DocumentCitationResolver(document);
                  final number = resolver.pmidToNumber[reference.pmid];
                  if (number != null) {
                    showPaperCitationSheet(
                      context,
                      citationNumber: number,
                      resolver: resolver,
                      documentId: document.id,
                    );
                  }
                },
                child: Text(
                  'View Full Paper',
                  style: GoogleFonts.inter(
                    color: AppColors.accentBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReferencesPanel() {
    return GlassContainer.clearGlass(
      height: double.infinity,
      width: double.infinity,
      color: Colors.white.withOpacity(0.2),
      borderRadius: BorderRadius.circular(18),
      elevation: 15,
      blur: 0.5,
      borderColor: Colors.white.withOpacity(0.5),
      borderGradient: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.5),
          Colors.white.withOpacity(0.2),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'References',
              style: GoogleFonts.poppins(
                color: AppColors.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select a section to view detailed information and sources',
              style: GoogleFonts.inter(
                color: AppColors.secondaryText,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ...document.references.map((ref) => _buildSimpleReferenceItem(ref)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleReferenceItem(DocumentReference reference) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reference.formattedReference,
            style: GoogleFonts.inter(
              color: AppColors.primaryText,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'PMID: ${reference.pmid}',
            style: GoogleFonts.inter(
              color: AppColors.tertiaryText,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
} 