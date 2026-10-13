    final managers = store.managers;
    const unassigned = '';
    final selected = await showAppSheet<String>(
      context: context,
      builder: (sheetContext) => AppSheetBody(
        title: 'Assign Manager',
        subtitle: employee.fullName,
        icon: CupertinoIcons.person_2,
        showCancel: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSheetOption(
              label: 'Unassigned',
              icon: CupertinoIcons.person_crop_circle_badge_xmark,
              selected: employee.managerId == null,
              onTap: () => Navigator.pop(sheetContext, unassigned),
            ),
            if (managers.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'No managers yet. Add a manager first.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            for (final manager in managers)
              AppSheetOption(
                label: manager.fullName,
                subtitle:
                    '${store.employeesForManager(manager.id).length} employees',
                icon: CupertinoIcons.person_crop_circle,
                selected: employee.managerId == manager.id,
                onTap: () => Navigator.pop(sheetContext, manager.id),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;

    final managerId = selected == unassigned ? null : selected;
    if (managerId == employee.managerId) return;
    await store.assignEmployeeToManager(
      employeeId: employee.id,
      managerId: managerId,
    );
    if (managerId == null) {
      ToastService.success('Manager unassigned');
      return;
    }
    final manager = managers.firstWhere((m) => m.id == managerId);
    ToastService.success('Assigned to ${manager.fullName}');
  }

