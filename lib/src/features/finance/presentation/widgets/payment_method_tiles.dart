import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../theme/app_colors.dart';

/// Empty selection means all methods; several methods can be selected together.
class PaymentMethodTiles extends StatelessWidget {
  const PaymentMethodTiles({
    super.key,
    required this.methods,
    required this.selected,
    required this.onChanged,
  });
  final Iterable<String> methods;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  static String normalize(String value) => value.trim().toLowerCase();
  static bool matches(String value, Set<String> selected) =>
      selected.isEmpty || selected.contains(normalize(value));
  @override
  Widget build(BuildContext context) {
    final unique = <String, String>{};
    for (final method in ['Cash', 'Card', 'Online', ...methods]) {
      if (method.trim().isNotEmpty) {
        unique.putIfAbsent(normalize(method), () => method.trim());
      }
    }
    final entries = <String, String>{'': 'All', ...unique};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment method',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in entries.entries)
              OutlinedButton.icon(
                onPressed: () {
                  if (entry.key.isEmpty) {
                    onChanged({});
                    return;
                  }
                  final next = {...selected};
                  if (!next.add(entry.key)) next.remove(entry.key);
                  onChanged(next);
                },
                icon: Icon(
                  entry.key.isEmpty
                      ? CupertinoIcons.list_bullet
                      : entry.key.contains('cash')
                      ? CupertinoIcons.money_dollar_circle
                      : entry.key.contains('card')
                      ? CupertinoIcons.creditcard
                      : CupertinoIcons.device_phone_portrait,
                  size: 17,
                ),
                label: Text(entry.value),
                style: OutlinedButton.styleFrom(
                  backgroundColor:
                      (entry.key.isEmpty
                          ? selected.isEmpty
                          : selected.contains(entry.key))
                      ? const Color(0xFFEDF8CD)
                      : Colors.white,
                  foregroundColor: AppColors.homeInk,
                  side: BorderSide(
                    color:
                        (entry.key.isEmpty
                            ? selected.isEmpty
                            : selected.contains(entry.key))
                        ? AppColors.homeOlive
                        : AppColors.border,
                  ),
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
