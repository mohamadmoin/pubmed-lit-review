import 'package:flutter/material.dart';
import 'package:glass_kit/glass_kit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/models/document_model.dart';
import '../../../core/providers/document_provider.dart';
import '../../../core/theme/colors.dart';

class DocumentProcessView extends StatelessWidget {
  final AIGeneratedDocument document;

  const DocumentProcessView({
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
          child: _buildProcessFlow(context),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 2,
          child: _buildProcessDetails(context),
        ),
      ],
    );
  }

  Widget _buildProcessFlow(BuildContext context) {
    final provider = Provider.of<DocumentProvider>(context);
    final logs = document.processLogs;
    
    if (logs.isEmpty) {
      return _buildEmptyState();
    }
    
    // Group logs by step, with null safety
    final stepToLogs = <String, List<ProcessLogEntry>>{};
    for (final log in logs) {
      final message = log.message?.contains(':') == true 
          ? log.message!.substring(0, log.message!.indexOf(':'))
          : log.message ?? 'Unknown';
      stepToLogs.putIfAbsent(message, () => []).add(log);
    }
    
    // Sort steps by earliest timestamp with null safety
    final steps = stepToLogs.keys.toList()
      ..sort((a, b) {
        final aTime = stepToLogs[a]?.map((l) => l.timestamp).reduce(
              (value, element) => value.isBefore(element) ? value : element,
            );
        final bTime = stepToLogs[b]?.map((l) => l.timestamp).reduce(
              (value, element) => value.isBefore(element) ? value : element,
            );
            
        if (aTime == null || bTime == null) return 0;
        return aTime.compareTo(bTime);
      });

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
            child: Text(
              'Process Flow',
              style: GoogleFonts.poppins(
                color: AppColors.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Divider(height: 1, color: Colors.white30),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: steps.length,
              itemBuilder: (context, index) {
                final step = steps[index];
                final stepLogs = stepToLogs[step] ?? [];
                final isCompleted = stepLogs.any((log) => log.level?.toLowerCase() == 'completed');
                final isError = stepLogs.any((log) => log.level?.toLowerCase() == 'failed');
                
                return _buildProcessFlowItem(
                  context,
                  step: step,
                  isCompleted: isCompleted,
                  isError: isError,
                  isSelected: provider.activeTab == 'process' && step == (provider.selectedPaperId ?? ''),
                  isLast: index == steps.length - 1,
                  onTap: () => provider.selectPaper(step),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
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
      child: Center(
        child: Text(
          'No process logs available',
          style: GoogleFonts.poppins(
            color: AppColors.secondaryText,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildProcessFlowItem(
    BuildContext context, {
    required String step,
    required bool isCompleted,
    required bool isError,
    required bool isSelected,
    required bool isLast,
    required VoidCallback onTap,
  }) {
    final Color statusColor = isError
        ? Colors.red.shade400
        : isCompleted
            ? AppColors.accentBlue
            : AppColors.tertiaryText;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isSelected ? AppColors.accentBlue.withOpacity(0.1) : Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: statusColor,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      isError
                          ? Icons.error_outline
                          : isCompleted
                              ? Icons.check
                              : Icons.hourglass_empty,
                      size: 14,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _formatStepName(step),
                    style: GoogleFonts.inter(
                      color: AppColors.primaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isError)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Failed',
                      style: GoogleFonts.inter(
                        color: Colors.red.shade400,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (isCompleted && !isError)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accentBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Completed',
                      style: GoogleFonts.inter(
                        color: AppColors.accentBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            if (!isLast)
              Container(
                margin: const EdgeInsets.only(left: 12),
                height: 20,
                width: 1,
                color: statusColor.withOpacity(0.5),
              ),
          ],
        ),
      ),
    );
  }

  String _formatStepName(String step) {
    final words = step.split(' ');
    for (var i = 0; i < words.length; i++) {
      if (words[i].isNotEmpty) {
        words[i] = words[i][0].toUpperCase() + words[i].substring(1);
      }
    }
    return words.join(' ');
  }

  Widget _buildProcessDetails(BuildContext context) {
    final provider = Provider.of<DocumentProvider>(context);
    final selectedStep = provider.selectedPaperId;

    if (selectedStep == null) {
      return _buildProcessOverview();
    }




    // Find logs for this step with null safety
    final stepLogs = document.processLogs
        .where((log) => (log.message?.contains(':') == true 
          ? log.message!.substring(0, log.message!.indexOf(':'))
          : log.message ?? 'Unknown') == selectedStep)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (stepLogs.isEmpty) {
      return _buildProcessOverview();
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
              '${_formatStepName(selectedStep)} Step',
              style: GoogleFonts.poppins(
                color: AppColors.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _buildStepInfoCard(stepLogs),
            const SizedBox(height: 24),
            Text(
              'Process Logs',
              style: GoogleFonts.poppins(
                color: AppColors.primaryText,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...stepLogs.map((log) => _buildLogItem(log)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepInfoCard(List<ProcessLogEntry> logs) {
    final startTime = logs.first.timestamp;
    final endTime = logs.last.timestamp;
    final duration = endTime.difference(startTime);
    final isCompleted = logs.any((log) => log.level == 'Completed');
    final isError = logs.any((log) => log.level == 'Failed');

    final statusText = isError ? 'Failed' : isCompleted ? 'Completed' : 'In Progress';
    final statusColor = isError
        ? Colors.red.shade400
        : isCompleted
            ? AppColors.accentBlue
            : AppColors.tertiaryText;

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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isError
                      ? Icons.error_outline
                      : isCompleted
                          ? Icons.check_circle_outline
                          : Icons.hourglass_empty,
                  size: 24,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                statusText,
                style: GoogleFonts.poppins(
                  color: statusColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Colors.white30),
          const SizedBox(height: 16),
          _buildInfoRow('Start Time', DateFormat('MMM d, yyyy HH:mm:ss').format(startTime)),
          const SizedBox(height: 8),
          _buildInfoRow('End Time', DateFormat('MMM d, yyyy HH:mm:ss').format(endTime)),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Duration',
            '${duration.inMinutes} min ${duration.inSeconds % 60} sec',
          ),
          const SizedBox(height: 8),
          _buildInfoRow('Event Count', '${logs.length}'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
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

  Widget _buildLogItem(ProcessLogEntry log) {
    final statusColor = log.level == 'Failed'
        ? Colors.red.shade400
        : log.level == 'Completed'
            ? AppColors.accentBlue
            : AppColors.tertiaryText;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  log.level ?? "Unknown Status",
                  style: GoogleFonts.inter(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('HH:mm:ss').format(log.timestamp),
                style: GoogleFonts.inter(
                  color: AppColors.tertiaryText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            log.source ?? "No Source",
            style: GoogleFonts.inter(
              color: AppColors.primaryText,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessOverview() {
    final logs = document.processLogs;
    
    // Calculate process stats
    final startTime = logs.map((l) => l.timestamp).reduce(
          (value, element) => value.isBefore(element) ? value : element,
        );
    final endTime = logs.map((l) => l.timestamp).reduce(
          (value, element) => value.isAfter(element) ? value : element,
        );
    final totalDuration = endTime.difference(startTime);
    
    // Count steps
    final steps = <String>{};
    for (final log in logs) {
      steps.add(log.message?? "No Step");
    }
    
    // Check if there are any errors
    final hasErrors = logs.any((log) => log.level == 'Failed');

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
              'Process Overview',
              style: GoogleFonts.poppins(
                color: AppColors.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select a process step from the left panel to view detailed information',
              style: GoogleFonts.inter(
                color: AppColors.secondaryText,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            _buildProcessSummaryCard(
              steps: steps.length,
              totalDuration: totalDuration,
              startTime: startTime,
              endTime: endTime,
              hasErrors: hasErrors,
            ),
            const SizedBox(height: 24),
            _buildProcessTimeline(),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessSummaryCard({
    required int steps,
    required Duration totalDuration,
    required DateTime startTime,
    required DateTime endTime,
    required bool hasErrors,
  }) {
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
            'Process Summary',
            style: GoogleFonts.poppins(
              color: AppColors.accentBlue,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Total Steps', steps.toString()),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Total Duration',
            '${totalDuration.inMinutes} min ${totalDuration.inSeconds % 60} sec',
          ),
          const SizedBox(height: 8),
          _buildInfoRow('Started At', DateFormat('MMM d, yyyy HH:mm:ss').format(startTime)),
          const SizedBox(height: 8),
          _buildInfoRow('Completed At', DateFormat('MMM d, yyyy HH:mm:ss').format(endTime)),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Status',
            hasErrors ? 'Completed with Errors' : 'Completed Successfully',
          ),
        ],
      ),
    );
  }

  Widget _buildProcessTimeline() {
    final logs = document.processLogs;
    
    if (logs.isEmpty) {
      return Container(); // Or return an empty state widget
    }
    
    // Group logs by step with null safety
    final stepToLogs = <String, List<ProcessLogEntry>>{};
    for (final log in logs) {
      final message = log.message ?? 'Unknown';
      stepToLogs.putIfAbsent(message, () => []).add(log);
    }
    
    // Sort steps by earliest timestamp with null safety
    final steps = stepToLogs.keys.toList()
      ..sort((a, b) {
        final aTime = stepToLogs[a]?.map((l) => l.timestamp).reduce(
              (value, element) => value.isBefore(element) ? value : element,
            );
        final bTime = stepToLogs[b]?.map((l) => l.timestamp).reduce(
              (value, element) => value.isBefore(element) ? value : element,
            );
            
        if (aTime == null || bTime == null) return 0;
        return aTime.compareTo(bTime);
      });

    // Create timeline widgets
    final timelineItems = <Widget>[];
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      final stepLogs = stepToLogs[step]!;
      
      final startTime = stepLogs.map((l) => l.timestamp).reduce(
            (value, element) => value.isBefore(element) ? value : element,
          );
      final endTime = stepLogs.map((l) => l.timestamp).reduce(
            (value, element) => value.isAfter(element) ? value : element,
          );
      final duration = endTime.difference(startTime);
      
      final isCompleted = stepLogs.any((log) => log.level == 'Completed');
      final isError = stepLogs.any((log) => log.level == 'Failed');
      
      final statusColor = isError
          ? Colors.red.shade400
          : isCompleted
              ? AppColors.accentBlue
              : AppColors.tertiaryText;
      
      timelineItems.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: statusColor,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      isError
                          ? Icons.error_outline
                          : isCompleted
                              ? Icons.check
                              : Icons.hourglass_empty,
                      size: 12,
                      color: statusColor,
                    ),
                  ),
                ),
                if (i < steps.length - 1)
                  Container(
                    height: 50,
                    width: 1,
                    color: Colors.white.withOpacity(0.3),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatStepName(step),
                    style: GoogleFonts.poppins(
                      color: AppColors.primaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, HH:mm:ss').format(startTime) +
                        ' (${duration.inMinutes}m ${duration.inSeconds % 60}s)',
                    style: GoogleFonts.inter(
                      color: AppColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stepLogs.last.source?? "No Last Source",
                    style: GoogleFonts.inter(
                      color: AppColors.tertiaryText,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (i < steps.length - 1) const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      );
    }
    
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
            'Process Timeline',
            style: GoogleFonts.poppins(
              color: AppColors.accentPurple,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...timelineItems,
        ],
      ),
    );
  }
}