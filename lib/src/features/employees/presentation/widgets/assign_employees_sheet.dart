import 'package:flutter/cupertino.dart';
import 'package:hairsaloon/src/core/widgets/app_sheet.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';

/// Multi-select sheet. Returns the chosen ids (empty = unassigned), or null
/// if cancelled.
Future<List<String>?> showAssignEmployeesSheet({
  required BuildContext context,
  required String employeeName,
  required List<EmployeeItem> others,
  required List<String> selectedIds,
  required int Function(String employeeId) assignedCount,
  bool Function(String employeeId)? isBlocked,
}) {
  return showAppSheet<List<String>>(
    context: context,
    builder: (_) => _AssignEmployeesSheet(
      employeeName: employeeName,
      others: others,
      initialIds: selectedIds,
      assignedCount: assignedCount,
      isBlocked: isBlocked,
    ),
  );
}

class _AssignEmployeesSheet extends StatefulWidget {
  const _AssignEmployeesSheet({
    required this.employeeName,
    required this.others,
    required this.initialIds,
    required this.assignedCount,
    this.isBlocked,
  });

  final String employeeName;
  final List<EmployeeItem> others;
  final List<String> initialIds;
  final int Function(String employeeId) assignedCount;
  final bool Function(String employeeId)? isBlocked;

  @override
  State<_AssignEmployeesSheet> createState() => _AssignEmployeesSheetState();
}

class _AssignEmployeesSheetState extends State<_AssignEmployeesSheet> {
  late final Set<String> _selected = {
    for (final id in widget.initialIds)
      if (widget.isBlocked?.call(id) != true) id,
  };

  bool _blocked(String id) => widget.isBlocked?.call(id) == true;

  @override
  Widget build(BuildContext context) {
    return AppSheetBody(
      title: 'Assigned to',
      subtitle: widget.employeeName,
      icon: CupertinoIcons.person_2,
      confirmLabel: 'Apply',
      onConfirm: () => Navigator.of(context).pop(
        _selected.where((id) => !_blocked(id)).toList(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSheetOption(
            label: 'Unassigned',
            subtitle: 'Not assigned to anyone',
            icon: CupertinoIcons.person_crop_circle_badge_xmark,
            selected: _selected.isEmpty,
            onTap: () => setState(_selected.clear),
          ),
          if (widget.others.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'No other employees yet.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            )
          else
            ...widget.others.map(_option),
        ],
      ),
    );
  }

  Widget _option(EmployeeItem other) {
    final blocked = _blocked(other.id);
    final count = widget.assignedCount(other.id);
    final status = other.isActive ? 'Active' : 'Inactive';
    final subtitle = blocked
        ? 'Already under ${widget.employeeName} — cannot reverse'
        : count == 0
        ? status
        : '$status  •  $count assigned';
    return AppSheetOption(
      label: other.fullName,
      subtitle: subtitle,
      icon: CupertinoIcons.person_crop_circle,
      selected: !blocked && _selected.contains(other.id),
      enabled: !blocked,
      onTap: () {
        if (blocked) return;
        setState(() {
          if (_selected.contains(other.id)) {
            _selected.remove(other.id);
          } else {
            _selected.add(other.id);
          }
        });
      },
    );
  }
}
