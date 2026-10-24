import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../domain/online_models.dart';
import '../../domain/online_repository.dart';

class BusinessPhoto extends StatefulWidget {
  const BusinessPhoto({
    super.key,
    required this.repository,
    required this.business,
    this.width = 48,
    this.height = 48,
    this.borderRadius = 8,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.storefront_outlined,
  });

  final OnlineRepository repository;
  final SalonBusiness business;
  final double width;
  final double height;
  final double borderRadius;
  final BoxFit fit;
  final IconData placeholderIcon;

  @override
  State<BusinessPhoto> createState() => _BusinessPhotoState();
}

class _BusinessPhotoState extends State<BusinessPhoto> {
  late Future<String?> _url = widget.repository.businessPhoto(widget.business);

  @override
  void didUpdateWidget(covariant BusinessPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.business.logoPath != widget.business.logoPath ||
        oldWidget.business.id != widget.business.id) {
      _url = widget.repository.businessPhoto(widget.business);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: _url,
    builder: (context, snapshot) {
      final url = snapshot.data;
      if (url == null) {
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.homeSage,
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
            child: Icon(
              widget.placeholderIcon,
              size: (widget.height * 0.35).clamp(22, 48),
              color: AppColors.homeOlive,
            ),
          ),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Image.network(
          url,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (_, __, ___) => SizedBox(
            width: widget.width,
            height: widget.height,
            child: ColoredBox(
              color: AppColors.homeSage,
              child: Icon(widget.placeholderIcon, color: AppColors.homeOlive),
            ),
          ),
        ),
      );
    },
  );
}
