import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/features/billing/presentation/state/billing_store.dart';
import 'package:hairsaloon/src/features/router/app_routes.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

class SavedBillsScreen extends StatelessWidget {
  const SavedBillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bills = context.watch<BillingStore>().bills;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(CupertinoIcons.back, color: Colors.black),
        ),
        title: const Text(
          'Saved Bills',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
        ),
      ),
      body: bills.isEmpty
          ? const Center(child: Text('No saved bills yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: bills.length,
              itemBuilder: (context, index) {
                final bill = bills[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      title: Text(
                        bill.customerName.isEmpty
                            ? (bill.customerPhone.isEmpty
                                  ? 'Walk-in Customer'
                                  : bill.customerPhone)
                            : bill.customerName,
                      ),
                      subtitle: Text(
                        'Rs.${bill.grandTotal.toStringAsFixed(0)} • ${bill.employeeName}',
                      ),
                      trailing: const Icon(CupertinoIcons.chevron_right),
                      onTap: () {
                        Navigator.of(
                          context,
                        ).pushNamed(AppRoutes.billDetails, arguments: bill.id);
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
