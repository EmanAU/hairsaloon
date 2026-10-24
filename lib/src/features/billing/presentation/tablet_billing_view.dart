import 'package:flutter/material.dart';
import '../../services/domain/entities/service_item.dart';

/// Two independently scrolling panes keep checkout visible on a landscape tablet.
class TabletBillingView extends StatelessWidget {
  const TabletBillingView({
    super.key,
    required this.services,
    required this.selectedServices,
    required this.categories,
    required this.category,
    required this.onCategory,
    required this.onSearch,
    required this.priceOf,
    required this.onToggle,
    required this.onEditPrice,
    required this.subTotal,
    required this.tax,
    required this.taxPercent,
    required this.discount,
    required this.total,
    required this.onDiscount,
    required this.onClear,
    required this.onCheckout,
    required this.onSavedBills,
    required this.onAddService,
    required this.customer,
  });

  final List<ServiceItem> services, selectedServices;
  final List<String> categories;
  final String category;
  final ValueChanged<String> onCategory, onSearch;
  final double Function(ServiceItem) priceOf;
  final ValueChanged<ServiceItem> onToggle, onEditPrice;
  final double subTotal, tax, taxPercent, discount, total;
  final VoidCallback onDiscount, onClear, onSavedBills, onAddService;
  final VoidCallback? onCheckout;
  final Widget customer;
  static const lime = Color(0xFFC7F52B);
  static const canvas = Color(0xFFF5F6F0);
  static const ink = Color(0xFF101B2B);
  static const muted = Color(0xFF738093);

  String _money(double value) =>
      'Rs ${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2)}';

  @override
  Widget build(BuildContext context) => Material(
    color: canvas,
    child: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 760) return _mobile(context);
          final orderWidth = (constraints.maxWidth * .31).clamp(320.0, 400.0);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'New Ticket',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: ink,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Chip(
                            label: Text('${selectedServices.length} Items'),
                            backgroundColor: Colors.white,
                            side: BorderSide.none,
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Saved Bills',
                            onPressed: onSavedBills,
                            icon: const Icon(Icons.receipt_long_outlined),
                          ),
                          IconButton(
                            tooltip: 'Add service',
                            onPressed: onAddService,
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                      const Text(
                        'Select services to add to the current order.',
                        style: TextStyle(color: muted),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        onChanged: onSearch,
                        decoration: InputDecoration(
                          hintText: 'Search services...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE0E4E9),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 42,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) => ChoiceChip(
                            label: Text(
                              categories[index] == 'All'
                                  ? 'All Services'
                                  : categories[index],
                            ),
                            selected: category == categories[index],
                            onSelected: (_) => onCategory(categories[index]),
                            showCheckmark: false,
                            selectedColor: lime,
                            backgroundColor: Colors.white,
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: ink,
                            ),
                            shape: const StadiumBorder(),
                            side: BorderSide(
                              color: category == categories[index]
                                  ? lime
                                  : const Color(0xFFE0E4E9),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, grid) {
                            final columns = (grid.maxWidth / 190).floor().clamp(
                              2,
                              5,
                            );
                            if (services.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.content_cut,
                                      size: 36,
                                      color: muted,
                                    ),
                                    const SizedBox(height: 12),
                                    const Text('No matching services'),
                                    TextButton(
                                      onPressed: onAddService,
                                      child: const Text('Add a service'),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return GridView.builder(
                              key: const ValueKey('tablet-service-grid'),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    mainAxisExtent: 170,
                                    crossAxisSpacing: 14,
                                    mainAxisSpacing: 14,
                                  ),
                              itemCount: services.length,
                              itemBuilder: (context, index) {
                                final service = services[index];
                                final selected = selectedServices.any(
                                  (item) => item.id == service.id,
                                );
                                return Semantics(
                                  selected: selected,
                                  button: true,
                                  label:
                                      '${service.subcategory}, ${_money(priceOf(service))}',
                                  child: Material(
                                    color: selected
                                        ? const Color(0xFFF0F8D8)
                                        : canvas,
                                    borderRadius: BorderRadius.circular(16),
                                    child: InkWell(
                                      onTap: () => onToggle(service),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        padding: const EdgeInsets.all(18),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: selected
                                                ? const Color(0xFF94B619)
                                                : const Color(0xFFDEE3E9),
                                            width: selected ? 1.8 : 1,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              service.subcategory,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w700,
                                                color: ink,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              service.category,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: muted,
                                              ),
                                            ),
                                            const Spacer(),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    _money(priceOf(service)),
                                                    style: const TextStyle(
                                                      fontSize: 19,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: ink,
                                                    ),
                                                  ),
                                                ),
                                                Icon(
                                                  selected
                                                      ? Icons.check_circle
                                                      : Icons
                                                            .add_circle_outline,
                                                  size: 22,
                                                  color: selected
                                                      ? const Color(0xFF668400)
                                                      : muted,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const VerticalDivider(width: 1, color: Color(0xFFE0E4E9)),
              SizedBox(
                width: orderWidth,
                child: ColoredBox(
                  color: Colors.white,
                  child: _OrderHeight(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Current Order',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: ink,
                                  ),
                                ),
                              ),
                              Text(
                                '${selectedServices.length} services',
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: canvas,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: customer,
                              ),
                              const SizedBox(height: 18),
                              if (selectedServices.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 26),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.shopping_bag_outlined,
                                        size: 32,
                                        color: muted,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Your ticket is empty',
                                        style: TextStyle(color: muted),
                                      ),
                                    ],
                                  ),
                                ),
                              for (final service in selectedServices)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              service.subcategory,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              service.category,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => onEditPrice(service),
                                        child: Text(_money(priceOf(service))),
                                      ),
                                      IconButton(
                                        tooltip:
                                            'Remove ${service.subcategory}',
                                        onPressed: () => onToggle(service),
                                        icon: const Icon(Icons.close, size: 18),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              _amount('Sub Total', subTotal),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextButton.icon(
                                      style: TextButton.styleFrom(
                                        alignment: Alignment.centerLeft,
                                        padding: EdgeInsets.zero,
                                      ),
                                      onPressed: onDiscount,
                                      icon: const Icon(
                                        Icons.sell_outlined,
                                        size: 16,
                                      ),
                                      label: const Text('Discount'),
                                    ),
                                  ),
                                  Text(
                                    '-${_money(discount)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              _amount(
                                'Tax ${taxPercent.toStringAsFixed(0)}%',
                                tax,
                              ),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: lime,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    const Text(
                                      'Total',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        _money(total),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: onClear,
                                      child: const Text('Clear'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: lime,
                                        foregroundColor: ink,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 18,
                                        ),
                                      ),
                                      onPressed: onCheckout,
                                      icon: const Icon(
                                        Icons.arrow_forward,
                                        size: 18,
                                      ),
                                      label: Text(
                                        onCheckout == null
                                            ? 'Saving...'
                                            : 'Checkout',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget _amount(String label, double value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: muted)),
        ),
        Text(
          _money(value),
          style: const TextStyle(fontWeight: FontWeight.w600, color: ink),
        ),
      ],
    ),
  );

  Widget _mobile(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'New Ticket',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Saved Bills',
              onPressed: onSavedBills,
              icon: const Icon(Icons.receipt_long_outlined),
            ),
            IconButton(
              tooltip: 'Add service',
              onPressed: onAddService,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: customer,
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: onSearch,
              decoration: InputDecoration(
                hintText: 'Search services...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFDEE4EA)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, index) => ChoiceChip(
                  label: Text(
                    categories[index] == 'All'
                        ? 'All Services'
                        : categories[index],
                  ),
                  selected: category == categories[index],
                  onSelected: (_) => onCategory(categories[index]),
                  selectedColor: lime,
                  showCheckmark: false,
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (services.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('No matching services.'),
              ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: services.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 135,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (_, index) {
                final service = services[index];
                final selected = selectedServices.any(
                  (item) => item.id == service.id,
                );
                return Material(
                  color: selected ? const Color(0xFFF0F8D8) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: () => onToggle(service),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF94B619)
                              : const Color(0xFFDEE4EA),
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service.subcategory,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            service.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: muted, fontSize: 11),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _money(priceOf(service)),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Icon(
                                selected
                                    ? Icons.check_circle
                                    : Icons.add_circle_outline,
                                size: 19,
                                color: selected
                                    ? const Color(0xFF668400)
                                    : muted,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Current Order · ${selectedServices.length} services',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            for (final service in selectedServices)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(service.subcategory),
                subtitle: TextButton(
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () => onEditPrice(service),
                  child: Text('${_money(priceOf(service))} · Edit price'),
                ),
                trailing: IconButton(
                  tooltip: 'Remove ${service.subcategory}',
                  onPressed: () => onToggle(service),
                  icon: const Icon(Icons.close),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: onDiscount,
                    icon: const Icon(Icons.sell_outlined, size: 17),
                    label: Text(
                      discount > 0
                          ? 'Discount −${_money(discount)}'
                          : 'Add discount',
                    ),
                  ),
                ),
                TextButton(onPressed: onClear, child: const Text('Clear')),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _money(total),
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Tax ${_money(tax)} included',
                        style: const TextStyle(fontSize: 11, color: muted),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: lime,
                    foregroundColor: ink,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                  ),
                  onPressed: onCheckout,
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: Text(
                    onCheckout == null ? 'Please wait...' : 'Checkout',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

class _OrderHeight extends StatelessWidget {
  const _OrderHeight({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxHeight < 480
        ? SingleChildScrollView(child: SizedBox(height: 650, child: child))
        : child,
  );
}
