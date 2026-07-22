import 'package:flutter/material.dart';

/// The status of a step in the process
enum StepStatus {
  /// Step is pending
  pending,
  
  /// Step is currently in progress
  inProgress,
  
  /// Step has been completed
  completed,
  
  /// Step encountered an error
  error,
}

/// Model class for a step in the process.
class StepModel {
  /// Title of the step
  final String title;
  
  /// Longer description of the step
  final String description;
  
  /// Icon to display for the step
  final IconData icon;
  
  /// Primary color for the step
  final Color color;
  
  /// Current status of the step
  final StepStatus status;
  
  /// Additional data for this step (optional)
  final Map<String, dynamic>? data;
  
  /// Constructor for creating a step
  const StepModel({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.status = StepStatus.pending,
    this.data,
  });
  
  /// Create a copy of this step with updated fields
  StepModel copyWith({
    String? title,
    String? description,
    IconData? icon,
    Color? color,
    StepStatus? status,
    Map<String, dynamic>? data,
  }) {
    return StepModel(
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      status: status ?? this.status,
      data: data ?? this.data,
    );
  }
} 