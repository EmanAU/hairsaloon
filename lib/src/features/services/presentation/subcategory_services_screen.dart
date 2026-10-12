import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/features/services/domain/entities/service_item.dart';
import 'package:hairsaloon/src/features/services/presentation/service_details_screen.dart';
import 'package:hairsaloon/src/features/services/presentation/state/services_store.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';
import 'package:provider/provider.dart';

class SubcategoryServicesScreen extends StatelessWidget {
  const SubcategoryServicesScreen({
    super.key,
    required this.category,
    required this.subcategory,
  });

  final String category;
  final String subcategory;

  @override
  Widget build(BuildContext context) {
    final services =
        context
            .watch<ServicesStore>()
            .services
            .where(
              (s) => s.category == category && s.subcategory == subcategory,
            )
            .toList()
          ..sort((a, b) {
            final g = a.gender.compareTo(b.gender);
            if (g != 0) return g;
            return a.ageGroup.compareTo(b.ageGroup);
          });

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
          'Services',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B6B6B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subcategory,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Services: ${services.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF555555),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (services.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 30),
                child: Text(
                  'No service found for this subcategory.\nAdd from Rate List → New Service.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            )
          else
            ...services.map((s) => _ServiceRow(item: s)),
        ],
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.item});

  final ServiceItem item;

  @override
  Widget build(BuildContext context) {
    final label = '${item.gender} • ${item.ageGroup}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B6B6B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.subcategory,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Rs.${item.price.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 6),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'edit') {
                final updated = await Navigator.of(context).push<ServiceItem>(
                  MaterialPageRoute(
                    builder: (_) => ServiceDetailsScreen(item: item),
                  ),
                );
                if (updated == null) return;
                if (!context.mounted) return;
                await context.read<ServicesStore>().updateService(updated);
                return;
              }
              if (value == 'delete') {
                await context.read<ServicesStore>().deleteService(item.id);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
            icon: const Icon(CupertinoIcons.ellipsis_vertical, size: 18),
          ),
        ],
      ),
    );
  }
}
