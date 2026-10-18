import 'package:flutter/material.dart';
import '../../domain/online_models.dart';
import '../../domain/online_repository.dart';

class BusinessPhoto extends StatefulWidget {
  const BusinessPhoto({
    super.key,
    required this.repository,
    required this.business,
  });
  final OnlineRepository repository;
  final SalonBusiness business;
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
    builder: (context, snapshot) => snapshot.data == null
        ? const Icon(
            Icons.storefront_outlined,
            size: 30,
            color: Color(0xFF34441D),
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              snapshot.data!,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stack) =>
                  const Icon(Icons.storefront_outlined, size: 30),
            ),
          ),
  );
}
