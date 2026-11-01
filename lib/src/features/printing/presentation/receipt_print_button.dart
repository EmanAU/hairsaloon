import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/toast_service.dart';
import '../../billing/domain/entities/bill.dart';
import '../../business_profile/presentation/state/business_profile_notifier.dart';
import '../../settings/presentation/state/settings_store.dart';
import '../domain/receipt_printer.dart';
import 'receipt_printer_store.dart';

/// Shared by checkout, receipt preview and the test action in Business Settings.
class ReceiptPrintButton extends StatelessWidget {
  const ReceiptPrintButton({super.key, this.bill, this.enabled = true});
  final Bill? bill;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final printer = context.watch<ReceiptPrinterStore>();
    return OutlinedButton.icon(
      onPressed: !enabled || printer.busy || printer.loading || printer.scanning
          ? null
          : () async {
              final profile = context.read<BusinessProfileNotifier>().profile;
              final currency = context.read<SettingsStore>().currencyCode;
              final testBill =
                  bill ??
                  Bill(
                    id: 'printer-test',
                    createdAt: DateTime.now(),
                    customerName: 'Test customer',
                    customerPhone: '',
                    employeeName: 'Test barber',
                    paymentType: 'Cash',
                    lines: const [
                      BillLine(serviceName: 'Haircut — test only', price: 500),
                    ],
                    subTotal: 500,
                    taxPercent: 0,
                    taxAmount: 0,
                    grandTotal: 500,
                  );
              await printer.print(
                PrintableReceipt(
                  bill: testBill,
                  businessName: profile?.businessName ?? 'TrimMatrix',
                  businessPhone: profile?.phoneNumber ?? '',
                  businessAddress: profile?.address.trim().isNotEmpty == true
                      ? profile!.address
                      : [profile?.area, profile?.city]
                            .whereType<String>()
                            .where((v) => v.isNotEmpty)
                            .join(', '),
                  currency: currency,
                  logoBase64: profile?.logoBase64,
                  test: bill == null,
                ),
              );
              if (!context.mounted) return;
              if (printer.error != null) {
                ToastService.error(printer.error!, context);
              } else if (printer.message != null) {
                ToastService.info(printer.message!, context);
              }
            },
      icon: const Icon(Icons.print_outlined, size: 18),
      label: Text(
        printer.busy
            ? 'Sending…'
            : bill == null
            ? 'Print test receipt'
            : 'Print receipt',
      ),
    );
  }
}
