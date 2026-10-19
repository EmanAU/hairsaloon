import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Read-only Quill document for customer service detail.
class ServiceRichContent extends StatefulWidget {
  const ServiceRichContent({
    super.key,
    required this.contentJson,
    this.fallbackDescription = '',
  });

  final List<dynamic> contentJson;
  final String fallbackDescription;

  @override
  State<ServiceRichContent> createState() => _ServiceRichContentState();
}

class _ServiceRichContentState extends State<ServiceRichContent> {
  late final QuillController _controller;

  @override
  void initState() {
    super.initState();
    _controller = QuillController(
      document: _document(),
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
  }

  Document _document() {
    if (widget.contentJson.isEmpty) {
      final fallback = widget.fallbackDescription.trim();
      if (fallback.isEmpty) return Document();
      return Document.fromJson([
        {'insert': '$fallback\n'},
      ]);
    }
    try {
      return Document.fromJson(widget.contentJson);
    } catch (_) {
      final fallback = widget.fallbackDescription.trim();
      if (fallback.isEmpty) return Document();
      return Document.fromJson([
        {'insert': '$fallback\n'},
      ]);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _useRich {
    if (widget.contentJson.isEmpty) return false;
    final text = widget.contentJson
        .whereType<Map>()
        .map((op) => op['insert'])
        .whereType<String>()
        .join()
        .trim();
    return text.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (!_useRich) {
      final fallback = widget.fallbackDescription.trim();
      return Text(
        fallback.isEmpty ? 'No description added yet.' : fallback,
        style: const TextStyle(height: 1.45, color: Color(0xFF34441D)),
      );
    }
    return QuillEditor.basic(
      controller: _controller,
      config: const QuillEditorConfig(
        padding: EdgeInsets.zero,
        showCursor: false,
        enableInteractiveSelection: true,
        expands: false,
        scrollable: false,
      ),
    );
  }
}
