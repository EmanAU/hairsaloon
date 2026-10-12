import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/features/billing/domain/entities/bill.dart';
import 'package:hairsaloon/src/features/billing/presentation/state/billing_store.dart';
import 'package:hairsaloon/src/features/router/app_routes.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  String _paymentFilter = 'Cash';
  _SalesPeriod _period = _SalesPeriod.daily;
  DateTime _anchorDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final allBills = context.watch<BillingStore>().bills;
    final filteredBills = allBills
        .where(
          (bill) =>
              bill.paymentType.trim().toLowerCase() ==
              _paymentFilter.toLowerCase(),
        )
        .where((bill) => _isInPeriod(bill.createdAt))
        .toList(growable: false);

    final totalSales = filteredBills.fold<double>(
      0,
      (sum, bill) => sum + bill.grandTotal,
    );
    final avgBill = filteredBills.isEmpty
        ? 0.0
        : totalSales / filteredBills.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _header(totalSales: totalSales, avgBill: avgBill),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _periodRow(),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _paymentChip('Cash'),
                const SizedBox(width: 8),
                _paymentChip('Online'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Text(
                  'Recent Sales',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  '${filteredBills.length} bills',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (filteredBills.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: _EmptySalesCard(),
            )
          else
            ...filteredBills.map((bill) => _salesTile(context, bill)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _header({required double totalSales, required double avgBill}) {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 18),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(CupertinoIcons.back, color: Colors.black),
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      'Sales',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _periodTitle(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 3),
            Text(
              'Rs.${totalSales.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    _periodLabel(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Avg Bill Rs.${avgBill.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _periodRow() {
    return Row(
      children: [
        _periodChip(_SalesPeriod.daily, 'Daily'),
        const SizedBox(width: 8),
        _periodChip(_SalesPeriod.weekly, 'Weekly'),
        const SizedBox(width: 8),
        _periodChip(_SalesPeriod.monthly, 'Monthly'),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _pickDate,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            side: BorderSide(color: Colors.grey.shade300),
          ),
          icon: const Icon(CupertinoIcons.calendar, size: 18),
        ),
      ],
    );
  }

  Widget _periodChip(_SalesPeriod period, String label) {
    final selected = _period == period;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _period = period),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.grey.shade300,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _paymentChip(String label) {
    final selected = _paymentFilter == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentFilter = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.grey.shade300,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _periodTitle() {
    switch (_period) {
      case _SalesPeriod.daily:
        return 'Total Daily Sales';
      case _SalesPeriod.weekly:
        return 'Total Weekly Sales';
      case _SalesPeriod.monthly:
        return 'Total Monthly Sales';
    }
  }

  String _periodLabel() {
    switch (_period) {
      case _SalesPeriod.daily:
        return _formatDay(_anchorDate);
      case _SalesPeriod.weekly:
        final start = _weekStart(_anchorDate);
        final end = start.add(const Duration(days: 6));
        return '${_formatDay(start)} - ${_formatDay(end)}';
      case _SalesPeriod.monthly:
        const months = <String>[
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        return '${months[_anchorDate.month - 1]} ${_anchorDate.year}';
    }
  }

  bool _isInPeriod(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    switch (_period) {
      case _SalesPeriod.daily:
        return target ==
            DateTime(_anchorDate.year, _anchorDate.month, _anchorDate.day);
      case _SalesPeriod.weekly:
        final start = _weekStart(_anchorDate);
        final end = start.add(const Duration(days: 6));
        return !target.isBefore(start) && !target.isAfter(end);
      case _SalesPeriod.monthly:
        return target.year == _anchorDate.year &&
            target.month == _anchorDate.month;
    }
  }

  DateTime _weekStart(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: date.weekday - 1));
  }

  String _formatDay(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchorDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _anchorDate = picked);
  }

  Widget _salesTile(BuildContext context, Bill bill) {
    final customerLabel = bill.customerName.trim().isNotEmpty
        ? bill.customerName.trim()
        : (bill.customerPhone.trim().isNotEmpty
              ? bill.customerPhone.trim()
              : 'Walk-in Customer');
    final firstService = bill.lines.isNotEmpty
        ? bill.lines.first.serviceName
        : 'No service';
    final dateText =
        '${bill.createdAt.day.toString().padLeft(2, '0')}-${bill.createdAt.month.toString().padLeft(2, '0')}-${bill.createdAt.year}';
    final timeText =
        '${bill.createdAt.hour.toString().padLeft(2, '0')}:${bill.createdAt.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: InkWell(
        onTap: () {
          Navigator.of(
            context,
          ).pushNamed(AppRoutes.billDetails, arguments: bill.id);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 86,
                child: Text(
                  '$timeText\n$dateText',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      firstService,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    bill.paymentType,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Rs.${bill.grandTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySalesCard extends StatelessWidget {
  const _EmptySalesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'No sales found for selected filters.',
        style: TextStyle(fontSize: 13, color: Colors.black54),
      ),
    );
  }
}

enum _SalesPeriod { daily, weekly, monthly }
