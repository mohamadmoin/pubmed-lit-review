import 'package:flutter/material.dart';
import 'step_model.dart';

/// Widget that displays the content for a selected step
class ProcessContent extends StatelessWidget {
  /// The currently selected step
  final StepModel step;
  
  /// Optional custom builder for the content
  final Widget Function(BuildContext, StepModel)? contentBuilder;
  
  /// Key for the content placeholder to allow border joining
  final GlobalKey contentPlaceholderKey = GlobalKey();
  
  ProcessContent({
    Key? key,
    required this.step,
    this.contentBuilder,
  }) : super(key: key);

  /// Get the key for the content placeholder
  GlobalKey getContentPlaceholderKey() => contentPlaceholderKey;

  @override
  Widget build(BuildContext context) {
    // Use custom builder if provided
    if (contentBuilder != null) {
      return contentBuilder!(context, step);
    }
    
    // Default content view
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section with icon and title
          Row(
            children: [
              // Step icon in a container
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
              
              // Step title and description
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
                    const SizedBox(height: 4),
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
          
          // Status indicator
          _buildStatusIndicator(context),
          
          const SizedBox(height: 32),
          
          // Placeholder content or actual content
          Expanded(
            child: _buildPlaceholderContent(context),
          ),
        ],
      ),
    );
  }
  
  /// Build a status indicator for the step
  Widget _buildStatusIndicator(BuildContext context) {
    // Status text and colors
    String statusText;
    Color statusColor;
    IconData statusIcon;
    
    switch (step.status) {
      case StepStatus.pending:
        statusText = 'Pending';
        statusColor = Colors.grey;
        statusIcon = Icons.hourglass_empty;
        break;
      case StepStatus.inProgress:
        statusText = 'In Progress';
        statusColor = Colors.blue;
        statusIcon = Icons.autorenew;
        break;
      case StepStatus.completed:
        statusText = 'Completed';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case StepStatus.error:
        statusText = 'Error';
        statusColor = Theme.of(context).colorScheme.error;
        statusIcon = Icons.error;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusIcon,
            color: statusColor,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Build placeholder content for the step
  Widget _buildPlaceholderContent(BuildContext context) {
    return Container(
      key: contentPlaceholderKey,
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
            'Details for ${step.title}',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'This area will show ${step.title.toLowerCase()} details and interactions.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
} 