import 'package:flutter/material.dart';

/// Dragable before/after photo comparison.
class BeforeAfterSlider extends StatefulWidget {
  const BeforeAfterSlider({
    super.key,
    required this.beforeUrl,
    required this.afterUrl,
    this.height = 280,
  });

  final String beforeUrl;
  final String afterUrl;
  final double height;

  @override
  State<BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _BeforeAfterSliderState extends State<BeforeAfterSlider> {
  double _ratio = 0.5;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: widget.height,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final split = width * _ratio;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _ratio = (details.localPosition.dx / width).clamp(
                        0.05,
                        0.95,
                      );
                    });
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        widget.afterUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, stack) => const ColoredBox(
                          color: Color(0xFFF0F5DE),
                          child: Center(child: Text('After unavailable')),
                        ),
                      ),
                      ClipRect(
                        clipper: _LeftClipper(split),
                        child: Image.network(
                          widget.beforeUrl,
                          fit: BoxFit.cover,
                          width: width,
                          height: widget.height,
                          errorBuilder: (_, error, stack) => const ColoredBox(
                            color: Color(0xFFE3E7EC),
                            child: Center(child: Text('Before unavailable')),
                          ),
                        ),
                      ),
                      Positioned(
                        left: split - 18,
                        top: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          child: Center(
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF668400),
                                  width: 2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    blurRadius: 6,
                                    color: Color(0x33000000),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.compare_arrows,
                                size: 18,
                                color: Color(0xFF668400),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Positioned(
                        left: 10,
                        top: 10,
                        child: _Badge(label: 'BEFORE'),
                      ),
                      const Positioned(
                        right: 10,
                        top: 10,
                        child: _Badge(label: 'AFTER'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Drag to compare before and after',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF718094), fontSize: 12),
        ),
      ],
    );
  }
}

class _LeftClipper extends CustomClipper<Rect> {
  _LeftClipper(this.width);
  final double width;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, width, size.height);

  @override
  bool shouldReclip(_LeftClipper oldClipper) => oldClipper.width != width;
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xCC14202D),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
