import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/widgets/app_confirm_dialog.dart';
import '../../theme/app_colors.dart';
import '../domain/online_models.dart';
import '../domain/online_repository.dart';
import 'widgets/online_widgets.dart';

Future<bool> showCustomerReviewEditor(
  BuildContext context,
  OnlineRepository repository,
  String businessId, {
  String? employeeId,
}) async {
  try {
    final rows = await repository.reviews(businessId, employeeId: employeeId);
    if (!context.mounted) return false;
    final own = rows
        .where((r) => r['author_id'] == repository.userId)
        .firstOrNull;
    return await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => _ReviewForm(
              repository: repository,
              businessId: businessId,
              employeeId: employeeId,
              review: own,
            ),
          ),
        ) ??
        false;
  } catch (_) {
    if (context.mounted) {
      showMessage(context, 'Could not open your review. Please try again.');
    }
    return false;
  }
}

class ReviewsPanel extends StatefulWidget {
  const ReviewsPanel({
    super.key,
    required this.repository,
    required this.businessId,
    this.employeeId,
    this.showWriteAction = true,
  });
  final OnlineRepository repository;
  final String businessId;
  final String? employeeId;
  final bool showWriteAction;
  @override
  State<ReviewsPanel> createState() => ReviewsPanelState();
}

class ReviewsPanelState extends State<ReviewsPanel> {
  late Future<List<Map<String, dynamic>>> _rows = _load();
  Future<List<Map<String, dynamic>>> _load() => widget.repository.reviews(
    widget.businessId,
    employeeId: widget.employeeId,
  );
  void refresh() => setState(() {
    _rows = _load();
  });
  Future<void> editOwnReview() async {
    final saved = await showCustomerReviewEditor(
      context,
      widget.repository,
      widget.businessId,
      employeeId: widget.employeeId,
    );
    if (saved && mounted) refresh();
  }

  Future<void> _delete(Map<String, dynamic> review) async {
    final yes = await showAppConfirmDialog(
      context: context,
      title: 'Delete your review?',
      message: 'You can write a new review whenever you like.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (yes != true) return;
    try {
      await widget.repository.deleteReview(review['id'] as String);
      if (mounted) refresh();
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Could not delete your review. Please retry.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Customer reviews',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            letterSpacing: -.35,
          ),
        ),
        const SizedBox(height: 14),
        RemoteContent<List<Map<String, dynamic>>>(
          future: _rows,
          onRetry: refresh,
          builder: (rows) {
            final own = rows
                .where((r) => r['author_id'] == widget.repository.userId)
                .firstOrNull;
            final average = rows.isEmpty
                ? 0.0
                : rows.fold<double>(
                        0,
                        (s, r) => s + (r['rating'] as num).toDouble(),
                      ) /
                      rows.length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8F5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Text(
                        rows.isEmpty ? '—' : average.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Stars(average.round()),
                            const SizedBox(height: 5),
                            Text(
                              rows.isEmpty
                                  ? 'Be the first to share your experience'
                                  : '${rows.length} ${rows.length == 1 ? 'review' : 'reviews'}${rows.length >= 100 ? ' · recent' : ''}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  'Customer opinions · visits are not verified',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (widget.showWriteAction)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: OutlinedButton.icon(
                      onPressed: editOwnReview,
                      icon: const Icon(CupertinoIcons.star, size: 17),
                      label: Text(
                        own == null ? 'Write a review' : 'Edit your review',
                      ),
                    ),
                  ),
                if (rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No reviews yet. Your experience could help someone choose.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                for (final row in rows)
                  Container(
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 17,
                              backgroundColor: Color(0xFFF1F5EA),
                              child: Icon(
                                CupertinoIcons.person,
                                size: 18,
                                color: AppColors.homeOlive,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                row['author_id'] == widget.repository.userId
                                    ? 'You'
                                    : (row['author_name'] as String? ??
                                          'Customer'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (row['author_id'] == widget.repository.userId)
                              PopupMenuButton<String>(
                                tooltip: 'Your review options',
                                icon: const Icon(
                                  CupertinoIcons.ellipsis,
                                  size: 19,
                                ),
                                onSelected: (v) {
                                  if (v == 'edit') editOwnReview();
                                  if (v == 'delete') _delete(row);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit your review'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete your review'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _Stars((row['rating'] as num).toInt()),
                        const SizedBox(height: 10),
                        Text(
                          row['body'] as String? ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.6,
                            color: AppColors.homeOlive,
                          ),
                        ),
                        if (DateTime.tryParse(
                              (row['created_at'] ?? '').toString(),
                            )
                            case final date?)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              '${date.day}/${date.month}/${date.year}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _Stars extends StatelessWidget {
  const _Stars(this.value);
  final int value;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 1; i <= 5; i++)
        Icon(
          i <= value ? CupertinoIcons.star_fill : CupertinoIcons.star,
          size: 15,
          color: const Color(0xFF6C7F25),
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
  late int _rating = (widget.review?['rating'] as num?)?.toInt() ?? 5;
  final _form = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.saveReview(
        widget.businessId,
        _rating,
        _body.text,
        employeeId: widget.employeeId,
        id: widget.review?['id'] as String?,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is OnlineFailure
              ? error.message
              : 'Could not save your review. Your text is still here; please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        tooltip: 'Back',
        onPressed: _saving ? null : () => Navigator.maybePop(context),
        icon: const Icon(CupertinoIcons.back),
      ),
      title: const Text(
        'Your review',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF1FFCC),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  const Text(
                    'How was your experience?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.6,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    widget.employeeId == null
                        ? 'Share a little about your time at this salon.'
                        : 'Share your experience with this barber.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.homeOlive,
                    ),
                  ),
                  const SizedBox(height: 22),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 1; i <= 5; i++)
                          IconButton(
                            tooltip: '$i ${i == 1 ? 'star' : 'stars'}',
                            onPressed: _saving
                                ? null
                                : () => setState(() => _rating = i),
                            icon: Icon(
                              i <= _rating
                                  ? CupertinoIcons.star_fill
                                  : CupertinoIcons.star,
                              color: AppColors.homeOlive,
                              size: 32,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    [
                      '',
                      'Poor',
                      'Fair',
                      'Good',
                      'Very good',
                      'Excellent',
                    ][_rating],
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.homeOlive,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            const Text(
              'Tell us more',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            Form(
              key: _form,
              child: TextFormField(
                controller: _body,
                enabled: !_saving,
                maxLength: 2000,
                minLines: 5,
                maxLines: 9,
                decoration: InputDecoration(
                  hintText: 'What did you like? What could be better?',
                  hintStyle: const TextStyle(fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFFF7F8F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Please describe your experience'
                    : null,
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 13),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF17251E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(_saving ? 'Saving…' : 'Save review'),
            ),
          ],
        ),
      ),
    ),
  );
}
