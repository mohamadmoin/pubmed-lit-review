import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'dart:math' as math;
import 'step_item.dart';
import 'step_model.dart';
import 'process_content.dart';

/// A container widget that displays a step process with a seamless border connecting
/// the selected step and the main content area.
class StepProcessContainer extends StatefulWidget {
  /// List of steps to display
  final List<StepModel> steps;
  
  /// Initial selected step index
  final int initialStepIndex;
  
  /// Whether to display steps vertically (sidebar) or horizontally (topbar)
  final bool isVertical;
  
  /// Optional builder for custom step content
  final Widget Function(BuildContext, StepModel)? contentBuilder;
  
  /// Optional builder for step items
  final Widget Function(BuildContext, StepModel, bool, StepStatus)? stepBuilder;
  
  /// Called when a step is selected
  final Function(int)? onStepSelected;
  
  /// Header widget above the steps (e.g. title)
  final Widget? header;
  
  /// Footer widget below the steps (e.g. actions)
  final Widget? footer;
  
  /// Border color override (defaults to step color)
  final Color? borderColor;
  
  /// Border width for the connected border
  final double borderWidth;
  
  /// Animation duration for transitions
  final Duration animationDuration;

  const StepProcessContainer({
    Key? key,
    required this.steps,
    this.initialStepIndex = 0,
    this.isVertical = true,
    this.contentBuilder,
    this.stepBuilder,
    this.onStepSelected,
    this.header,
    this.footer,
    this.borderColor,
    this.borderWidth = 2.5,
    this.animationDuration = const Duration(milliseconds: 400),
  }) : super(key: key);

  @override
  State<StepProcessContainer> createState() => _StepProcessContainerState();
}

class _StepProcessContainerState extends State<StepProcessContainer> with SingleTickerProviderStateMixin {
  /// Currently selected step index
  late int _selectedStepIndex;
  
  /// Previous selected index (for animations)
  late int _previousStepIndex;
  
  /// Animation controller for the joined border
  late AnimationController _animationController;
  
  /// List of StepItem instances
  final List<StepItem> _stepItems = [];
  
  /// Process content instance
  ProcessContent? _processContent;
  
  /// Key for the content area
  final GlobalKey _contentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _selectedStepIndex = widget.initialStepIndex;
    _previousStepIndex = widget.initialStepIndex;
    
    // Animation controller for border transitions
    _animationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    
    // Initialize step items
    _initStepItems();
    
    // Run initial animation
    _animationController.forward();
  }
  
  /// Initialize the step items
  void _initStepItems() {
    _stepItems.clear();
    for (int i = 0; i < widget.steps.length; i++) {
      _stepItems.add(
        StepItem(
          step: widget.steps[i],
          isSelected: i == _selectedStepIndex,
          isVertical: widget.isVertical,
        ),
      );
    }
    
    // Initialize process content
    _processContent = ProcessContent(
      step: widget.steps[_selectedStepIndex],
      contentBuilder: widget.contentBuilder,
    );
  }
  
  @override
  void didUpdateWidget(StepProcessContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update step items if the steps list changes
    if (oldWidget.steps.length != widget.steps.length || 
        oldWidget.isVertical != widget.isVertical) {
      _initStepItems();
    }

    // Follow the active step as generation progresses
    if (widget.initialStepIndex != oldWidget.initialStepIndex &&
        widget.initialStepIndex != _selectedStepIndex &&
        widget.initialStepIndex >= 0 &&
        widget.initialStepIndex < widget.steps.length) {
      _previousStepIndex = _selectedStepIndex;
      _selectedStepIndex = widget.initialStepIndex;
      for (int i = 0; i < _stepItems.length; i++) {
        _stepItems[i] = StepItem(
          step: widget.steps[i],
          isSelected: i == _selectedStepIndex,
          isVertical: widget.isVertical,
        );
      }
      _processContent = ProcessContent(
        step: widget.steps[_selectedStepIndex],
        contentBuilder: widget.contentBuilder,
      );
    }
    
    // Update process content if step or builder changes
    if (oldWidget.contentBuilder != widget.contentBuilder) {
      _processContent = ProcessContent(
        step: widget.steps[_selectedStepIndex],
        contentBuilder: widget.contentBuilder,
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  /// Handle step selection
  void _selectStep(int index) {
    if (_selectedStepIndex != index && index >= 0 && index < widget.steps.length) {
      setState(() {
        _previousStepIndex = _selectedStepIndex;
        _selectedStepIndex = index;
        
        // Update selected state for step items
        for (int i = 0; i < _stepItems.length; i++) {
          _stepItems[i] = StepItem(
            step: widget.steps[i],
            isSelected: i == index,
            isVertical: widget.isVertical,
          );
        }
        
        // Update process content with new selected step
        _processContent = ProcessContent(
          step: widget.steps[index],
          contentBuilder: widget.contentBuilder,
        );
      });
      
      // Animate the border transition with a smoother curve
      _animationController.reset();
      _animationController.animateWith(
        SpringSimulation(
          const SpringDescription(
            mass: 1.0,
            stiffness: 100.0,
            damping: 15.0,
          ),
          0.0,  // from
          1.0,  // to
          0.0,  // velocity
        ),
      );
      
      // Notify parent if callback provided
      widget.onStepSelected?.call(index);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Make sure we have valid step items and process content
        if (_stepItems.isEmpty || _processContent == null) {
          _initStepItems();
        }
        
        return Stack(
          children: [
            // Base layout (row or column based on orientation)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(4.0), // Padding to give room for the border
                child: widget.isVertical 
                    ? _buildVerticalLayout(constraints) 
                    : _buildHorizontalLayout(constraints),
              ),
            ),
            
            // Overlay for the connected border
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, _) {
                  // Make sure we have content initialized
                  if (_stepItems.isEmpty || _processContent == null) {
                    return const SizedBox.shrink();
                  }
                  
                  // After the first layout pass, we can get positions
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    // This will force a rebuild to ensure we have proper positions
                    if (mounted) setState(() {});
                  });
                  
                  // Get current step item key
                  final currentStepItem = _stepItems[_selectedStepIndex];
                  final previousStepItem = _stepItems[_previousStepIndex];
                  
                  // Get rects for drawing joint border
                  final currentStepRect = _getWidgetRect(currentStepItem.getStepItemKey());
                  final previousStepRect = _getWidgetRect(previousStepItem.getStepItemKey());
                  final contentRect = _getWidgetRect(_processContent!.getContentPlaceholderKey());
                  
                  // Only draw if we have valid rects
                  if (currentStepRect == null || contentRect == null) {
                    return const SizedBox.shrink();
                  }
                  
                  return CustomPaint(
                    painter: _JointBorderPainter(
                      prevStepRect: previousStepRect ?? currentStepRect,
                      stepRect: currentStepRect,
                      contentRect: contentRect,
                      stepColor: widget.borderColor ?? widget.steps[_selectedStepIndex].color,
                      borderWidth: widget.borderWidth,
                      animationValue: _animationController.value,
                      isVertical: widget.isVertical,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
  
  /// Build vertical layout (sidebar + content)
  Widget _buildVerticalLayout(BoxConstraints constraints) {
    // Sidebar width - 25% of total width or at most 300px
    final sidebarWidth = math.min(constraints.maxWidth * 0.25, 300.0);
    
    return Row(
      children: [
        // Sidebar with steps
        Container(
          width: sidebarWidth,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Optional header
              if (widget.header != null)
                widget.header!,
                
              // Steps list
              Expanded(
                child: ListView.builder(
                  itemCount: widget.steps.length,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  itemBuilder: (context, index) {
                    // Use custom builder or our step item
                    return GestureDetector(
                      onTap: () => _selectStep(index),
                      child: widget.stepBuilder != null
                          ? widget.stepBuilder!(
                              context, 
                              widget.steps[index], 
                              index == _selectedStepIndex, 
                              widget.steps[index].status
                            )
                          : _stepItems[index],
                    );
                  },
                ),
              ),
              
              // Optional footer
              if (widget.footer != null)
                widget.footer!,
            ],
          ),
        ),
        
        // Small gap between sidebar and content
        const SizedBox(width: 2),
        
        // Main content area
        Expanded(
          child: Container(
            key: _contentKey,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
            ),
            child: _processContent!,
          ),
        ),
      ],
    );
  }
  
  /// Build horizontal layout (topbar + content)
  Widget _buildHorizontalLayout(BoxConstraints constraints) {
    // Topbar height - fixed at 120
    const topbarHeight = 120.0;
    
    return Column(
      children: [
        // Topbar with steps
        Container(
          height: topbarHeight,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Optional header
              if (widget.header != null)
                widget.header!,
                
              // Steps list (horizontal)
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.steps.length,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  itemBuilder: (context, index) {
                    // Use custom builder or our step item
                    return GestureDetector(
                      onTap: () => _selectStep(index),
                      child: widget.stepBuilder != null
                          ? widget.stepBuilder!(
                              context, 
                              widget.steps[index], 
                              index == _selectedStepIndex, 
                              widget.steps[index].status
                            )
                          : _stepItems[index],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        
        // Small gap between topbar and content
        const SizedBox(height: 2),
        
        // Main content area
        Expanded(
          child: Container(
            key: _contentKey,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
            ),
            child: _processContent!,
          ),
        ),
        
        // Optional footer
        if (widget.footer != null)
          widget.footer!,
      ],
    );
  }
  
  /// Get the rect of a widget from its GlobalKey
  Rect? _getWidgetRect(GlobalKey key) {
    final RenderObject? renderObject = key.currentContext?.findRenderObject();
    if (renderObject != null && renderObject is RenderBox && renderObject.hasSize) {
      final position = renderObject.localToGlobal(Offset.zero);
      return position & renderObject.size;
    }
    return null;
  }
}

/// Custom painter for drawing the joint border between step item and content
class _JointBorderPainter extends CustomPainter {
  final Rect prevStepRect;
  final Rect stepRect;
  final Rect contentRect;
  final Color stepColor;
  final double borderWidth;
  final double animationValue;
  final bool isVertical;
  
  _JointBorderPainter({
    required this.prevStepRect,
    required this.stepRect,
    required this.contentRect,
    required this.stepColor,
    required this.borderWidth,
    required this.animationValue,
    required this.isVertical,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Calculate interpolated step rect for animation
    final interpolatedRect = Rect.lerp(prevStepRect, stepRect, animationValue)!;
    
    // Create a path for the joined border
    final path = Path();
    
    if (isVertical) {
      // For vertical layout (sidebar + main content)
      
      // Get the corner radius for both containers
      final stepRadius = 8.0;
      final contentRadius = 16.0;
      
      // Create RRects for both containers
      final stepRRect = RRect.fromRectAndCorners(
        interpolatedRect,
        topLeft: Radius.circular(stepRadius),
        topRight: Radius.circular(stepRadius),
        bottomLeft: Radius.circular(stepRadius),
        bottomRight: Radius.zero, // No corner where it connects to content
      );
      
      final contentRRect = RRect.fromRectAndCorners(
        contentRect,
        topLeft: Radius.zero, // No corner where it connects to step
        topRight: Radius.circular(contentRadius),
        bottomRight: Radius.circular(contentRadius),
        bottomLeft: Radius.circular(contentRadius),
      );
      
      // Determine connection points
      final stepCenterY = interpolatedRect.center.dy;
      final stepRight = interpolatedRect.right;
      final contentLeft = contentRect.left;
      
      // Draw step container border (except the right side)
      path.moveTo(interpolatedRect.left, interpolatedRect.top + stepRadius);
      path.arcToPoint(
        Offset(interpolatedRect.left + stepRadius, interpolatedRect.top),
        radius: Radius.circular(stepRadius),
      );
      path.lineTo(interpolatedRect.right - stepRadius, interpolatedRect.top);
      path.arcToPoint(
        Offset(interpolatedRect.right, interpolatedRect.top + stepRadius),
        radius: Radius.circular(stepRadius),
      );
      
      // Now instead of completing the step border, we'll connect to the content
      path.lineTo(stepRight, stepCenterY - 10); // Stop short of center
      
      // Connect to content with a slight curve
      path.quadraticBezierTo(
        (stepRight + contentLeft) / 2, stepCenterY, // Control point
        contentLeft, stepCenterY + 10, // End point
      );
      
      // Draw the bottom part of content border
      path.lineTo(contentLeft, contentRect.bottom - contentRadius);
      path.arcToPoint(
        Offset(contentLeft + contentRadius, contentRect.bottom),
        radius: Radius.circular(contentRadius),
      );
      path.lineTo(contentRect.right - contentRadius, contentRect.bottom);
      path.arcToPoint(
        Offset(contentRect.right, contentRect.bottom - contentRadius),
        radius: Radius.circular(contentRadius),
      );
      
      // Right edge of content
      path.lineTo(contentRect.right, contentRect.top + contentRadius);
      path.arcToPoint(
        Offset(contentRect.right - contentRadius, contentRect.top),
        radius: Radius.circular(contentRadius),
      );
      
      // Top edge of content
      path.lineTo(contentLeft, contentRect.top);
      
      // Connect back to step
      path.lineTo(contentLeft, stepCenterY - 10);
      path.quadraticBezierTo(
        (stepRight + contentLeft) / 2, stepCenterY, // Control point
        stepRight, stepCenterY + 10, // End point
      );
      
      // Complete the bottom part of step border
      path.lineTo(stepRight, interpolatedRect.bottom - stepRadius);
      path.arcToPoint(
        Offset(stepRight - stepRadius, interpolatedRect.bottom),
        radius: Radius.circular(stepRadius),
      );
      path.lineTo(interpolatedRect.left + stepRadius, interpolatedRect.bottom);
      path.arcToPoint(
        Offset(interpolatedRect.left, interpolatedRect.bottom - stepRadius),
        radius: Radius.circular(stepRadius),
      );
      
      // Complete the path
      path.lineTo(interpolatedRect.left, interpolatedRect.top + stepRadius);
      
    } else {
      // For horizontal layout (topbar + main content)
      
      // Get the corner radius for both containers
      final stepRadius = 8.0;
      final contentRadius = 16.0;
      
      // Create RRects for both containers
      final stepRRect = RRect.fromRectAndCorners(
        interpolatedRect,
        topLeft: Radius.circular(stepRadius),
        topRight: Radius.circular(stepRadius),
        bottomLeft: Radius.circular(stepRadius),
        bottomRight: Radius.circular(stepRadius),
      );
      
      final contentRRect = RRect.fromRectAndCorners(
        contentRect,
        topLeft: Radius.circular(contentRadius),
        topRight: Radius.circular(contentRadius),
        bottomRight: Radius.circular(contentRadius),
        bottomLeft: Radius.circular(contentRadius),
      );
      
      // Determine connection points
      final stepCenterX = interpolatedRect.center.dx;
      final stepBottom = interpolatedRect.bottom;
      final contentTop = contentRect.top;
      
      // Draw step container border (except the bottom)
      path.moveTo(interpolatedRect.left + stepRadius, interpolatedRect.top);
      path.lineTo(interpolatedRect.right - stepRadius, interpolatedRect.top);
      path.arcToPoint(
        Offset(interpolatedRect.right, interpolatedRect.top + stepRadius),
        radius: Radius.circular(stepRadius),
      );
      path.lineTo(interpolatedRect.right, interpolatedRect.bottom - stepRadius);
      path.arcToPoint(
        Offset(interpolatedRect.right - stepRadius, interpolatedRect.bottom),
        radius: Radius.circular(stepRadius),
      );
      
      // Bottom edge except the connection part
      path.lineTo(stepCenterX + 10, stepBottom);
      
      // Connect to content with a curved line
      path.quadraticBezierTo(
        stepCenterX, (stepBottom + contentTop) / 2, // Control point
        stepCenterX - 10, contentTop, // End point
      );
      
      // Draw content border
      path.lineTo(contentRect.left + contentRadius, contentTop);
      path.arcToPoint(
        Offset(contentRect.left, contentTop + contentRadius),
        radius: Radius.circular(contentRadius),
      );
      path.lineTo(contentRect.left, contentRect.bottom - contentRadius);
      path.arcToPoint(
        Offset(contentRect.left + contentRadius, contentRect.bottom),
        radius: Radius.circular(contentRadius),
      );
      path.lineTo(contentRect.right - contentRadius, contentRect.bottom);
      path.arcToPoint(
        Offset(contentRect.right, contentRect.bottom - contentRadius),
        radius: Radius.circular(contentRadius),
      );
      path.lineTo(contentRect.right, contentTop + contentRadius);
      path.arcToPoint(
        Offset(contentRect.right - contentRadius, contentTop),
        radius: Radius.circular(contentRadius),
      );
      
      // Top edge of content to connection point
      path.lineTo(stepCenterX + 10, contentTop);
      
      // Connect back to step
      path.quadraticBezierTo(
        stepCenterX, (stepBottom + contentTop) / 2, // Control point
        stepCenterX - 10, stepBottom, // End point
      );
      
      // Complete step border
      path.lineTo(interpolatedRect.left + stepRadius, stepBottom);
      path.arcToPoint(
        Offset(interpolatedRect.left, interpolatedRect.bottom - stepRadius),
        radius: Radius.circular(stepRadius),
      );
      path.lineTo(interpolatedRect.left, interpolatedRect.top + stepRadius);
      path.arcToPoint(
        Offset(interpolatedRect.left + stepRadius, interpolatedRect.top),
        radius: Radius.circular(stepRadius),
      );
    }
    
    // Create the gradient paint
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..shader = LinearGradient(
        colors: [
          stepColor.withOpacity(0.9),
          stepColor.withOpacity(0.7),
          stepColor.withOpacity(0.5),
          stepColor.withOpacity(0.3),
        ],
        begin: isVertical 
            ? Alignment.centerLeft 
            : Alignment.topCenter,
        end: isVertical 
            ? Alignment.centerRight 
            : Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    // Draw the path
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant _JointBorderPainter oldDelegate) {
    return oldDelegate.prevStepRect != prevStepRect ||
           oldDelegate.stepRect != stepRect ||
           oldDelegate.contentRect != contentRect ||
           oldDelegate.stepColor != stepColor ||
           oldDelegate.borderWidth != borderWidth ||
           oldDelegate.animationValue != animationValue ||
           oldDelegate.isVertical != isVertical;
  }
} 