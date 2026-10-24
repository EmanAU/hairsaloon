import 'package:flutter/material.dart';
import '../../core/services/toast_service.dart';
import '../domain/online_models.dart';
import '../domain/online_repository.dart';
import 'service_customer_view_editor.dart';
import 'widgets/online_widgets.dart';

class OnlineRateList extends StatefulWidget {
  const OnlineRateList({
    super.key,
    required this.repository,
    required this.businessId,
  });
  final OnlineRepository repository;
  final String businessId;

  @override
  State<OnlineRateList> createState() => _OnlineRateListState();
}

class _OnlineRateListState extends State<OnlineRateList> {
  late Future<List<SalonService>> _services = _load();

  Future<List<SalonService>> _load() async {
    try {
      await widget.repository.ensureBusinessServices(widget.businessId);
    } catch (_) {
      // Seeding is best-effort; still show whatever services exist.
    }
    return widget.repository.services(widget.businessId, includeInactive: true);
  }

  void _refresh() => setState(() => _services = _load());

  Future<void> _edit([SalonService? service]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _ServiceForm(
          repository: widget.repository,
          businessId: widget.businessId,
          service: service,
        ),
      ),
    );
    if (saved == true && context.mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) => OnlinePage(
    title: 'Online rate list',
    children: [
      const Text(
        'These services appear in the customer app when your business is active.',
      ),
      ActionButton(label: 'Add service', icon: Icons.add, onPressed: _edit),
      RemoteContent<List<SalonService>>(
        future: _services,
        onRetry: _refresh,
        builder: (services) => Column(
          children: [
            if (services.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Default services will appear after the salon is created. Pull to refresh or add your own.',
                ),
              ),
            for (final service in services)
              Card(
                child: ListTile(
                  title: Text(service.name),
                  subtitle: Text(
                    '${service.category} · ${service.isActive ? 'Visible' : 'Hidden'}',
                  ),
                  trailing: Text(service.price.toStringAsFixed(2)),
                  onTap: () => _edit(service),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class _ServiceForm extends StatefulWidget {
  const _ServiceForm({
    required this.repository,
    required this.businessId,
    this.service,
  });
  final OnlineRepository repository;
  final String businessId;
  final SalonService? service;

  @override
  State<_ServiceForm> createState() => _ServiceFormState();
}

class _ServiceFormState extends State<_ServiceForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.service?.name);
  late final _category = TextEditingController(text: widget.service?.category);
  late final _description = TextEditingController(
    text: widget.service?.description,
  );
  late final _price = TextEditingController(
    text: widget.service?.price.toStringAsFixed(2),
  );
  late bool _active = widget.service?.isActive ?? true;

  @override
  void dispose() {
    for (final controller in [_name, _category, _description, _price]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await widget.repository.saveService(
      businessId: widget.businessId,
      id: widget.service?.id,
      name: _name.text,
      category: _category.text,
      description: _description.text,
      price: double.parse(_price.text.trim()),
      isActive: _active,
    );
    if (mounted) {
      ToastService.success('Service saved', context);
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) => OnlinePage(
    title: widget.service == null ? 'Add service' : 'Edit service',
    children: [
      Form(
        key: _form,
        child: Column(
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Service name'),
              maxLength: 160,
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            TextFormField(
              controller: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              maxLength: 120,
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            TextFormField(
              controller: _price,
              decoration: const InputDecoration(labelText: 'Price'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                final price = double.tryParse(value?.trim() ?? '');
                return price == null ||
                        !price.isFinite ||
                        price < 0 ||
                        price >= 10000000000 ||
                        !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value!.trim())
                    ? 'Enter a valid price with up to 2 decimal places'
                    : null;
              },
            ),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Description'),
              minLines: 3,
              maxLines: 6,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Visible to customers'),
              value: _active,
              onChanged: (value) => setState(() => _active = value),
            ),
            ActionButton(
              label: 'Save service',
              icon: Icons.check,
              onPressed: _save,
            ),
            if (widget.service != null)
              ActionButton(
                label: 'Customer view',
                icon: Icons.article_outlined,
                onPressed: () async {
                  final saved = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ServiceCustomerViewEditor(
                        repository: widget.repository,
                        businessId: widget.businessId,
                        service: widget.service!,
                      ),
                    ),
                  );
                  if (saved == true && context.mounted) {
                    Navigator.pop(context, true);
                  }
                },
              ),
          ],
        ),
      ),
    ],
  );
}
