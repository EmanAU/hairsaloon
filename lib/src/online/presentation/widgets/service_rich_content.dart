import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../../../theme/app_colors.dart';

/// Read-only Quill document for customer / preview service detail.
/// Preserves bold, italic, underline, and list formatting from the editor.
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
  late QuillController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _buildController();
  }

  @override
  void didUpdateWidget(covariant ServiceRichContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameContent(oldWidget.contentJson, widget.contentJson) ||
        oldWidget.fallbackDescription != widget.fallbackDescription) {
      _controller.dispose();
      _controller = _buildController();
    }
  }

  bool _sameContent(List<dynamic> a, List<dynamic> b) {
    try {
      return jsonEncode(a) == jsonEncode(b);
    } catch (_) {
      return identical(a, b);
    }
  }

  QuillController _buildController() {
    return QuillController(
      document: _document(),
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
  }

  /// Deep-convert Supabase / JSON maps so Quill attributes (bold, etc.) apply.
  List<Map<String, dynamic>> _normalizeOps(List<dynamic> raw) {
    final ops = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final op = <String, dynamic>{};
      for (final entry in item.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (key == 'attributes' && value is Map) {
          op[key] = <String, dynamic>{
            for (final a in value.entries) a.key.toString(): a.value,
          };
        } else {
          op[key] = value;
        }
      }
      if (op.containsKey('insert')) ops.add(op);
    }
    return ops;
  }

  Document _document() {
    final normalized = _normalizeOps(widget.contentJson);
    if (normalized.isNotEmpty) {
      try {
        return Document.fromJson(normalized);
      } catch (_) {
        // Fall through to plain description.
      }
    }
    final fallback = widget.fallbackDescription.trim();
    if (fallback.isEmpty) return Document();
    return Document.fromJson([
      {'insert': '$fallback\n'},
    ]);
  }

  bool get _hasVisibleText {
    final plain = _controller.document.toPlainText().trim();
    return plain.isNotEmpty;
  }

  DefaultStyles _styles(BuildContext context) {
    const baseColor = Color(0xFF34441D);
    const baseSize = 15.0;
    final base = DefaultTextBlockStyle(
      const TextStyle(
        fontSize: baseSize,
        height: 1.45,
        color: baseColor,
      ),
      HorizontalSpacing.zero,
      VerticalSpacing.zero,
      VerticalSpacing.zero,
      null,
    );
    final lists = DefaultListBlockStyle(
      const TextStyle(
        fontSize: baseSize,
        height: 1.45,
        color: baseColor,
      ),
      HorizontalSpacing.zero,
      const VerticalSpacing(6, 0),
      const VerticalSpacing(0, 6),
      null,
      null,
    );
    return DefaultStyles.getInstance(context).merge(
      DefaultStyles(
        paragraph: base,
        bold: const TextStyle(
          fontWeight: FontWeight.w700,
          color: baseColor,
        ),
        italic: const TextStyle(
          fontStyle: FontStyle.italic,
          color: baseColor,
        ),
        underline: const TextStyle(
          decoration: TextDecoration.underline,
          color: baseColor,
        ),
        lists: lists,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasVisibleText) {
      return Text(
        'No description added yet.',
        style: TextStyle(
          height: 1.45,
          color: AppColors.textSecondary,
        ),
      );
    }

    return QuillEditor.basic(
      controller: _controller,
      config: QuillEditorConfig(
        padding: EdgeInsets.zero,
        showCursor: false,
        enableInteractiveSelection: true,
        expands: false,
        scrollable: false,
        customStyles: _styles(context),
      ),
    );
  }
}
