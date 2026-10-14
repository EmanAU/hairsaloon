import 'package:flutter/cupertino.dart';
import 'package:hairsaloon/src/core/widgets/app_sheet.dart';
import 'package:hairsaloon/src/features/employees/domain/entities/employee_item.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';

/// Assignment sheet. Returns selected manager ids (empty = unassigned),
/// or null if cancelled.
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
  /// Empty set = unassigned. Supports one or more managers.
  late final Set<String> _selected = {
    for (final id in widget.initialIds)
      if (widget.isBlocked?.call(id) != true) id,
  };

  bool _blocked(String id) => widget.isBlocked?.call(id) == true;

  void _unassign() {
    setState(() => _selected.clear());
  }

  void _toggle(String id) {
    if (_blocked(id)) return;
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final unassigned = _selected.isEmpty;
    return AppSheetBody(
      title: 'Assigned to',
      subtitle: widget.employeeName,
      icon: CupertinoIcons.person_2,
      confirmLabel: unassigned ? 'Set Unassigned' : 'Apply Assignment',
      onConfirm: () => Navigator.of(context).pop(
        _selected.where((id) => !_blocked(id)).toList(growable: false),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSheetOption(
            label: 'Unassigned',
            subtitle: 'Clear assignment — not under anyone',
            icon: CupertinoIcons.person_crop_circle_badge_xmark,
            selected: unassigned,
            onTap: _unassign,
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
          else ...[
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                'Assign to',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ...widget.others.map(_option),
          ],
        ],
      ),
    );
  }

  Widget _option(EmployeeItem other) {
    final blocked = _blocked(other.id);
    final selected = !blocked && _selected.contains(other.id);
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
      selected: selected,
      enabled: !blocked,
      onTap: () => _toggle(other.id),
    );
  }
}
