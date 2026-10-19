import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../../core/services/toast_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../domain/online_models.dart';
import '../domain/online_repository.dart';
import 'service_before_after_cards.dart';

/// Owner editor for the customer-facing rich description of a service.
/// Always resumes the latest [content_json] from Supabase (not a blank doc).
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
  QuillController? _controller;
  final _editorScroll = ScrollController();
  final _focus = FocusNode();
  bool _saving = false;
  bool _showPhotos = false;
  bool _loading = true;
  String? _loadError;
  late SalonService _service;

  @override
  void initState() {
    super.initState();
    _service = widget.service;
    _resumeFromSupabase();
  }

  Future<void> _resumeFromSupabase() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final fresh = await widget.repository.serviceById(widget.service.id);
      if (!mounted) return;
      _service = fresh ?? widget.service;
      _controller?.dispose();
      _controller = QuillController(
        document: _documentFromJson(_service.contentJson),
        selection: const TextSelection.collapsed(offset: 0),
      );
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      // Fall back to whatever was passed in (still better than blank).
      _controller?.dispose();
      _controller = QuillController(
        document: _documentFromJson(widget.service.contentJson),
        selection: const TextSelection.collapsed(offset: 0),
      );
      setState(() {
        _loading = false;
        _loadError = null;
      });
    }
  }

  Document _documentFromJson(List<dynamic> json) {
    if (json.isEmpty) {
      final fallback = _service.description.trim();
      if (fallback.isEmpty) return Document();
      return Document.fromJson([
        {'insert': '$fallback\n'},
      ]);
    }
    try {
      final ops = <Map<String, dynamic>>[];
      for (final item in json) {
        if (item is! Map) continue;
        final op = <String, dynamic>{
          for (final e in item.entries) e.key.toString(): e.value,
        };
        if (op['attributes'] is Map) {
          final attrs = op['attributes'] as Map;
          op['attributes'] = <String, dynamic>{
            for (final e in attrs.entries) e.key.toString(): e.value,
          };
        }
        if (op.containsKey('insert')) ops.add(op);
      }
      if (ops.isEmpty) return Document();
      return Document.fromJson(ops);
    } catch (_) {
      final fallback = _service.description.trim();
      if (fallback.isEmpty) return Document();
      return Document.fromJson([
        {'insert': '$fallback\n'},
      ]);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _editorScroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _plainExcerpt() {
    final plain = _controller?.document.toPlainText().trim() ?? '';
    if (plain.isEmpty) return _service.description;
    if (plain.length <= 500) return plain;
    return plain.substring(0, 500);
  }

  Future<void> _save() async {
    final controller = _controller;
    if (_saving || controller == null) return;
    setState(() => _saving = true);
    try {
      final delta = controller.document.toDelta().toJson();
      final saved = await widget.repository.saveServiceContent(
        serviceId: _service.id,
        contentJson: delta,
        description: _plainExcerpt(),
      );
      if (!mounted) return;
      _service = saved;
      // Parent opens View with [saved]; toast there so Scaffold is ready.
      Navigator.pop(context, saved);
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

  QuillSimpleToolbarConfig get _toolbarConfig => QuillSimpleToolbarConfig(
    multiRowsDisplay: false,
    showDividers: true,
    // Common writing tools.
    showBoldButton: true,
    showItalicButton: true,
    showUnderLineButton: true,
    showStrikeThrough: true,
    showListBullets: true,
    showListNumbers: true,
    showIndent: true,
    showLink: true,
    showClearFormat: true,
    showUndo: true,
    showRedo: true,
    // Keep the rest off.
    showFontFamily: false,
    showFontSize: false,
    showInlineCode: false,
    showColorButton: false,
    showBackgroundColorButton: false,
    showHeaderStyle: false,
    showListCheck: false,
    showCodeBlock: false,
    showQuote: false,
    showSearchButton: false,
    showSubscript: false,
    showSuperscript: false,
    showAlignmentButtons: false,
    showDirection: false,
    toolbarSize: 44,
    buttonOptions: QuillSimpleToolbarButtonOptions(
      base: QuillToolbarBaseButtonOptions(
        iconTheme: QuillIconTheme(
          iconButtonSelectedData: IconButtonData(
            style: IconButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              backgroundColor: AppColors.primary.withValues(alpha: 0.55),
              minimumSize: const Size(40, 40),
            ),
          ),
          iconButtonUnselectedData: IconButtonData(
            style: IconButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              minimumSize: const Size(40, 40),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final controller = _controller;

    return Scaffold(
      backgroundColor: AppColors.surface,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(_service.name),
        actions: [
          TextButton(
            onPressed: _saving || _loading || controller == null ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
        ],
      ),
      body: _loading || controller == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_loadError != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      _loadError!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
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
                            ServiceBeforeAfterCards(
                              repository: widget.repository,
                              serviceId: _service.id,
                              businessId: widget.businessId,
                            ),
                          ],
                        )
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: QuillEditor.basic(
                            controller: controller,
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
                  elevation: 3,
                  shadowColor: AppColors.shadow,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: bottomInset > 0 ? 0 : 0,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Divider(height: 1, color: AppColors.border),
                          if (!_showPhotos)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: QuillSimpleToolbar(
                                  controller: controller,
                                  config: _toolbarConfig,
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
                            child: Row(
                              children: [
                                TextButton.icon(
                                  onPressed: () => setState(
                                    () => _showPhotos = !_showPhotos,
                                  ),
                                  icon: Icon(
                                    _showPhotos
                                        ? Icons.edit_note_outlined
                                        : Icons.photo_library_outlined,
                                    size: 20,
                                    color: AppColors.textPrimary,
                                  ),
                                  label: Text(
                                    _showPhotos
                                        ? 'Back to writing'
                                        : 'Photos',
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
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
