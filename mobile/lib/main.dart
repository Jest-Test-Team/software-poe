import 'package:flutter/material.dart';

import 'api.dart';

void main() => runApp(const PoeApp());

class PoeApp extends StatelessWidget {
  const PoeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Software POE',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const ReviewQueueScreen(),
    );
  }
}

class ReviewQueueScreen extends StatefulWidget {
  const ReviewQueueScreen({super.key});

  @override
  State<ReviewQueueScreen> createState() => _ReviewQueueScreenState();
}

class _ReviewQueueScreenState extends State<ReviewQueueScreen> {
  final _api = PoeApi();
  late Future<List<Assessment>> _queue;

  @override
  void initState() {
    super.initState();
    _queue = _api.reviewQueue();
  }

  Future<void> _reload() async {
    setState(() => _queue = _api.reviewQueue());
    await _queue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review queue')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<Assessment>>(
          future: _queue,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Cannot reach gateway: ${snapshot.error}'),
                ),
              ]);
            }
            final items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return ListView(children: const [
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Nothing awaiting review.'),
                ),
              ]);
            }
            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, i) {
                final a = items[i];
                return ListTile(
                  leading: Icon(
                    a.gapDetected ? Icons.warning_amber : Icons.check_circle_outline,
                    color: a.gapDetected ? Colors.amber.shade800 : Colors.green,
                  ),
                  title: Text(a.summary, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                      'uncertainty ${a.uncertainty.toStringAsFixed(2)}'
                      '${a.missingData ? ' · missing expectation' : ''}'
                      '${a.staleEvidence ? ' · stale' : ''}'),
                  onTap: () async {
                    final changed = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => AssessmentDetailScreen(assessment: a, api: _api),
                      ),
                    );
                    if (changed == true) _reload();
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class AssessmentDetailScreen extends StatefulWidget {
  const AssessmentDetailScreen(
      {super.key, required this.assessment, required this.api});

  final Assessment assessment;
  final PoeApi api;

  @override
  State<AssessmentDetailScreen> createState() => _AssessmentDetailScreenState();
}

class _AssessmentDetailScreenState extends State<AssessmentDetailScreen> {
  final _reviewer = TextEditingController();
  final _annotation = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _decide(String decision) async {
    if (_reviewer.text.trim().isEmpty) {
      setState(() => _error = 'Reviewer name is required — decisions are audited.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.review(widget.assessment.id,
          reviewer: _reviewer.text.trim(),
          decision: decision,
          annotation:
              _annotation.text.trim().isEmpty ? null : _annotation.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.assessment;
    return Scaffold(
      appBar: AppBar(title: const Text('Assessment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(a.summary, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('uncertainty ${a.uncertainty.toStringAsFixed(2)}'),
          Text('rule ${a.ruleVersion ?? 'n/a'}'),
          Text('evidence: ${a.evidenceRefs.join(', ')}'),
          if (a.missingData) const Text('⚠ missing expectation'),
          if (a.staleEvidence) const Text('⚠ stale evidence (>30d)'),
          const Divider(height: 32),
          TextField(
            controller: _reviewer,
            decoration: const InputDecoration(labelText: 'Reviewer'),
          ),
          TextField(
            controller: _annotation,
            decoration: const InputDecoration(labelText: 'Annotation (optional)'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : () => _decide('accepted'),
                  child: const Text('Accept'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: _busy ? null : () => _decide('rejected'),
                  child: const Text('Reject'),
                ),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }
}
