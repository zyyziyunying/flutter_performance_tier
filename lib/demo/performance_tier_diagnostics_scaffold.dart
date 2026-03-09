import 'package:flutter/material.dart';

class PerformanceTierDiagnosticsScaffold extends StatelessWidget {
  const PerformanceTierDiagnosticsScaffold({
    super.key,
    required this.title,
    required this.introText,
    required this.headline,
    required this.report,
    required this.isRefreshing,
    required this.onRefresh,
    required this.onCopyAiReport,
    required this.onCopyLatestLogLine,
    this.error,
    this.controlButtons = const <Widget>[],
    this.sectionsBeforeReport = const <Widget>[],
  });

  final String title;
  final String introText;
  final String headline;
  final String report;
  final bool isRefreshing;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onCopyAiReport;
  final Future<void> Function() onCopyLatestLogLine;
  final String? error;
  final List<Widget> controlButtons;
  final List<Widget> sectionsBeforeReport;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: <Widget>[
          IconButton(
            onPressed: isRefreshing ? null : onRefresh,
            tooltip: 'Refresh decision',
            icon: isRefreshing
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: onCopyAiReport,
            tooltip: 'Copy AI report',
            icon: const Icon(Icons.copy_all_outlined),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              introText,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(headline),
            if (error != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Last Error: $error',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: onCopyLatestLogLine,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy latest log'),
                ),
                ...controlButtons,
              ],
            ),
            ..._buildSectionsWithSpacing(),
            const SizedBox(height: 12),
            Text(
              'AI Diagnostics JSON',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    report,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSectionsWithSpacing() {
    if (sectionsBeforeReport.isEmpty) {
      return const <Widget>[];
    }

    final widgets = <Widget>[const SizedBox(height: 8)];
    for (final section in sectionsBeforeReport) {
      widgets.add(section);
      widgets.add(const SizedBox(height: 8));
    }
    return widgets;
  }
}
