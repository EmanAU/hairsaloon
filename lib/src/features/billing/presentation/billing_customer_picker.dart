import 'package:hairsaloon/src/core/utils/pk_phone.dart';
import 'package:flutter/material.dart';
import '../domain/entities/customer_contact.dart';

class BillingCustomerPicker extends StatelessWidget {
  const BillingCustomerPicker({
    super.key,
    required this.searching,
    required this.controller,
    required this.selected,
    required this.matches,
    required this.onMode,
    required this.onChanged,
    required this.onSelect,
    required this.onAdd,
  });
  final bool searching;
  final TextEditingController controller;
  final CustomerContact? selected;
  final List<CustomerContact> matches;
  final ValueChanged<bool> onMode;
  final ValueChanged<String> onChanged;
  final ValueChanged<CustomerContact> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'CUSTOMER',
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 1.3,
          fontWeight: FontWeight.w700,
          color: Color(0xFF738093),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _mode(
              'Walk-in',
              Icons.person_outline,
              !searching,
              () => onMode(false),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _mode('Search', Icons.search, searching, () => onMode(true)),
          ),
        ],
      ),
      const SizedBox(height: 14),
      if (!searching)
        const Text(
          'Walk-in customer · no phone required',
          style: TextStyle(fontSize: 12, color: Color(0xFF738093)),
        )
      else ...[
        TextField(
          key: const ValueKey('customer-search'),
          controller: controller,
          keyboardType: TextInputType.phone,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: 'Search phone number',
            prefixIcon: const Icon(Icons.search_rounded, size: 21),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear customer search',
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                    icon: const Icon(Icons.close, size: 18),
                  ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFDEE4EA)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFDEE4EA)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFF94B619),
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (selected != null)
          _person(selected!, true)
        else if (controller.text.trim().isEmpty)
          const Text(
            'Find a saved customer, or add someone new.',
            style: TextStyle(fontSize: 12, color: Color(0xFF738093)),
          )
        else if (matches.isNotEmpty)
          ...matches.take(4).map((person) => _person(person, false))
        else
          const Text(
            'No customer found for this number.',
            style: TextStyle(fontSize: 12, color: Color(0xFF738093)),
          ),
        if (selected == null && matches.isEmpty)
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: const Text('Add New Customer'),
          ),
      ],
    ],
  );
  Widget _person(CustomerContact person, bool checked) => Card(
    margin: const EdgeInsets.only(top: 6),
    color: Colors.white,
    elevation: 0,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFF0F5DE),
        child: Icon(Icons.person_outline, color: Color(0xFF506321)),
      ),
      title: Text(
        person.name.isEmpty ? 'Saved customer' : person.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(PkPhone.localNumber(person.phone)),
      trailing: Icon(
        checked ? Icons.check_circle : Icons.chevron_right,
        color: const Color(0xFF668400),
      ),
      onTap: () => onSelect(person),
    ),
  );
  Widget _mode(
    String label,
    IconData icon,
    bool selected,
    VoidCallback onTap,
  ) => OutlinedButton.icon(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      backgroundColor: selected ? const Color(0xFFC7F52B) : Colors.white,
      foregroundColor: const Color(0xFF101B2B),
      side: BorderSide(
        color: selected ? const Color(0xFFC7F52B) : const Color(0xFFDEE4EA),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(vertical: 12),
    ),
    icon: Icon(icon, size: 18),
    label: Text(label),
  );
}
