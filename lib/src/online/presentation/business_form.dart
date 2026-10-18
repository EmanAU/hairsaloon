import 'package:flutter/material.dart';
import '../../core/utils/pk_phone.dart';
import '../domain/online_models.dart';
import '../domain/online_repository.dart';
import 'widgets/online_widgets.dart';

class BusinessForm extends StatefulWidget {
  const BusinessForm({super.key, required this.repository, this.business});
  final OnlineRepository repository;
  final SalonBusiness? business;

  @override
  State<BusinessForm> createState() => _BusinessFormState();
}

class _BusinessFormState extends State<BusinessForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.business?.name);
  late final _phone = TextEditingController(text: widget.business?.phone);
  late final _type = TextEditingController(
    text: widget.business?.type ?? 'Salon',
  );
  late final _city = TextEditingController(text: widget.business?.city);
  late final _area = TextEditingController(text: widget.business?.area);
  late final _address = TextEditingController(text: widget.business?.address);

  @override
  void dispose() {
    for (final field in [_name, _phone, _type, _city, _area, _address]) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await widget.repository.saveBusiness(
      id: widget.business?.id,
      name: _name.text,
      phone: _phone.text,
      type: _type.text,
      city: _city.text,
      area: _area.text,
      address: _address.text,
    );
    if (mounted) Navigator.pop(context, true);
  }

  Widget _field(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      maxLength: label == 'Business name' ? 160 : 250,
      decoration: InputDecoration(labelText: label),
      validator: (value) =>
          value == null || value.trim().isEmpty ? 'Required' : null,
    ),
  );

  @override
  Widget build(BuildContext context) => OnlinePage(
    title: widget.business == null ? 'Register business' : 'Edit business',
    children: [
      if (widget.business == null)
        const Padding(
          padding: EdgeInsets.only(bottom: 20),
          child: Text(
            'Your business becomes visible to customers after admin approval.',
          ),
        ),
      Form(
        key: _form,
        child: Column(
          children: [
            _field(_name, 'Business name'),
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Business phone'),
              keyboardType: TextInputType.phone,
              validator: (value) => PkPhone.validationError(value),
            ),
            const SizedBox(height: 16),
            _field(_type, 'Business type'),
            _field(_city, 'City'),
            _field(_area, 'Area'),
            _field(_address, 'Address'),
            ActionButton(
              label: 'Save business',
              onPressed: _save,
              icon: Icons.check,
            ),
          ],
        ),
      ),
    ],
  );
}
