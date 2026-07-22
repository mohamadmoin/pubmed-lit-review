import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'step_model.dart';

/// Widget to represent a single step in the process
class StepItem extends StatelessWidget {
  /// The step data to display
  final StepModel step;
  
  /// Whether this step is currently selected
  final bool isSelected;
  
  /// Whether this step is displayed in vertical layout
  final bool isVertical;
  
  /// Key for the step item container to allow border joining
  final GlobalKey stepItemKey = GlobalKey();
  
  StepItem({
    Key? key,
    required this.step,
    required this.isSelected,
    required this.isVertical,
  }) : super(key: key);

  /// Get the key for the step item container
  GlobalKey getStepItemKey() => stepItemKey;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Colors based on status
    Color iconBackgroundColor;
    Color iconColor;
    Color textColor;
    
    switch (step.status) {
      case StepStatus.pending:
        iconBackgroundColor = Theme.of(context).colorScheme.surfaceVariant;
        iconColor = Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5);
        textColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.5);
        break;
      case StepStatus.inProgress:
        iconBackgroundColor = step.color.withOpacity(0.2);
        iconColor = step.color;
        textColor = Theme.of(context).colorScheme.onSurface;
        break;
      case StepStatus.completed:
        iconBackgroundColor = isDarkMode 
            ? step.color.withOpacity(0.3) 
            : step.color.withOpacity(0.2);
        iconColor = isDarkMode ? Colors.white : step.color;
        textColor = Theme.of(context).colorScheme.onSurface;
        break;
      case StepStatus.error:
        iconBackgroundColor = Theme.of(context).colorScheme.error.withOpacity(0.2);
        iconColor = Theme.of(context).colorScheme.error;
        textColor = Theme.of(context).colorScheme.error;
        break;
    }
    
    // Container decoration for the step
    final containerDecoration = BoxDecoration(
      color: isSelected ? step.color.withOpacity(0.1) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      border: isSelected 
          ? Border.all(color: step.color.withOpacity(0.5), width: 1.5) 
          : null,
    );
    
    // Vertical or horizontal layout
    if (isVertical) {
      // Desktop-like view
      return Container(
        key: stepItemKey,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: containerDecoration,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              // Icon with animations
              _buildAnimatedIcon(iconBackgroundColor, iconColor, context),
              
              const SizedBox(width: 12),
              
              // Title and description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: textColor,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (isSelected)
                      Text(
                        step.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: textColor.withOpacity(0.8),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Mobile-like view (horizontal)
      return Container(
        key: stepItemKey,
        width: 100,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: containerDecoration,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with animations
              _buildAnimatedIcon(iconBackgroundColor, iconColor, context),
              
              const SizedBox(height: 8),
              
              // Title (description hidden in horizontal mode)
              Text(
                step.title,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: textColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }
  }
  
  Widget _buildAnimatedIcon(Color backgroundColor, Color iconColor, BuildContext context) {
    Widget iconWidget;
    
    switch (step.status) {
      case StepStatus.pending:
        iconWidget = Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            step.icon,
            color: iconColor,
            size: 18,
          ),
        );
        break;
        
      case StepStatus.inProgress:
        iconWidget = Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            border: isSelected 
                ? Border.all(color: step.color, width: 2) 
                : null,
          ),
          child: Icon(
            step.icon,
            color: iconColor,
            size: 18,
          ),
        )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(duration: 1.5.seconds, color: step.color.withOpacity(0.8))
        .animate()
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.1, 1.1),
          duration: 0.8.seconds,
        ).then()
        .scale(
          begin: const Offset(1.1, 1.1),
          end: const Offset(1, 1),
          duration: 0.8.seconds,
        );
        break;
        
      case StepStatus.completed:
        iconWidget = Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            border: isSelected 
                ? Border.all(color: step.color, width: 2) 
                : null,
          ),
          child: Icon(
            Icons.check_circle,
            color: iconColor,
            size: 18,
          ),
        )
        .animate()
        .scale(
          begin: const Offset(0.5, 0.5),
          end: const Offset(1, 1),
          curve: Curves.elasticOut,
          duration: 0.8.seconds,
        );
        break;
        
      case StepStatus.error:
        iconWidget = Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            border: isSelected
                ? Border.all(color: Theme.of(context).colorScheme.error, width: 2)
                : null,
          ),
          child: Icon(
            Icons.error,
            color: iconColor,
            size: 18,
          ),
        ).animate().shake(duration: 0.5.seconds);
        break;
    }
    
    return iconWidget;
  }
} 