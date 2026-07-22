import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/document_provider.dart';
import '../../../core/services/document_generation_tracker.dart';
import '../../../core/models/document_model.dart';
import '../../widgets/step_process/step_process.dart';
import 'pubmed_search_step_screen.dart';
import 'section_papers_step_screen.dart';
import 'document_preview_screen.dart';

class DocumentGenerationProgressScreen extends StatefulWidget {
  const DocumentGenerationProgressScreen({Key? key}) : super(key: key);

  @override
  State<DocumentGenerationProgressScreen> createState() => _DocumentGenerationProgressScreenState();
}

class _DocumentGenerationProgressScreenState extends State<DocumentGenerationProgressScreen> {
  // Track if we've shown a completed message
  bool _hasShownCompletionMessage = false;

  bool _isLogStepCompleted(ProcessLog log) {
    final message = log.message.toLowerCase();
    return log.level.toLowerCase() == 'completed' ||
        message.contains(': completed') ||
        message.contains(': section completed');
  }

  bool _hasProcessCompleted(List<ProcessLog>? logs) {
    if (logs == null) return false;
    return logs.any(
      (log) => log.message.contains('Process: Completed'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<DocumentProvider>(
        builder: (context, documentProvider, child) {
          final logs = documentProvider.generationLogs;
          
          // Convert provider steps to our StepModel format
          final steps = _buildStepsFromProvider(documentProvider);
          
          // Check if all steps are completed to potentially navigate away
          final allCompleted = _areAllStepsCompleted(steps) || _hasProcessCompleted(logs);
          if (allCompleted && !_hasShownCompletionMessage) {
            _hasShownCompletionMessage = true;
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) {
                // Pop the generation progress screen
                Navigator.of(context).pop();
                // Navigate to the preview screen
                if (documentProvider.generatingDocumentId != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => DocumentPreviewScreen(
                        documentId: documentProvider.generatingDocumentId!,
                      ),
                    ),
                  );
                }
              }
            });
          }

          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Use horizontal layout for narrow screens
                final isWideScreen = constraints.maxWidth > 700;
                
                return StepProcessContainer(
                  steps: steps,
                  isVertical: isWideScreen, 
                  initialStepIndex: _getActiveStepIndex(steps),
                  onStepSelected: (index) {
                    // Optional: Add any additional logic when a step is selected
                  },
                  header: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: isWideScreen
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Document Generation',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          documentProvider.generationStatusMessage ?? 'In progress...',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  footer: isWideScreen 
                      ? Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: TextButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Cancel Generation?'),
                                  content: const Text(
                                    'Do you want to cancel the document generation? '
                                    'This will not delete any already generated content.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(),
                                      child: const Text('No, continue'),
                                    ),
                                    FilledButton(
                                      onPressed: () {
                                        documentProvider.cancelGenerationTracking();
                                        Navigator.of(ctx).pop();
                                        Navigator.of(context).pop();
                                      },
                                      child: const Text('Yes, cancel'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text('Cancel Generation'),
                          ),
                        )
                      : null,
                  contentBuilder: (context, step) {
                    // We can customize each step's content
                    return _buildContentForStep(context, step, documentProvider);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
  
  /// Build content for a specific step
  Widget _buildContentForStep(BuildContext context, StepModel step, DocumentProvider provider) {
    // Here we could build custom content for each step type
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with step icon and title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: step.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  step.icon,
                  color: step.color,
                  size: 32,
                ),
              ),
              
              const SizedBox(width: 16),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      step.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Status chip
          if (step.status != StepStatus.pending)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _getStatusColor(step.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getStatusIcon(step.status),
                    color: _getStatusColor(step.status),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getStatusText(step.status),
                    style: TextStyle(
                      color: _getStatusColor(step.status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 32),
          
          // Content specific to each step
          Expanded(
            child: _buildSpecificStepContent(context, step, provider),
          ),
        ],
      ),
    );
  }
  
  /// Build the content specific to each step type
  Widget _buildSpecificStepContent(BuildContext context, StepModel step, DocumentProvider provider) {
    // Special handling for Document Structure step
    if (step.title == 'Document Structure') {
      return _buildDocumentStructureContent(context, step, provider);
    }
    
    // Special handling for PubMed Search step
    if (step.title == 'PubMed Search') {
      return const PubMedSearchStepScreen();
    }

    if (step.title == 'Paper Selection') {
      return const SectionPapersStepScreen(
        stepLogSource: 'Paper Selection',
        completedLogFragment: 'Paper Selection: Completed',
        viewMode: SectionPaperViewMode.selected,
        detailTabs: [PaperDetailTab.abstract],
      );
    }

    if (step.title == 'Full Text Retrieval') {
      return const SectionPapersStepScreen(
        stepLogSource: 'Full Text Retrieval',
        completedLogFragment: 'Full Text Retrieval: Completed',
        viewMode: SectionPaperViewMode.selected,
        detailTabs: [PaperDetailTab.abstract, PaperDetailTab.fullText],
      );
    }

    if (step.title == 'Content Generation') {
      return const SectionPapersStepScreen(
        stepLogSource: 'Content Generation',
        completedLogFragment: 'Content Generation: Completed',
        viewMode: SectionPaperViewMode.selected,
        detailTabs: [PaperDetailTab.abstract, PaperDetailTab.fullText, PaperDetailTab.summary],
      );
    }

    // Special handling for Final Document step
    if (step.title == 'Final Document') {
      // We'll reuse the content part of DocumentPreviewScreen
      return _buildDocumentPreviewContent(context, provider);
    }
    
    // For other steps, use the default placeholder
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: step.color.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: step.color.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            step.icon,
            size: 64,
            color: step.color.withOpacity(0.7),
          ),
          const SizedBox(height: 24),
          Text(
            'Content for ${step.title}',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'This area will contain detailed information and controls for the ${step.title.toLowerCase()} step.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          
          // Display logs if any
          if (provider.generationLogs != null && provider.generationLogs!.isNotEmpty)
            const SizedBox(height: 32),
            
          if (provider.generationLogs != null && provider.generationLogs!.isNotEmpty)
            Expanded(
              child: _buildLogsSection(context, step, provider),
            ),
        ],
      ),
    );
  }
  
  /// Build content for the Document Structure step
  Widget _buildDocumentStructureContent(BuildContext context, StepModel step, DocumentProvider provider) {
    final document = provider.currentDocument;
    final logs = provider.generationLogs;



    
    // Check if document structure is completed
    final isStructureCompleted = logs?.any((log) => 
      log.source == 'Document Structure' && 
      log.message?.contains('Document Structure: Completed') == true
    ) ?? false;
    
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: step.color.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: step.color.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Show loading placeholder until structure is completed
              if (!isStructureCompleted) ...[
                Expanded(
                  child: _buildLoadingPlaceholder(context),
                ),
              ] else if (document != null) ...[
                _buildDocumentHeader(context, document, step),
                const SizedBox(height: 32),
                Expanded(
                  child: _buildSectionsList(context, document, step),
                ),
              ] else ...[
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.sync,
                          size: 48,
                          color: step.color.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Fetching document data...',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              // Logs section at the bottom - Always show if there are logs
              if (logs != null && logs.isNotEmpty) ...[
                const SizedBox(height: 32),
                SizedBox(
                  height: 200,
                  child: _buildLogsSection(context, step, provider),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Build the document header with metadata
  Widget _buildDocumentHeader(BuildContext context, AIGeneratedDocument document, StepModel step) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title with icon
        Row(
          children: [
            Icon(
              Icons.description_outlined,
              color: step.color,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                document.title ?? 'Untitled Document',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Description
        if (document.description != null && document.description!.isNotEmpty)
          Text(
            document.description!,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        
        const SizedBox(height: 16),
        
        // Creation date
        Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(width: 8),
            Text(
              'Created ${_formatDate(document.createdAt)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Build the sections list with search terms
  Widget _buildSectionsList(BuildContext context, AIGeneratedDocument document, StepModel step) {
    if (document.sections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 48,
              color: step.color.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No sections available yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: document.sections.length,
      itemBuilder: (context, index) {
        final section = document.sections[index];
        return _buildSectionCard(context, section, step);
      },
    );
  }

  /// Build a section card with title, description and search terms
  Widget _buildSectionCard(BuildContext context, DocumentSection section, StepModel step) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section title
            Row(
              children: [
                Icon(
                  Icons.article_outlined,
                  color: step.color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    section.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Section content preview
            Text(
              section.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Paper counts
            Row(
              children: [
                _buildPaperCountChip(
                  context,
                  'Pre-filtered',
                  section.preFilteredPapers.length,
                  step.color,
                ),
                const SizedBox(width: 8),
                _buildPaperCountChip(
                  context,
                  'Filtered',
                  section.filteredPapers.length,
                  step.color,
                ),
                const SizedBox(width: 8),
                _buildPaperCountChip(
                  context,
                  'Selected',
                  section.selectedPapers.length,
                  step.color,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build a chip showing paper count
  Widget _buildPaperCountChip(BuildContext context, String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build a loading placeholder with shimmer effect
  Widget _buildLoadingPlaceholder(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title placeholder
          ShimmerPlaceholder(
            width: double.infinity,
            height: 32,
            borderRadius: 8,
          ),
          
          const SizedBox(height: 16),
          
          // Description placeholder
          ShimmerPlaceholder(
            width: double.infinity,
            height: 80,
            borderRadius: 8,
          ),
          
          const SizedBox(height: 16),
          
          // Date placeholder
          ShimmerPlaceholder(
            width: 200,
            height: 20,
            borderRadius: 4,
          ),
          
          const SizedBox(height: 32),
          
          // Sections placeholders
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ShimmerPlaceholder(
                  width: double.infinity,
                  height: 160,
                  borderRadius: 12,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Build a section to display logs
  Widget _buildLogsSection(BuildContext context, StepModel step, DocumentProvider provider) {
    // Filter logs for this step
    final stepLogs = provider.generationLogs!
        .where((log) => log.source == step.title)
        .toList();
    
    if (stepLogs.isEmpty) {
      return const Center(
        child: Text('No logs available for this step.'),
      );
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Process Logs',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: stepLogs.length,
              itemBuilder: (context, index) {
                final log = stepLogs[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${log.timestamp.hour}:${log.timestamp.minute}:${log.timestamp.second}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          log.message ?? '',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper methods
  
  /// Convert provider data to our step model format
  List<StepModel> _buildStepsFromProvider(DocumentProvider provider) {
    final steps = [
      StepModel(
        title: 'Document Structure',
        description: 'Creating the document outline and structure',
        icon: Icons.architecture,
        color: Colors.blue,
        status: _getStepStatusFromLogs('Document Structure', provider.generationLogs),
      ),
      StepModel(
        title: 'PubMed Search',
        description: 'Searching for scientific papers and filtering results',
        icon: Icons.search,
        color: Colors.green,
        status: _getStepStatusFromLogs('PubMed Search', provider.generationLogs),
      ),
      StepModel(
        title: 'Paper Selection',
        description: 'Selecting relevant papers for each section',
        icon: Icons.library_books,
        color: Colors.orange,
        status: _getStepStatusFromLogs('Paper Selection', provider.generationLogs),
      ),
      StepModel(
        title: 'Full Text Retrieval',
        description: 'Retrieving full text of selected papers',
        icon: Icons.download,
        color: Colors.purple,
        status: _getStepStatusFromLogs('Full Text Retrieval', provider.generationLogs),
      ),
      StepModel(
        title: 'Content Generation',
        description: 'Generating content from paper summaries',
        icon: Icons.auto_awesome,
        color: Colors.amber,
        status: _getStepStatusFromLogs('Content Generation', provider.generationLogs),
      ),
      StepModel(
        title: 'Citation Formatting',
        description: 'Formatting citations and references',
        icon: Icons.format_quote,
        color: Colors.teal,
        status: _getStepStatusFromLogs('Citation Formatting', provider.generationLogs),
      ),
      StepModel(
        title: 'Final Document',
        description: 'View your completed document',
        icon: Icons.description,
        color: Colors.indigo,
        status: _determineFinalDocumentStatus(provider.generationLogs),
      ),
    ];
    
    return steps;
  }
  
  /// Determine step status from logs
  StepStatus _getStepStatusFromLogs(String stepTitle, List<ProcessLog>? logs) {
    if (logs == null || logs.isEmpty) {
      return stepTitle == 'Document Structure' 
          ? StepStatus.inProgress 
          : StepStatus.pending;
    }
    
    // Define steps list
    final steps = [
      'Document Structure',
      'PubMed Search',
      'Paper Selection',
      'Full Text Retrieval',
      'Content Generation',
      'Citation Formatting',
    ];
    
    // Filter logs for this step
    final stepLogs = logs.where((log) => log.source == stepTitle).toList();
    
    if (stepLogs.isEmpty) {
      // Check if previous steps are completed to determine if this is active
      final stepIndex = steps.indexOf(stepTitle);
      
      // Find the last completed step
      int lastCompletedIndex = -1;
      for (int i = 0; i < stepIndex; i++) {
        final prevStepLogs = logs.where((log) => log.source == steps[i]).toList();
        if (prevStepLogs.any(_isLogStepCompleted)) {
          lastCompletedIndex = i;
        }
      }
      
      return stepIndex == lastCompletedIndex + 1
          ? StepStatus.inProgress
          : stepIndex < lastCompletedIndex + 1
              ? StepStatus.completed
              : StepStatus.pending;
    }
    
    // Check if completed based on logs
    if (stepLogs.any(_isLogStepCompleted)) {
      return StepStatus.completed;
    }
    
    // Check if error based on logs
    if (stepLogs.any((log) => log.level.toLowerCase() == 'error')) {
      return StepStatus.error;
    }
    
    // Otherwise, in progress
    return StepStatus.inProgress;
  }
  
  /// Determine final document status
  StepStatus _determineFinalDocumentStatus(List<ProcessLog>? logs) {
    if (logs == null || logs.isEmpty) return StepStatus.pending;
    
    // Final document is completed if all other steps are completed
    bool allCompleted = true;
    final steps = [
      'Document Structure',
      'PubMed Search',
      'Paper Selection',
      'Full Text Retrieval',
      'Content Generation',
      'Citation Formatting',
    ];
    
    for (final step in steps) {
      if (_getStepStatusFromLogs(step, logs) != StepStatus.completed) {
        allCompleted = false;
        break;
      }
    }
    
    return allCompleted ? StepStatus.completed : StepStatus.pending;
  }
  
  /// Get the active step index from logs
  int _getActiveStepIndexFromLogs(List<ProcessLog> logs) {
    final steps = [
      'Document Structure',
      'PubMed Search',
      'Paper Selection',
      'Full Text Retrieval',
      'Content Generation',
      'Citation Formatting',
    ];
    
    // Find the first non-completed step
    for (int i = 0; i < steps.length; i++) {
      final stepLogs = logs.where((log) => log.source == steps[i]).toList();
      
      // If no logs for this step, check if previous steps are completed
      if (stepLogs.isEmpty) {
        bool allPreviousCompleted = true;
        for (int j = 0; j < i; j++) {
          final prevStepLogs = logs.where((log) => log.source == steps[j]).toList();
          if (!prevStepLogs.any(_isLogStepCompleted)) {
            allPreviousCompleted = false;
            break;
          }
        }
        if (allPreviousCompleted) {
          return i;
        }
      }
      
      // If step has logs but isn't completed, it's active
      if (!stepLogs.any(_isLogStepCompleted)) {
        return i;
      }
    }
    
    // If all completed, return the final document
    return steps.length;
  }
  
  /// Get active step index from our step models
  int _getActiveStepIndex(List<StepModel> steps) {
    // Find the first in-progress step
    for (int i = 0; i < steps.length; i++) {
      if (steps[i].status == StepStatus.inProgress) {
        return i;
      }
    }
    
    // If none are in progress, find first pending step
    for (int i = 0; i < steps.length; i++) {
      if (steps[i].status == StepStatus.pending) {
        return i > 0 ? i - 1 : 0;
      }
    }
    
    // If all completed, show the final one
    return steps.length - 1;
  }
  
  /// Check if all steps are completed
  bool _areAllStepsCompleted(List<StepModel> steps) {
    // Check all but the final document step
    for (int i = 0; i < steps.length - 1; i++) {
      if (steps[i].status != StepStatus.completed) {
        return false;
      }
    }
    return true;
  }
  
  /// Get text representation of status
  String _getStatusText(StepStatus status) {
    switch (status) {
      case StepStatus.pending:
        return 'Pending';
      case StepStatus.inProgress:
        return 'In Progress';
      case StepStatus.completed:
        return 'Completed';
      case StepStatus.error:
        return 'Error';
    }
  }
  
  /// Get icon for status
  IconData _getStatusIcon(StepStatus status) {
    switch (status) {
      case StepStatus.pending:
        return Icons.hourglass_empty;
      case StepStatus.inProgress:
        return Icons.autorenew;
      case StepStatus.completed:
        return Icons.check_circle;
      case StepStatus.error:
        return Icons.error;
    }
  }
  
  /// Get color for status
  Color _getStatusColor(StepStatus status) {
    switch (status) {
      case StepStatus.pending:
        return Colors.grey;
      case StepStatus.inProgress:
        return Colors.blue;
      case StepStatus.completed:
        return Colors.green;
      case StepStatus.error:
        return Colors.red;
    }
  }

  Widget _buildDocumentPreviewContent(BuildContext context, DocumentProvider provider) {
    final document = provider.currentDocument;
    if (document == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading document...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Document metadata
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (document.description.isNotEmpty)
                  Text(
                    document.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Created ${_formatDate(document.createdAt)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Document sections
          ...document.sections.map((section) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                section.content,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
            ],
          )),
          // References section
          if (document.references.isNotEmpty) ...[
            Text(
              'References',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...document.references.map((ref) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                ref.formattedReference,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )),
          ],
        ],
      ),
    );
  }
}

/// A shimmer effect placeholder widget
class ShimmerPlaceholder extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerPlaceholder({
    Key? key,
    required this.width,
    required this.height,
    this.borderRadius = 4,
  }) : super(key: key);

  @override
  State<ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<ShimmerPlaceholder> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.surface.withOpacity(0.5),
                Theme.of(context).colorScheme.surface,
              ],
              stops: [
                _animation.value - 0.2,
                _animation.value,
                _animation.value + 0.2,
              ],
            ),
          ),
        );
      },
    );
  }
}