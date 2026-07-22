import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/document_provider.dart';
import '../../../core/models/document_model.dart';
import '../../widgets/documents/generation_step_activity.dart';

class PubMedSearchStepScreen extends StatefulWidget {
  const PubMedSearchStepScreen({Key? key}) : super(key: key);

  @override
  State<PubMedSearchStepScreen> createState() => _PubMedSearchStepScreenState();
}

class _PubMedSearchStepScreenState extends State<PubMedSearchStepScreen> with SingleTickerProviderStateMixin {
  String? _selectedSectionId;
  bool _showFilteredPapers = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DocumentProvider>(
      builder: (context, documentProvider, child) {
        final document = documentProvider.currentDocument;
        final logs = documentProvider.generationLogs;
        final theme = Theme.of(context);

        // Check if PubMed Search is completed
        final isSearchCompleted = logs?.any((log) => 
          log.source == 'PubMed Search' && 
          log.message?.contains('PubMed Search: Completed') == true
        ) ?? false;

        if (!isSearchCompleted) {
          final hasPartialData = document != null &&
              document.sections.any(
                (s) => s.preFilteredPapers.isNotEmpty || s.filteredPapers.isNotEmpty,
              );
          if (!hasPartialData) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: GenerationStepActivity(
                stepSource: 'PubMed Search',
                logs: logs,
                workingMessage: 'Searching PubMed for relevant papers…',
              ),
            );
          }
        }

        if (document == null || document.sections.isEmpty) {
          return _buildEmptyState(context);
        }

        // If no section is selected, select the first one
        if (_selectedSectionId == null) {
          _selectedSectionId = document.sections.first.id;
        }

        final selectedSection = document.sections.firstWhere(
          (section) => section.id == _selectedSectionId,
          orElse: () => document.sections.first,
        );

        return Column(
          children: [
            // Modern section selector with gradient background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.1),
                    theme.colorScheme.primary.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.article_outlined,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Section',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: document.sections.length,
                      itemBuilder: (context, index) {
                        final section = document.sections[index];
                        final isSelected = section.id == _selectedSectionId;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(
                              section.title,
                              style: TextStyle(
                                color: isSelected 
                                    ? theme.colorScheme.onPrimary 
                                    : theme.colorScheme.onSurface,
                                fontWeight: isSelected ? FontWeight.bold : null,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedSectionId = section.id);
                              }
                            },
                            backgroundColor: theme.colorScheme.surface,
                            selectedColor: theme.colorScheme.primary,
                            checkmarkColor: theme.colorScheme.onPrimary,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Tab bar for paper types
            TabBar(
              controller: _tabController,
              onTap: (index) => setState(() => _showFilteredPapers = index == 1),
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
              indicatorColor: theme.colorScheme.primary,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'Pre-filtered'),
                Tab(text: 'Filtered'),
              ],
            ),

            // Papers list with shimmer effect
            Expanded(
              child: _buildPapersList(
                context,
                selectedSection,
                _showFilteredPapers,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPapersList(
    BuildContext context,
    DocumentSection section,
    bool showFilteredPapers,
  ) {
    final papers = showFilteredPapers
        ? section.filteredPapers
        : section.preFilteredPapers;

    if (papers.isEmpty) {
      return _buildEmptyPapersState(context, showFilteredPapers);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: papers.length,
      itemBuilder: (context, index) {
        final paper = papers[index];
        return _buildPaperCard(context, paper);
      },
    );
  }

  Widget _buildPaperCard(BuildContext context, PaperInstanse paper) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => _buildPaperDetailsSheet(context, paper),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title with relevance score
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      paper.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (paper.relevanceScore != 1.0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${(paper.relevanceScore * 100).toInt()}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Authors
              Text(
                paper.authorString,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 4),
              
              // Journal and date
              Row(
                children: [
                  Icon(
                    Icons.article_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${paper.journal} • ${paper.publicationDate}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _buildStatusChip(
                    _paperHasFullText(paper) ? 'Full text' : 'Abstract only',
                    _paperHasFullText(paper) ? Colors.green : Colors.orange,
                  ),
                  if (paper.hasSummary)
                    _buildStatusChip('Summary', Colors.blue),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _paperHasFullText(PaperInstanse paper) {
    return paper.hasFullText ||
        (paper.fullTextPreview?.isNotEmpty ?? false) ||
        (paper.fullText?.isNotEmpty ?? false);
  }

  Widget _buildStatusChip(String label, Color color) {
    return Chip(
      label: Text(label, style: TextStyle(color: color, fontSize: 11)),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildPaperDetailsSheet(BuildContext context, PaperInstanse paper) {
    final theme = Theme.of(context);
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              paper.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Authors and metadata
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paper.authorString,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 16,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      paper.journal,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '•',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      paper.publicationDate,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Abstract / full text / summary tabs when available
          Expanded(
            child: DefaultTabController(
              length: _detailTabCount(paper),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TabBar(
                    tabs: _detailTabs(paper),
                    labelColor: theme.colorScheme.primary,
                  ),
                  Expanded(
                    child: TabBarView(
                      children: _detailTabViews(paper, theme),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // PMID
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.tag_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
                const SizedBox(width: 8),
                Text(
                  'PMID: ${paper.pmid}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _detailTabCount(PaperInstanse paper) => 3;

  List<Tab> _detailTabs(PaperInstanse paper) {
    return const [
      Tab(text: 'Abstract'),
      Tab(text: 'Full Text'),
      Tab(text: 'Summary'),
    ];
  }

  List<Widget> _detailTabViews(PaperInstanse paper, ThemeData theme) {
    final fullText = paper.fullTextPreview ?? paper.fullText;
    return [
      SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Text(
          paper.abstract.isNotEmpty ? paper.abstract : 'No abstract available.',
          style: theme.textTheme.bodyLarge,
        ),
      ),
      SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Text(
          fullText?.isNotEmpty == true
              ? fullText!
              : paper.pmcId != null
                  ? 'PMC record ${paper.pmcId} found but full text could not be retrieved.'
                  : 'Not available in PubMed Central open access.',
          style: theme.textTheme.bodyMedium,
        ),
      ),
      SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Text(
          paper.summary?.isNotEmpty == true ? paper.summary! : 'Summary not generated yet.',
          style: theme.textTheme.bodyMedium,
        ),
      ),
    ];
  }

  Widget _buildLoadingPlaceholder(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search,
              size: 48,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Searching PubMed...',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Finding relevant papers for your document',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off,
              size: 48,
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No sections available',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please create a document structure first',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPapersState(BuildContext context, bool showFilteredPapers) {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off,
              size: 48,
              color: theme.colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No ${showFilteredPapers ? 'filtered' : 'pre-filtered'} papers',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search criteria',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
} 