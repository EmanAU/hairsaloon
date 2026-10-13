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
}) {
  return showAppSheet<List<String>>(
    context: context,
    builder: (_) => _AssignEmployeesSheet(
      employeeName: employeeName,
      others: others,
      initialIds: selectedIds,
      assignedCount: assignedCount,
    ),
  );
}

class _AssignEmployeesSheet extends StatefulWidget {
  const _AssignEmployeesSheet({
    required this.employeeName,
    required this.others,
    required this.initialIds,
    required this.assignedCount,
  });

  final String employeeName;
  final List<EmployeeItem> others;
  final List<String> initialIds;
  final int Function(String employeeId) assignedCount;

  @override
  State<_AssignEmployeesSheet> createState() => _AssignEmployeesSheetState();
}

class _AssignEmployeesSheetState extends State<_AssignEmployeesSheet> {
  late final Set<String> _selected = widget.initialIds.toSet();

  @override
  Widget build(BuildContext context) {
    return AppSheetBody(
      title: 'Assigned to',
      subtitle: widget.employeeName,
      icon: CupertinoIcons.person_2,
      confirmLabel: 'Apply',
      onConfirm: () => Navigator.of(context).pop(_selected.toList()),
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
            for (final other in widget.others)
              AppSheetOption(
                label: other.fullName,
                subtitle: () {
                  final count = widget.assignedCount(other.id);
                  final status = other.isActive ? 'Active' : 'Inactive';
                  if (count == 0) return status;
                  return '$status  •  $count assigned';
                }(),
                icon: CupertinoIcons.person_crop_circle,
                selected: _selected.contains(other.id),
                onTap: () => setState(() {
                  if (_selected.contains(other.id)) {
                    _selected.remove(other.id);
                  } else {
                    _selected.add(other.id);
                  }
                }),
              ),
        ],
      ),
    );
  }
}
