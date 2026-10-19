import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../../core/services/toast_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../domain/online_models.dart';
import '../domain/online_repository.dart';
import 'service_media.dart';

/// Owner editor for the customer-facing rich description of a service.
class ServiceCustomerViewEditor extends StatefulWidget {
  const ServiceCustomerViewEditor({
    super.key,
    required this.repository,
    required this.businessId,
    required this.service,
  });

  final OnlineRepository repository;
  final String businessId;
  final SalonService service;

  @override
  State<ServiceCustomerViewEditor> createState() =>
      _ServiceCustomerViewEditorState();
}

class _ServiceCustomerViewEditorState extends State<ServiceCustomerViewEditor> {
  late final QuillController _controller;
  final _editorScroll = ScrollController();
  final _focus = FocusNode();
  bool _saving = false;
  bool _showPhotos = false;

  @override
  void initState() {
    super.initState();
    _controller = QuillController(
      document: _documentFromJson(widget.service.contentJson),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  Document _documentFromJson(List<dynamic> json) {
    if (json.isEmpty) return Document();
    try {
      return Document.fromJson(json);
    } catch (_) {
      return Document();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _editorScroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _plainExcerpt() {
    final plain = _controller.document.toPlainText().trim();
    if (plain.isEmpty) return widget.service.description;
    if (plain.length <= 500) return plain;
    return plain.substring(0, 500);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final delta = _controller.document.toDelta().toJson();
      await widget.repository.saveService(
        businessId: widget.businessId,
        id: widget.service.id,
        name: widget.service.name,
        category: widget.service.category,
        description: _plainExcerpt(),
        price: widget.service.price,
        isActive: widget.service.isActive,
        contentJson: delta,
      );
      if (!mounted) return;
      ToastService.success('Customer view saved', context);
      Navigator.pop(context, true);
    } on OnlineFailure catch (error) {
      if (mounted) ToastService.error(error.message, context);
    } catch (_) {
      if (mounted) {
        ToastService.error('Could not save customer view.', context);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static const _toolbarConfig = QuillSimpleToolbarConfig(
    multiRowsDisplay: false,
    showAlignmentButtons: true,
    showFontFamily: false,
    showFontSize: false,
    showBackgroundColorButton: false,
    showCodeBlock: false,
    showInlineCode: false,
    showSubscript: false,
    showSuperscript: false,
    showSearchButton: false,
    showQuote: true,
    showIndent: true,
    showListNumbers: true,
    showListBullets: true,
    showListCheck: false,
    showLink: true,
  );

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      backgroundColor: AppColors.surface,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(widget.service.name),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _showPhotos
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      Text(
                        'Before & after photos',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'These appear on the customer service page.',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ServiceMedia(
                        repository: widget.repository,
                        serviceId: widget.service.id,
                        businessId: widget.businessId,
                      ),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: QuillEditor.basic(
                      controller: _controller,
                      focusNode: _focus,
                      scrollController: _editorScroll,
                      config: const QuillEditorConfig(
                        placeholder:
                            'Write what customers should know about this service…',
                        padding: EdgeInsets.only(bottom: 12),
                        autoFocus: false,
                        expands: true,
                      ),
                    ),
                  ),
          ),
          Material(
            color: AppColors.surface,
            elevation: 2,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomInset > 0 ? 0 : 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Divider(height: 1),
                    if (!_showPhotos)
                      QuillSimpleToolbar(
                        controller: _controller,
                        config: _toolbarConfig,
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          TextButton.icon(
                            onPressed: () =>
                                setState(() => _showPhotos = !_showPhotos),
                            icon: Icon(
                              _showPhotos
                                  ? Icons.edit_note_outlined
                                  : Icons.photo_library_outlined,
                              size: 20,
                            ),
                            label: Text(
                              _showPhotos ? 'Back to writing' : 'Photos',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
