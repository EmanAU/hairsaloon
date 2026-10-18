import 'package:flutter/material.dart';

class WorkspaceCard extends StatelessWidget {
  const WorkspaceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.leading,
  });
  final String title, subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: Color(0xFFE3E7EC)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                leading ?? Icon(icon, size: 30, color: const Color(0xFF34441D)),
                const Spacer(),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 20,
                  color: Color(0xFF718094),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF14202D),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF718094), height: 1.5),
            ),
          ],
        ),
      ),
    ),
  );
}

class WorkspaceCards extends StatelessWidget {
  const WorkspaceCards({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final width = size.maxWidth >= 600
          ? (size.maxWidth - 16) / 2
          : size.maxWidth;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: children
            .map((child) => SizedBox(width: width, child: child))
            .toList(),
      );
    },
  );
}
