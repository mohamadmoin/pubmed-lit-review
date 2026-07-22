import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/document_provider.dart';
import '../../../core/models/document_model.dart';
import '../../../core/services/document_generation_tracker.dart';
import '../../widgets/documents/paper_full_text_view.dart';

enum SectionPaperViewMode {
  preFiltered,
  filtered,
  selected,
}

enum PaperDetailTab {
  abstract,
  fullText,
  summary,
}

enum _PaperFilter { all, withFullText, withoutFullText }

/// Reusable step screen for paper-selection and full-text pipeline stages.
class SectionPapersStepScreen extends StatefulWidget {
  final String stepLogSource;
  final String completedLogFragment;
  final SectionPaperViewMode viewMode;
  final List<PaperDetailTab> detailTabs;

  const SectionPapersStepScreen({
    Key? key,
    required this.stepLogSource,
    required this.completedLogFragment,
    required this.viewMode,
    this.detailTabs = const [PaperDetailTab.abstract],
  }) : super(key: key);

  @override
  State<SectionPapersStepScreen> createState() => _SectionPapersStepScreenState();
}

class _SectionPapersStepScreenState extends State<SectionPapersStepScreen> {
  String? _selectedSectionId;
  _PaperFilter _filter = _PaperFilter.all;

  bool _isStepCompleted(List<ProcessLog>? logs) {
    return logs?.any((log) =>
            log.source == widget.stepLogSource &&
            log.message.contains(widget.completedLogFragment)) ??
        false;
  }

  List<PaperInstanse> _papersForSection(DocumentSection section) {
    switch (widget.viewMode) {
      case SectionPaperViewMode.preFiltered:
        return section.preFilteredPapers;
      case SectionPaperViewMode.filtered:
        return section.filteredPapers;
      case SectionPaperViewMode.selected:
        return section.selectedPapers;
    }
  }

  bool _paperHasFullText(PaperInstanse paper) {
    return paper.hasFullText ||
        (paper.fullTextPreview?.isNotEmpty ?? false) ||
        (paper.fullText?.isNotEmpty ?? false);
  }

  List<PaperInstanse> _applyFilter(List<PaperInstanse> papers) {
    switch (_filter) {
      case _PaperFilter.all:
        return papers;
      case _PaperFilter.withFullText:
        return papers.where(_paperHasFullText).toList();
      case _PaperFilter.withoutFullText:
        return papers.where((p) => !_paperHasFullText(p)).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DocumentProvider>(
      builder: (context, documentProvider, child) {
        final document = documentProvider.currentDocument;
        final theme = Theme.of(context);
        final logs = documentProvider.generationLogs;

        if (!_isStepCompleted(logs)) {
          return _buildLoading(context, theme);
        }

        if (document == null || document.sections.isEmpty) {
          return _buildEmpty(context, theme, 'No sections available yet');
        }

        _selectedSectionId ??= document.sections.first.id;
        final selectedSection = document.sections.firstWhere(
          (s) => s.id == _selectedSectionId,
          orElse: () => document.sections.first,
        );
        final allPapers = _papersForSection(selectedSection);
        final papers = _applyFilter(allPapers);
        final fullTextCount = allPapers.where(_paperHasFullText).length;

        return Column(
          children: [
            _buildSectionSelector(context, document, theme),
            _buildStatsBar(theme, allPapers.length, fullTextCount),
            if (widget.detailTabs.contains(PaperDetailTab.fullText))
              _buildFilterBar(theme),
            Expanded(
              child: papers.isEmpty
                  ? _buildEmpty(
                      context,
                      theme,
                      _filter == _PaperFilter.all
                          ? 'No papers for this section yet'
                          : 'No papers match this filter',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: papers.length,
                      itemBuilder: (context, index) => _buildPaperCard(context, papers[index], theme),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionSelector(BuildContext context, AIGeneratedDocument document, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
      ),
      child: SizedBox(
        height: 44,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: document.sections.length,
          itemBuilder: (context, index) {
            final section = document.sections[index];
            final selected = section.id == _selectedSectionId;
            final sectionPapers = _papersForSection(section);
            final ftCount = sectionPapers.where(_paperHasFullText).length;
            final label = ftCount > 0 ? '${section.title} ($ftCount/${sectionPapers.length})' : section.title;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(label, overflow: TextOverflow.ellipsis),
                selected: selected,
                onSelected: (_) => setState(() {
                  _selectedSectionId = section.id;
                  _filter = _PaperFilter.all;
                }),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatsBar(ThemeData theme, int total, int fullTextCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Row(
        children: [
          Icon(Icons.analytics_outlined, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$total papers · $fullTextCount with full text · ${total - fullTextCount} abstract only',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Text('Filter:', style: theme.textTheme.labelMedium),
          const SizedBox(width: 8),
          _filterChip('All', _PaperFilter.all, theme),
          const SizedBox(width: 6),
          _filterChip('Full text', _PaperFilter.withFullText, theme),
          const SizedBox(width: 6),
          _filterChip('Abstract only', _PaperFilter.withoutFullText, theme),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _PaperFilter value, ThemeData theme) {
    final selected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildPaperCard(BuildContext context, PaperInstanse paper, ThemeData theme) {
    final hasFullText = _paperHasFullText(paper);
    final hasSummary = paper.hasSummary;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: hasFullText
              ? Colors.green.withValues(alpha: 0.15)
              : Colors.orange.withValues(alpha: 0.15),
          child: Icon(
            hasFullText ? Icons.article : Icons.description_outlined,
            color: hasFullText ? Colors.green.shade700 : Colors.orange.shade700,
            size: 20,
          ),
        ),
        title: Text(paper.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(paper.authorString, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('PMID: ${paper.pmid}', style: theme.textTheme.bodySmall),
            if (paper.pmcId != null)
              Text('PMC: ${paper.pmcId}', style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _statusChip(
                  hasFullText ? 'Full text available' : 'Abstract only',
                  hasFullText ? Colors.green : Colors.orange,
                ),
                if (hasSummary)
                  _statusChip('Summary ready', Colors.blue),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          final documentId = context.read<DocumentProvider>().generatingDocumentId ??
              context.read<DocumentProvider>().currentDocument?.id;
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => _PaperDetailSheet(
              paper: paper,
              tabs: widget.detailTabs,
              documentId: documentId,
            ),
          );
        },
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Chip(
      label: Text(label, style: TextStyle(color: color, fontSize: 11)),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildLoading(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text('${widget.stepLogSource} in progress…'),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, ThemeData theme, String message) {
    return Center(child: Text(message, style: theme.textTheme.titleMedium));
  }
}

class _PaperDetailSheet extends StatelessWidget {
  final PaperInstanse paper;
  final List<PaperDetailTab> tabs;
  final String? documentId;

  const _PaperDetailSheet({
    required this.paper,
    required this.tabs,
    this.documentId,
  });

  bool _hasFullText() {
    return paper.hasFullText ||
        (paper.fullTextPreview?.isNotEmpty ?? false) ||
        (paper.fullText?.isNotEmpty ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveTabs = List<PaperDetailTab>.from(tabs);
    if (!effectiveTabs.contains(PaperDetailTab.fullText)) {
      effectiveTabs.add(PaperDetailTab.fullText);
    }
    final tabWidgets = effectiveTabs.map(_tab).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (context, scrollController) {
        return Material(
          child: DefaultTabController(
            length: tabWidgets.length,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(paper.title, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text('PMID: ${paper.pmid}', style: theme.textTheme.bodySmall),
                      if (paper.pmcId != null)
                        Text('PMC ID: ${paper.pmcId}', style: theme.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text(
                        _hasFullText()
                            ? 'Full text was retrieved from PubMed Central.'
                            : paper.pmcId != null
                                ? 'PMC record exists but full text could not be parsed.'
                                : 'No open-access PMC record — abstract only.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _hasFullText() ? Colors.green.shade700 : Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                TabBar(tabs: tabWidgets),
                Expanded(
                  child: TabBarView(
                    children: effectiveTabs.map((tab) {
                      return SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        child: _buildTabContent(tab, theme),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Tab _tab(PaperDetailTab tab) {
    switch (tab) {
      case PaperDetailTab.abstract:
        return const Tab(text: 'Abstract');
      case PaperDetailTab.fullText:
        return Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Full Text'),
              if (!_hasFullText()) ...[
                const SizedBox(width: 4),
                Icon(Icons.info_outline, size: 14, color: Colors.orange.shade700),
              ],
            ],
          ),
        );
      case PaperDetailTab.summary:
        return const Tab(text: 'Summary');
    }
  }

  Widget _buildTabContent(PaperDetailTab tab, ThemeData theme) {
    switch (tab) {
      case PaperDetailTab.abstract:
        return _textPanel(
          theme,
          paper.abstract.isNotEmpty ? paper.abstract : 'Abstract not available.',
        );
      case PaperDetailTab.fullText:
        if (!_hasFullText() && paper.pmcId == null) {
          return _textPanel(
            theme,
            'This paper is not available in PubMed Central open access. Only the abstract is available.',
            tone: Colors.orange.shade50,
          );
        }
        return PaperFullTextView(
          paper: paper,
          documentId: documentId,
        );
      case PaperDetailTab.summary:
        return _textPanel(
          theme,
          paper.summary?.isNotEmpty == true
              ? paper.summary!
              : 'Summary not generated yet.',
        );
    }
  }

  Widget _textPanel(ThemeData theme, String text, {Color? tone}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone ?? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
      ),
      child: SelectableText(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.65),
      ),
    );
  }
}
