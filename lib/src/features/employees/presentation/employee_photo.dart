import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../online/data/business_workspace.dart';
import '../../../online/domain/online_repository.dart';
import '../domain/entities/employee_item.dart';

/// Linked staff always use their own profile photo; a shop logo or an owner's
/// locally selected image must never stand in for that person's identity.
class EmployeePhoto extends StatefulWidget {
  const EmployeePhoto({
    super.key,
    required this.employee,
    this.repository,
    this.size = 48,
  });
  final EmployeeItem employee;
  final OnlineRepository? repository;
  final double size;

  @override
  State<EmployeePhoto> createState() => _EmployeePhotoState();
}

class _EmployeePhotoState extends State<EmployeePhoto> {
  OnlineRepository? _repository;
  String? _employeeId;
  Future<String?>? _url;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(covariant EmployeePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    _load();
  }

  void _load() {
    final repository =
        widget.repository ?? context.read<BusinessWorkspace?>()?.repository;
    final id = widget.employee.onlineSynced ? widget.employee.id : null;
    if (id == _employeeId && identical(repository, _repository)) return;
    _repository = repository;
    _employeeId = id;
    _url = id == null || repository == null
        ? null
        : repository
              .profilePhoto(barberId: id)
              .timeout(const Duration(seconds: 15));
  }

  Widget _placeholder() => ColoredBox(
    color: const Color(0xFFEDF2E7),
    child: Center(
      child: Icon(
        Icons.person_outline,
        size: widget.size * .5,
        color: const Color(0xFF65745C),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ClipOval(
    child: SizedBox(
      width: widget.size,
      height: widget.size,
      child: widget.employee.onlineSynced
          ? FutureBuilder<String?>(
              future: _url,
              builder: (context, snapshot) {
                final url = snapshot.data;
                return url == null
                    ? (widget.employee.email.isNotEmpty
                          ? _localPhoto()
                          : _placeholder())
                    : Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _placeholder(),
                      );
              },
            )
          : _localPhoto(),
    ),
  );

  Widget _localPhoto() {
    final value = widget.employee.photoBase64;
    if (value == null || value.isEmpty) return _placeholder();
    try {
      return Image.memory(
        base64Decode(value),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    } on FormatException {
      return _placeholder();
    }
  }
}
