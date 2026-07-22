import 'package:flutter/material.dart';
import 'package:litreview_app/ui/widgets/glass_panel.dart';
import 'package:litreview_app/core/theme/app_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/document_model.dart';
import '../../../core/providers/document_provider.dart';
import '../../../core/theme/colors.dart';

class DocumentSourcesView extends StatelessWidget {
  final AIGeneratedDocument document;

  const DocumentSourcesView({
    Key? key,
    required this.document,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 1,
          child: _buildSourcesList(context),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 2,
          child: _buildSourceDetails(context),
        ),
      ],
    );
  }

  Widget _buildSourcesList(BuildContext context) {
    final provider = Provider.of<DocumentProvider>(context);
    final isViewingSectionSources = provider.viewingSectionSources;
    final selectedSectionId = provider.selectedSectionId;

    // Get the appropriate list of sources based on context
    final sources = isViewingSectionSources && selectedSectionId != null
        ? provider.getPaperSummariesForSection(selectedSectionId)
        : document.references;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  isViewingSectionSources ? 'Selected Papers' : 'References',
                  style: AppFonts.heading(
                    color: AppColors.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.accentPurple.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${sources.length} ${isViewingSectionSources ? 'papers' : 'references'}',
                    style: AppFonts.inter(
                      color: AppColors.accentPurple,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white30),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: sources.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
              itemBuilder: (context, index) {
                final source = sources[index];
                return isViewingSectionSources
                    ? _buildPaperListItem(context, source as PaperInstanse)
                    : _buildReferenceListItem(context, source as DocumentReference);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaperListItem(BuildContext context, PaperInstanse paper) {
    final provider = Provider.of<DocumentProvider>(context);
    final isSelected = provider.selectedPaperId == paper.pmid;

    return InkWell(
      onTap: () => provider.selectPaper(isSelected ? null : paper.pmid),
      child: Container(
        padding: const EdgeInsets.all(16),
        color: isSelected ? AppColors.accentBlue.withOpacity(0.1) : Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.article_outlined,
                  size: 16,
                  color: AppColors.accentBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'PMID: ${paper.pmid}',
                    style: AppFonts.inter(
                      color: AppColors.accentBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              paper.title,
              style: AppFonts.inter(
                color: AppColors.primaryText,
                fontSize: 13,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              paper.authorString,
              style: AppFonts.inter(
                color: AppColors.secondaryText,
                fontSize: 12,
                height: 1.4,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.accentPurple.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Relevance: ${(paper.relevanceScore * 100).toStringAsFixed(1)}%',
                    style: AppFonts.inter(
                      color: AppColors.accentPurple,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferenceListItem(BuildContext context, DocumentReference reference) {
    final provider = Provider.of<DocumentProvider>(context);
    final isSelected = provider.selectedPaperId == reference.pmid;

    // Count how many sections cite this reference
    final sectionCount = reference.citedInSectionIds.length;

    return InkWell(
      onTap: () => provider.selectPaper(isSelected ? null : reference.pmid),
      child: Container(
        padding: const EdgeInsets.all(16),
        color: isSelected ? AppColors.accentBlue.withOpacity(0.1) : Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.article_outlined,
                  size: 16,
                  color: AppColors.accentBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'PMID: ${reference.pmid}',
                    style: AppFonts.inter(
                      color: AppColors.accentBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              reference.formattedReference,
              style: AppFonts.inter(
                color: AppColors.primaryText,
                fontSize: 13,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.accentPurple.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Used in $sectionCount section${sectionCount != 1 ? 's' : ''}',
                    style: AppFonts.inter(
                      color: AppColors.accentPurple,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceDetails(BuildContext context) {
    final provider = Provider.of<DocumentProvider>(context);
    final selectedPaperId = provider.selectedPaperId;
    final isViewingSectionSources = provider.viewingSectionSources;
    final selectedSectionId = provider.selectedSectionId;

    if (selectedPaperId == null) {
      return _buildSourcesOverview();
    }

    if (isViewingSectionSources && selectedSectionId != null) {
      final papers = provider.getPaperSummariesForSection(selectedSectionId);
      final paper = papers.firstWhere(
        (p) => p.pmid == selectedPaperId,
        orElse: () => papers.first,
      );
      return _buildPaperDetails(context, paper);
    } else {
      final reference = document.references.firstWhere(
        (ref) => ref.pmid == selectedPaperId,
        orElse: () => document.references.first,
      );
      return _buildReferenceDetails(context, reference);
    }
  }

  Widget _buildPaperDetails(BuildContext context, PaperInstanse paper) {
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
              'Paper Details',
              style: AppFonts.heading(
                color: AppColors.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _buildPaperDetailCard(paper),
            const SizedBox(height: 24),
            _buildPaperActions(context, paper: paper),
          ],
        ),
      ),
    );
  }

  Widget _buildPaperDetailCard(PaperInstanse paper) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
            paper.title,
            style: AppFonts.inter(
              color: AppColors.primaryText,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Colors.white30),
          const SizedBox(height: 16),
          _buildInfoRow('Authors', paper.authorString),
          const SizedBox(height: 8),
          _buildInfoRow('Journal', paper.journal),
          const SizedBox(height: 8),
          _buildInfoRow('Publication Date', paper.publicationDate),
          const SizedBox(height: 8),
          _buildInfoRow('Relevance Score', '${(paper.relevanceScore * 100).toStringAsFixed(1)}%'),
          if (paper.abstract.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: Colors.white30),
            const SizedBox(height: 16),
            Text(
              'Abstract',
              style: AppFonts.inter(
                color: AppColors.accentBlue,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              paper.abstract,
              style: AppFonts.inter(
                color: AppColors.primaryText,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
          if (paper.summary?.isNotEmpty ?? false) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: Colors.white30),
            const SizedBox(height: 16),
            Text(
              'AI Summary',
              style: AppFonts.inter(
                color: AppColors.accentBlue,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              paper.summary!,
              style: AppFonts.inter(
                color: AppColors.primaryText,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
          if (paper.hasFullText && (paper.fullTextPreview?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: Colors.white30),
            const SizedBox(height: 16),
            Text(
              'Full Text Preview',
              style: AppFonts.inter(
                color: AppColors.accentBlue,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              paper.fullTextPreview!,
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.inter(
                color: AppColors.primaryText,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: AppFonts.inter(
              color: AppColors.secondaryText,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppFonts.inter(
              color: AppColors.primaryText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaperActions(BuildContext context, {PaperInstanse? paper, DocumentReference? reference}) {
    final pmid = paper?.pmid ?? reference?.pmid ?? '';
    final pmcId = paper?.pmcId;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildActionButton(
          icon: Icons.open_in_new,
          label: 'View Full Paper',
          onTap: () {
            if (paper != null) {
              _showPaperContentDialog(context, paper);
            } else if (reference != null) {
              final matchedPaper = _findPaperByPmid(reference.pmid);
              if (matchedPaper != null) {
                _showPaperContentDialog(context, matchedPaper);
              } else if (reference.pmid.isNotEmpty) {
                _openExternalUrl('https://pubmed.ncbi.nlm.nih.gov/${reference.pmid}/');
              }
            }
          },
        ),
        const SizedBox(width: 16),
        _buildActionButton(
          icon: Icons.download_outlined,
          label: 'Open in PubMed',
          onTap: () {
            if (pmid.isNotEmpty) {
              _openExternalUrl('https://pubmed.ncbi.nlm.nih.gov/$pmid/');
            } else if (pmcId != null && pmcId.isNotEmpty) {
              final id = pmcId.startsWith('PMC') ? pmcId : 'PMC$pmcId';
              _openExternalUrl('https://www.ncbi.nlm.nih.gov/pmc/articles/$id/');
            }
          },
        ),
      ],
    );
  }

  PaperInstanse? _findPaperByPmid(String pmid) {
    if (pmid.isEmpty) return null;
    for (final section in document.sections) {
      for (final paper in [
        ...section.selectedPapers,
        ...section.filteredPapers,
        ...section.preFilteredPapers,
      ]) {
        if (paper.pmid == pmid) return paper;
      }
    }
    return null;
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showPaperContentDialog(BuildContext context, PaperInstanse paper) {
    final content = paper.fullText ??
        paper.fullTextPreview ??
        paper.summary ??
        paper.abstract;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          paper.title.isNotEmpty ? paper.title : 'Paper ${paper.pmid}',
          style: AppFonts.heading(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Text(
              content.isNotEmpty
                  ? content
                  : 'No stored full text for this paper. Open in PubMed to read the abstract online.',
              style: AppFonts.inter(fontSize: 14, height: 1.5),
            ),
          ),
        ),
        actions: [
          if (paper.pmid.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openExternalUrl('https://pubmed.ncbi.nlm.nih.gov/${paper.pmid}/');
              },
              child: const Text('Open in PubMed'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.accentBlue.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.accentBlue.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: AppColors.accentBlue,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppFonts.inter(
                color: AppColors.accentBlue,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourcesOverview() {
    // Group references by section
    final sectionToReferences = <String, List<DocumentReference>>{};
    for (final reference in document.references) {
      for (final sectionId in reference.citedInSectionIds) {
        if (!sectionToReferences.containsKey(sectionId)) {
          sectionToReferences[sectionId] = [];
        }
        sectionToReferences[sectionId]!.add(reference);
      }
    }

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
              'Sources Overview',
              style: AppFonts.heading(
                color: AppColors.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select a source from the list to view detailed information',
              style: AppFonts.inter(
                color: AppColors.secondaryText,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            _buildSourcesDistributionCard(sectionToReferences),
            const SizedBox(height: 32),
            _buildSourcesStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildSourcesDistributionCard(Map<String, List<DocumentReference>> sectionToReferences) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
            'Sources Distribution',
            style: AppFonts.heading(
              color: AppColors.accentBlue,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...document.sections.map((section) {
            final references = sectionToReferences[section.id] ?? [];
            return _buildSectionSourcesItem(section, references);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSectionSourcesItem(DocumentSection section, List<DocumentReference> references) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: AppFonts.inter(
              color: AppColors.primaryText,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.accentPurple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: references.length / (document.references.length > 0 ? document.references.length : 1),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.accentPurple,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${references.length} source${references.length != 1 ? 's' : ''}',
                style: AppFonts.inter(
                  color: AppColors.accentPurple,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSourcesStats() {
    // Get unique papers (by PMID)
    final uniquePmids = <String>{};
    for (final reference in document.references) {
      uniquePmids.add(reference.pmid);
    }

    // Calculate stats
    final totalSources = uniquePmids.length;
    final totalCitations = document.references.length;
    final avgSourcesPerSection = document.sections.isNotEmpty
        ? totalCitations / document.sections.length
        : 0;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Total Sources',
            value: totalSources.toString(),
            icon: Icons.source_outlined,
            color: AppColors.accentBlue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            title: 'Total Citations',
            value: totalCitations.toString(),
            icon: Icons.format_quote_outlined,
            color: AppColors.accentPurple,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            title: 'Avg. Sources per Section',
            value: avgSourcesPerSection.toStringAsFixed(1),
            icon: Icons.bar_chart_outlined,
            color: AppColors.accentPink,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppFonts.inter(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppFonts.heading(
              color: AppColors.primaryText,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceDetails(BuildContext context, DocumentReference reference) {
    final provider = Provider.of<DocumentProvider>(context);

    // Find all sections where this reference is used
    final relatedSections = <DocumentSection>[];
    for (final sectionId in reference.citedInSectionIds) {
      final section = provider.getSectionById(sectionId);
      if (section != null) {
        relatedSections.add(section);
      }
    }

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
              'Reference Details',
              style: AppFonts.heading(
                color: AppColors.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _buildReferenceDetailCard(reference),
            const SizedBox(height: 24),
            if (relatedSections.isNotEmpty) ...[
              Text(
                'Used in Sections',
                style: AppFonts.heading(
                  color: AppColors.primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ...relatedSections.map((section) => _buildRelatedSectionItem(context, section)).toList(),
            ],
            const SizedBox(height: 24),
            _buildPaperActions(context, reference: reference),
          ],
        ),
      ),
    );
  }

  Widget _buildReferenceDetailCard(DocumentReference reference) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
            reference.formattedReference,
            style: AppFonts.inter(
              color: AppColors.primaryText,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Colors.white30),
          const SizedBox(height: 16),
          _buildInfoRow('PMID', reference.pmid),
          const SizedBox(height: 8),
          _buildInfoRow('Cited In', '${reference.citedInSectionIds.length} section(s)'),
          const SizedBox(height: 8),
          _buildInfoRow('Source Type', 'Research Paper'),
        ],
      ),
    );
  }

  Widget _buildRelatedSectionItem(BuildContext context, DocumentSection section) {
    final provider = Provider.of<DocumentProvider>(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.accentBlue.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: AppFonts.heading(
              color: AppColors.primaryText,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            section.content,
            style: AppFonts.inter(
              color: AppColors.secondaryText,
              fontSize: 14,
              height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () {
                provider.selectSection(section.id);
                provider.setActiveTab('document');
              },
              child: Text(
                'View in Document',
                style: AppFonts.inter(
                  color: AppColors.accentBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 