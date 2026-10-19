import 'dart:ui';

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
  late final TextEditingController _titleCtrl;
  bool _saving = false;
  bool _showPhotos = false;
  bool _loading = true;
  String? _loadError;
  late SalonService _service;
  String? _beforeUrl;
  String? _afterUrl;

  @override
  void initState() {
    super.initState();
    _service = widget.service;
    _titleCtrl = TextEditingController(text: widget.service.name);
    _resumeFromSupabase();
    _loadPhotoStatus();
  }

  Future<void> _loadPhotoStatus() async {
    try {
      final rows = await widget.repository.media(_service.id);
      if (!mounted) return;
      String? before;
      String? after;
      for (final row in rows) {
        final kind = row['kind'] as String?;
        final url = row['url'] as String?;
        if (kind == 'before' && before == null) before = url;
        if (kind == 'after' && after == null) after = url;
      }
      setState(() {
        _beforeUrl = before;
        _afterUrl = after;
      });
    } catch (_) {
      // Bottom tiles stay on "Add photo" if status can't load.
    }
  }

  void _leavePhotosOrPop() {
    if (_showPhotos) {
      setState(() => _showPhotos = false);
      return;
    }
    Navigator.maybePop(context);
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
      _titleCtrl.text = _service.name;
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
    _titleCtrl.dispose();
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
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ToastService.error('Enter a service title.', context);
      return;
    }
    setState(() => _saving = true);
    try {
      final delta = controller.document.toDelta().toJson();
      final saved = await widget.repository.saveServiceContent(
        serviceId: _service.id,
        contentJson: delta,
        description: _plainExcerpt(),
        name: title,
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

    return PopScope(
      canPop: !_showPhotos,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_showPhotos) setState(() => _showPhotos = false);
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          surfaceTintColor: const Color(0x00000000),
          elevation: 0,
          foregroundColor: AppColors.onPrimary,
          iconTheme: const IconThemeData(color: AppColors.onPrimary),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _leavePhotosOrPop,
          ),
          title: const Text(
            'Edit customer view',
            style: TextStyle(
              color: AppColors.onPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  _saving || _loading || controller == null ? null : _save,
              child: Text(
                _saving ? 'Saving…' : 'Save',
                style: const TextStyle(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
                if (!_showPhotos)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _titleCtrl,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            height: 1.25,
                          ),
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            hintText: 'Service title',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _service.category.trim().isEmpty
                              ? 'Service'
                              : _service.category,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Divider(height: 1, color: AppColors.border),
                      ],
                    ),
                  ),
                Expanded(
                  child: _showPhotos
                      ? ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          children: [
                            Text(
                              'Before & after',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Two sections: add a Before photo and an After photo.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            ServiceBeforeAfterCards(
                              repository: widget.repository,
                              serviceId: _service.id,
                              businessId: widget.businessId,
                              onChanged: _loadPhotoStatus,
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
                            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                            child: _showPhotos
                                ? Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: () => setState(
                                        () => _showPhotos = false,
                                      ),
                                      icon: const Icon(
                                        Icons.edit_note_outlined,
                                        size: 20,
                                        color: AppColors.textPrimary,
                                      ),
                                      label: const Text(
                                        'Back to writing',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  )
                                : Row(
                                    children: [
                                      Expanded(
                                        child: _PhotoNavTile(
                                          label: 'Before photo',
                                          imageUrl: _beforeUrl,
                                          onTap: () => setState(
                                            () => _showPhotos = true,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 1,
                                        height: 40,
                                        color: AppColors.border,
                                      ),
                                      Expanded(
                                        child: _PhotoNavTile(
                                          label: 'After photo',
                                          imageUrl: _afterUrl,
                                          onTap: () => setState(
                                            () => _showPhotos = true,
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
      ),
    );
  }
}

class _PhotoNavTile extends StatelessWidget {
  const _PhotoNavTile({
    required this.label,
    required this.onTap,
    this.imageUrl,
  });

  final String label;
  final String? imageUrl;
  final VoidCallback onTap;

  bool get _hasPhoto => imageUrl != null && imageUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            _thumb(),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    _hasPhoto ? 'Change photo' : 'Add photo',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumb() {
    if (!_hasPhoto) {
      return const Icon(
        Icons.add_photo_alternate_outlined,
        size: 22,
        color: AppColors.textPrimary,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 36,
        height: 36,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: AppColors.background,
                child: Icon(Icons.broken_image_outlined, size: 16),
              ),
            ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 1.4, sigmaY: 1.4),
              child: ColoredBox(
                color: AppColors.textPrimary.withValues(alpha: 0.28),
              ),
            ),
            const Center(
              child: Icon(
                Icons.photo_outlined,
                size: 16,
                color: AppColors.surface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
