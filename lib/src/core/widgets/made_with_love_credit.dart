import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hairsaloon/src/theme/app_colors.dart';

/// "Made with ♥ by Intelligement" footer credit.
class MadeWithLoveCredit extends StatelessWidget {
  const MadeWithLoveCredit({
    super.key,
    required this.onTap,
    this.fontSize = 10.5,
    this.color = AppColors.textSecondary,
  });

  final VoidCallback onTap;
  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
    );
    return Semantics(
      label: 'Made with love by Intelligement',
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Made with ', style: style),
          Icon(
            CupertinoIcons.heart_fill,
            size: fontSize + 0.5,
            color: AppColors.danger,
          ),
          Text(' by ', style: style),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: Text(
              'Intelligement',
              style: style.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
