import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../core/services/toast_service.dart';
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
  final _scroll = ScrollController();
  final _editorScroll = ScrollController();
  final _focus = FocusNode();
  bool _saving = false;

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
    _scroll.dispose();
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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: Text(
        'Customer view · ${widget.service.name}',
        style: const TextStyle(fontFamily: 'Roboto'),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    ),
    body: Column(
      children: [
        QuillSimpleToolbar(
          controller: _controller,
          config: const QuillSimpleToolbarConfig(
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
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              const Text(
                'Describe this service for customers. Add before & after photos below.',
                style: TextStyle(color: Color(0xFF718094)),
              ),
              const SizedBox(height: 12),
              Container(
                height: 280,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE1E5EA)),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
                child: QuillEditor.basic(
                  controller: _controller,
                  focusNode: _focus,
                  scrollController: _editorScroll,
                  config: const QuillEditorConfig(
                    placeholder: 'Write what is included in this service…',
                    padding: EdgeInsets.zero,
                    autoFocus: false,
                    expands: false,
                  ),
                ),
              ),
              ServiceMedia(
                repository: widget.repository,
                serviceId: widget.service.id,
                businessId: widget.businessId,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
