import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:convert';
import '../../theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/toast_service.dart';
import '../../core/utils/pk_phone.dart';
import '../../features/business_profile/domain/business_options.dart';
import '../domain/online_models.dart';
import '../domain/online_repository.dart';
import 'widgets/online_widgets.dart';

class BusinessForm extends StatefulWidget {
  const BusinessForm({
    super.key,
    required this.repository,
    this.business,
    this.onRegistered,
  });
  final OnlineRepository repository;
  final SalonBusiness? business;
  final ValueChanged<SalonBusiness>? onRegistered;
  @override
  State<BusinessForm> createState() => _BusinessFormState();
}

class _BusinessFormState extends State<BusinessForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.business?.name);
  late final _phone = TextEditingController(
    text: PkPhone.localNumber(widget.business?.phone),
  );
  late String? _city = widget.business == null
      ? null
      : BusinessOptions.resolve(
          widget.business?.city,
          BusinessOptions.cities,
          BusinessOptions.defaultCity,
        );
  late final _area = TextEditingController(text: widget.business?.area);
  late final _address = TextEditingController(text: widget.business?.address);
  late String _type =
      widget.business?.type ?? BusinessOptions.defaultBusinessType;
  late String? _savedId = widget.business?.id;
  late final _photoUrl = widget.business == null
      ? Future<String?>.value(null)
      : widget.repository.businessPhoto(widget.business!);
  Uint8List? _photo;
  String? _extension;
  bool _saving = false;
  bool _picking = false;
  String? _photoError;
  String? _savedDetails;
  bool _remembered = false;
  String get _detailsStamp => jsonEncode([
    _name.text,
    _phone.text,
    _type,
    _city,
    _area.text,
    _address.text,
  ]);

  @override
  void dispose() {
    for (final field in [_name, _phone, _area, _address]) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    setState(() => _picking = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (file == null) return;
      if (await file.length() > 20 * 1024 * 1024) {
        throw const OnlineFailure(
          'Choose a JPG, PNG or WebP photo up to 2 MB.',
        );
      }
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 512);
      final frame = await codec.getNextFrame();
      final normalized = await frame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      frame.image.dispose();
      codec.dispose();
      if (normalized == null || normalized.lengthInBytes > 2 * 1024 * 1024) {
        throw const OnlineFailure('Choose a smaller photo up to 2 MB.');
      }
      if (mounted) {
        setState(() {
          _photo = normalized.buffer.asUint8List();
          _extension = 'png';
          _photoError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          error is OnlineFailure
              ? error.message
              : 'Could not open photo. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _picking || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      // Retain the ID if a photo upload fails, so retry updates this business.
      if (_savedId == null || _savedDetails != _detailsStamp) {
        _savedId = await widget.repository.saveBusiness(
          id: _savedId,
          name: _name.text,
          phone: _phone.text,
          type: _type,
          city: _city!,
          area: _area.text,
          address: _address.text,
        );
        _savedDetails = _detailsStamp;
      }
      var photoFailed = false;
      if (_photo != null) {
        try {
          await widget.repository.uploadBusinessPhoto(
            _savedId!,
            _photo!,
            _extension!,
          );
        } on PhotoUploadFailure catch (error) {
          photoFailed = true;
          if (mounted) setState(() => _photoError = error.message);
        } on OnlineFailure catch (error) {
          photoFailed = true;
          if (mounted) setState(() => _photoError = error.message);
        } catch (_) {
          photoFailed = true;
          if (mounted) {
            setState(
              () => _photoError =
                  'Business details saved. Photo upload is unavailable; retry it or continue without a photo.',
            );
          }
        }
      }
      if (!mounted) return;
      if (widget.business == null && !_remembered) {
        _remembered = true;
        widget.onRegistered?.call(
          SalonBusiness(
            id: _savedId!,
            name: _name.text.trim(),
            phone: PkPhone.normalize(_phone.text),
            type: _type,
            city: _city!,
            area: _area.text.trim(),
            address: _address.text.trim(),
            isActive: false,
          ),
        );
      }
      if (photoFailed) {
        // Keep the form open so the owner can retry the photo upload.
        return;
      }
      ToastService.success('Business saved', context);
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String label, IconData icon, {String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 21, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.homeCanvas,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      );

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLength = 120,
    int lines = 1,
  }) => TextFormField(
    controller: controller,
    textCapitalization: TextCapitalization.words,
    maxLines: lines,
    inputFormatters: [LengthLimitingTextInputFormatter(maxLength)],
    decoration: _decoration(label, icon),
    validator: (value) => (value?.trim().isEmpty ?? true) ? 'Required' : null,
  );

  Widget _photoPicker() => Column(
    children: [
      FutureBuilder<String?>(
        future: _photoUrl,
        builder: (context, snapshot) {
          final ImageProvider? image = _photo != null
              ? MemoryImage(_photo!)
              : snapshot.data == null
              ? null
              : NetworkImage(snapshot.data!);
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 88,
              width: 88,
              child: image == null
                  ? const ColoredBox(
                      color: AppColors.homeSage,
                      child: Icon(Icons.storefront_outlined, size: 36),
                    )
                  : Image(
                      image: image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, stack) =>
                          const Icon(Icons.storefront_outlined, size: 36),
                    ),
            ),
          );
        },
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _picking ? null : _choosePhoto,
        child: Text(
          _photo != null || widget.business?.logoPath != null
              ? 'Change business photo'
              : 'Add business photo',
        ),
      ),
      const Text(
        'Up to 2 MB',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          widget.business == null ? 'Register business' : 'Edit business',
        ),
      ),
      body: OnlineShell.centered(
        maxWidth: OnlineShell.formMaxWidth,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          child: AbsorbPointer(
            absorbing: _saving,
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _photoPicker(),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, size) {
                      final width = size.maxWidth >= OnlineShell.twoColMinWidth
                          ? (size.maxWidth - 16) / 2
                          : size.maxWidth;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 18,
                        children: [
                          SizedBox(
                            width: width,
                            child: _field(
                              _name,
                              'Business name',
                              Icons.storefront_outlined,
                              maxLength: 160,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: TextFormField(
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [PkPhoneInputFormatter()],
                              decoration: _decoration(
                                'Business phone',
                                Icons.phone_outlined,
                                hint: '03465501748',
                              ),
                              validator: PkPhone.localValidationError,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: DropdownButtonFormField<String>(
                              initialValue: _type,
                              isExpanded: true,
                              decoration: _decoration(
                                'Business type',
                                Icons.category_outlined,
                              ),
                              items:
                                  {
                                        ...BusinessOptions.businessTypes,
                                        if (!BusinessOptions.businessTypes
                                            .contains(_type))
                                          _type,
                                      }
                                      .map(
                                        (value) => DropdownMenuItem(
                                          value: value,
                                          child: Text(
                                            value,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _type = value);
                                }
                              },
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: DropdownButtonFormField<String>(
                              initialValue: _city,
                              isExpanded: true,
                              decoration: _decoration(
                                'City',
                                Icons.location_city_outlined,
                              ),
                              items: BusinessOptions.cities
                                  .map(
                                    (city) => DropdownMenuItem(
                                      value: city,
                                      child: Text(city),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => _city = value),
                              validator: (value) =>
                                  value == null ? 'Select your city' : null,
                            ),
                          ),
                          SizedBox(
                            width: size.maxWidth,
                            child: _field(
                              _area,
                              'Area',
                              Icons.near_me_outlined,
                            ),
                          ),
                          SizedBox(
                            width: size.maxWidth,
                            child: _field(
                              _address,
                              'Address',
                              Icons.location_on_outlined,
                              maxLength: 250,
                              lines: 2,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  if (_photoError != null) ...[
                    Text(
                      _photoError!,
                      key: const Key('business-photo-error'),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.pop(context, true),
                      child: const Text('Continue without photo'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  ActionButton(
                    label: _photoError == null
                        ? 'Save business'
                        : 'Retry photo',
                    onPressed: _save,
                    icon: Icons.check,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
