import 'dart:async';
import 'package:flutter/foundation.dart';

import '../utils/parse_timestamp.dart';
import 'document_service.dart';

/// Status of a document generation request
enum GenerationStatus {
  /// Request is waiting to be processed
  pending,
  
  /// Request is being processed
  processing,
  
  /// Request has been completed successfully
  completed,
  
  /// Request has failed
  failed,
  
  /// Request status is unknown
  unknown
}

/// Status update for document generation
class GenerationStatusUpdate {
  /// Current status
  final GenerationStatus status;
  
  /// Document ID if completed
  final String? documentId;
  
  /// Error message if failed
  final String? errorMessage;
  
  /// Status message
  final String? message;
  
  /// List of process logs
  final List<ProcessLog>? logs;
  
  /// Total number of steps
  final int? totalSteps;
  
  /// Current step index
  final int? currentStep;
  
  /// Create a generation status update
  const GenerationStatusUpdate({
    required this.status,
    this.documentId,
    this.errorMessage,
    this.message,
    this.logs,
    this.totalSteps,
    this.currentStep,
  });
  
  /// Check if generation is complete
  bool get isComplete => status == GenerationStatus.completed;
  
  /// Check if generation failed
  bool get isFailed => status == GenerationStatus.failed;
  
  /// Check if generation is still in progress
  bool get isInProgress => 
      status == GenerationStatus.pending || 
      status == GenerationStatus.processing;
  
  @override
  String toString() => 'GenerationStatusUpdate(status: $status, '
      'documentId: $documentId, errorMessage: $errorMessage, message: $message, '
      'totalSteps: $totalSteps, currentStep: $currentStep)';
}

/// Process log entry from the backend
class ProcessLog {
  /// Unique ID
  final String id;
  
  /// Timestamp of the log
  final DateTime timestamp;
  
  /// Log message
  final String message;
  
  /// Log level
  final String level;
  
  /// Source of the log
  final String source;

  /// Create a process log entry
  const ProcessLog({
    required this.id,
    required this.timestamp,
    required this.message,
    required this.level,
    required this.source,
  });

  /// Create from JSON
  factory ProcessLog.fromJson(Map<String, dynamic> json) {
    return ProcessLog(
      id: json['id'] ?? '',
      timestamp: parseFlexibleTimestamp(json['timestamp']),
      message: json['message'] ?? '',
      level: json['level'] ?? '',
      source: json['source'] ?? '',
    );
  }
}

/// Callback for generation status updates
typedef GenerationStatusCallback = void Function(GenerationStatusUpdate update);

/// Service that tracks document generation progress
class DocumentGenerationTracker {
  /// Document service for API calls
  final DocumentService _documentService;
  
  /// ID of the document being generated
  final String documentId;
  
  /// How often to poll the server for status updates
  final Duration pollingInterval;
  
  /// Maximum number of poll attempts (-1 for unlimited)
  final int maxAttempts;
  
  /// Callback for status updates
  final GenerationStatusCallback onStatusUpdate;
  
  /// Timer for polling
  Timer? _pollingTimer;
  
  /// Number of polling attempts
  int _attempts = 0;
  
  /// Latest known status
  GenerationStatus _lastStatus = GenerationStatus.unknown;
  
  /// Latest logs
  List<ProcessLog> _logs = [];
  
  /// Stream controller for status updates
  final StreamController<GenerationStatusUpdate> _statusController;
  
  /// Stream of status updates
  Stream<GenerationStatusUpdate> get statusUpdates => _statusController.stream;
  
  /// Create a document generation tracker
  DocumentGenerationTracker({
    required this.documentId,
    required this.onStatusUpdate,
    DocumentService? documentService,
    this.pollingInterval = const Duration(seconds: 3),
    this.maxAttempts = -1,
  }) : _documentService = documentService ?? DocumentService(),
       _statusController = StreamController<GenerationStatusUpdate>.broadcast();
  
  /// Start tracking the generation status
  void startTracking() {
    if (_pollingTimer != null) {
      return; // Already tracking
    }
    
    _attempts = 0;
    _checkStatus();
    
    _pollingTimer = Timer.periodic(pollingInterval, (_) {
      _checkStatus();
    });
    
    if (kDebugMode) {
      print('Started tracking document generation for $documentId');
    }
  }
  
  /// Stop tracking the generation status
  void stopTracking() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    
    if (kDebugMode) {
      print('Stopped tracking document generation for $documentId');
    }
  }
  
  /// Manually check the current status
  Future<void> checkNow() async {
    await _checkStatus();
  }
  
  /// Check the status of the generation request
  Future<void> _checkStatus() async {
    _attempts++;
    
    // Check if we've exceeded the maximum number of attempts
    if (maxAttempts > 0 && _attempts > maxAttempts) {
      final update = GenerationStatusUpdate(
        status: GenerationStatus.unknown,
        errorMessage: 'Maximum polling attempts exceeded',
      );
      _statusController.add(update);
      onStatusUpdate(update);
      stopTracking();
      return;
    }
    
    try {
      // Use the process_logs endpoint to get status
      final processLogsResponse = await _documentService.getDocumentProcessLogs(documentId);
      
      String statusString = processLogsResponse['status']?.toString() ?? 'unknown';
      GenerationStatus generationStatus = _parseStatus(statusString);
      
      // Parse logs
      List<ProcessLog> logs = [];
      if (processLogsResponse['logs'] != null) {
        logs = (processLogsResponse['logs'] as List)
            .map((log) => ProcessLog.fromJson(log))
            .toList();
      }
      
      // Parse total steps and current step
      int? totalSteps;
      int? currentStep;
      
      // Safely parse total_steps
      if (processLogsResponse['total_steps'] != null) {
        totalSteps = processLogsResponse['total_steps'] is int 
            ? processLogsResponse['total_steps'] 
            : int.tryParse(processLogsResponse['total_steps'].toString());
      }
      
      // Safely parse current_step
      if (processLogsResponse['current_step'] != null) {
        currentStep = processLogsResponse['current_step'] is int 
            ? processLogsResponse['current_step'] 
            : int.tryParse(processLogsResponse['current_step'].toString());
      }
      
      // Only notify if status has changed or logs have been updated
      if (generationStatus != _lastStatus || logs.length != _logs.length) {
        _lastStatus = generationStatus;
        _logs = logs;
        
        final update = GenerationStatusUpdate(
          status: generationStatus,
          documentId: documentId,
          errorMessage: null,
          message: _getStatusMessage(generationStatus, logs),
          logs: logs,
          totalSteps: totalSteps,
          currentStep: currentStep,
        );
        
        _statusController.add(update);
        onStatusUpdate(update);
        
        // Stop tracking if complete or failed
        if (generationStatus == GenerationStatus.completed || 
            generationStatus == GenerationStatus.failed) {
          stopTracking();
        }
      }
    } catch (e) {
      // Don't propagate 404 errors in the first few attempts
      // as the document might still be being created
      if (_attempts < 3 && e.toString().contains('Document not found')) {
        return;
      }
      
      if (kDebugMode) {
        print('Error checking generation status: $e');
      }
      
      // Don't stop tracking on error, try again next interval
    }
  }
  
  /// Parse the status string from the API into a GenerationStatus enum
  GenerationStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return GenerationStatus.pending;
      case 'processing':
        return GenerationStatus.processing;
      case 'completed':
        return GenerationStatus.completed;
      case 'failed':
        return GenerationStatus.failed;
      default:
        return GenerationStatus.unknown;
    }
  }
  
  /// Get a user-friendly message for the current status
  String _getStatusMessage(GenerationStatus status, List<ProcessLog> logs) {
    // Find the most recent log message if available
    String? latestMessage;
    if (logs.isNotEmpty) {
      logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      latestMessage = logs.first.message;
    }
    
    switch (status) {
      case GenerationStatus.pending:
        return latestMessage ?? 'Your document is in the queue and will be processed soon...';
      case GenerationStatus.processing:
        return latestMessage ?? 'Your document is being generated. This may take several minutes...';
      case GenerationStatus.completed:
        return 'Your document has been generated successfully!';
      case GenerationStatus.failed:
        return 'Document generation failed: ${latestMessage ?? 'Unknown error'}';
      case GenerationStatus.unknown:
        return 'The status of your document generation is unknown';
    }
  }
  
  /// Dispose resources
  void dispose() {
    stopTracking();
    _statusController.close();
  }
} 