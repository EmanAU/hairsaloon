import 'package:flutter/material.dart';
import '../domain/online_repository.dart';
import 'widgets/online_widgets.dart';

class ReviewsPanel extends StatefulWidget {
  const ReviewsPanel({
    super.key,
    required this.repository,
    required this.businessId,
    this.employeeId,
  });
  final OnlineRepository repository;
  final String businessId;
  final String? employeeId;
  @override
  State<ReviewsPanel> createState() => _ReviewsPanelState();
}

class _ReviewsPanelState extends State<ReviewsPanel> {
  late Future<List<Map<String, dynamic>>> _rows = _load();
  Future<List<Map<String, dynamic>>> _load() => widget.repository.reviews(
    widget.businessId,
    employeeId: widget.employeeId,
  );
  void _refresh() => setState(() => _rows = _load());
  Future<void> _edit(Map<String, dynamic>? review) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _ReviewForm(
          repository: widget.repository,
          businessId: widget.businessId,
          employeeId: widget.employeeId,
          review: review,
        ),
      ),
    );
    if (saved == true && mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 24),
      Text('Customer reviews', style: Theme.of(context).textTheme.titleLarge),
      RemoteContent(
        future: _rows,
        onRetry: _refresh,
        builder: (rows) {
          final own = rows
              .where((row) => row['author_id'] == widget.repository.userId)
              .firstOrNull;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (rows.isEmpty) const Text('No reviews yet.'),
              const Text('Customer opinions; visits are not verified.'),
              ActionButton(
                label: own == null ? 'Write a review' : 'Edit your review',
                onPressed: () => _edit(own),
              ),
              if (own != null)
                ActionButton(
                  label: 'Delete your review',
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete your review?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                    await widget.repository.deleteReview(own['id'] as String);
                    if (mounted) _refresh();
                  },
                ),
              for (final row in rows)
                Card(
                  child: ListTile(
                    title: Text(
                      '${row['rating']} / 5 · ${row['author_id'] == widget.repository.userId ? 'You' : 'Customer'}',
                    ),
                    subtitle: Text(row['body'] as String),
                  ),
                ),
              if (rows.length >= 100)
                const Text('Showing recent reviews and your own review.'),
            ],
          );
        },
      ),
    ],
  );
}

class _ReviewForm extends StatefulWidget {
  const _ReviewForm({
    required this.repository,
    required this.businessId,
    this.employeeId,
    this.review,
  });
  final OnlineRepository repository;
  final String businessId;
  final String? employeeId;
  final Map<String, dynamic>? review;
  @override
  State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> {
  late final _body = TextEditingController(
    text: widget.review?['body'] as String?,
  );
  late int _rating = widget.review?['rating'] as int? ?? 5;
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OnlinePage(
    title: 'Your review',
    children: [
      Form(
        key: _form,
        child: Column(
          children: [
            DropdownButtonFormField<int>(
              initialValue: _rating,
              decoration: const InputDecoration(labelText: 'Rating'),
              items: [
                for (var i = 1; i <= 5; i++)
                  DropdownMenuItem(value: i, child: Text('$i / 5')),
              ],
              onChanged: (value) => _rating = value!,
            ),
            TextFormField(
              controller: _body,
              maxLength: 2000,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(labelText: 'Your experience'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Please describe your experience'
                  : null,
            ),
            ActionButton(
              label: 'Save review',
              onPressed: () async {
                if (!_form.currentState!.validate()) return;
                await widget.repository.saveReview(
                  widget.businessId,
                  _rating,
                  _body.text,
                  employeeId: widget.employeeId,
                  id: widget.review?['id'] as String?,
                );
                if (context.mounted) Navigator.pop(context, true);
              },
            ),
          ],
        ),
      ),
    ],
  );
}
