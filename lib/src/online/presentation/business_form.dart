import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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

  InputDecoration _decoration(
    String label,
    IconData icon, {
    String? hint,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
    hintStyle: const TextStyle(fontSize: 12, color: AppColors.iconMuted),
    errorStyle: const TextStyle(fontSize: 10.5),
    errorMaxLines: 2,
    prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
    prefixIconConstraints: const BoxConstraints(minWidth: 36),
    isDense: true,
    filled: true,
    fillColor: const Color(0xFFF8F9F6),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.homeInk),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
  );

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLength = 120,
    int lines = 1,
  }) => TextFormField(
    controller: controller,
    style: const TextStyle(fontSize: 13),
    textInputAction: lines > 1 ? TextInputAction.newline : TextInputAction.next,
    textCapitalization: TextCapitalization.words,
    maxLines: lines,
    inputFormatters: [LengthLimitingTextInputFormatter(maxLength)],
    decoration: _decoration(label, icon),
    validator: (value) => (value?.trim().isEmpty ?? true) ? 'Required' : null,
  );

  Widget _photoPicker() => Material(
    color: const Color(0xFFF8F9F6),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: _picking ? null : _choosePhoto,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            FutureBuilder<String?>(
              future: _photoUrl,
              builder: (context, snapshot) {
                final ImageProvider? image = _photo != null
                    ? MemoryImage(_photo!)
                    : snapshot.data == null
                    ? null
                    : NetworkImage(snapshot.data!);
                const placeholder = ColoredBox(
                  color: Color(0xFFEBF1DC),
                  child: Icon(
                    CupertinoIcons.camera,
                    color: AppColors.homeInk,
                    size: 28,
                  ),
                );
                return ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 56,
                    width: 56,
                    child: image == null
                        ? placeholder
                        : Image(
                            image: image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, error, stack) => placeholder,
                          ),
                  ),
                );
              },
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _picking
                        ? 'Opening photos…'
                        : _photo != null || widget.business?.logoPath != null
                        ? 'Change business photo'
                        : 'Add business photo',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.homeInk,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Shop photo or logo · up to 2 MB',
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _saving ? null : () => Navigator.maybePop(context),
          icon: const Icon(CupertinoIcons.back),
        ),
        title: Text(
          widget.business == null ? 'Register business' : 'Edit business',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
      body: OnlineShell.centered(
        maxWidth: 640,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.paddingOf(context).bottom,
          ),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: AbsorbPointer(
            absorbing: _saving,
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.business == null
                        ? 'Set up your business'
                        : 'Your business details',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.35,
                      color: AppColors.homeInk,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Add your salon’s details so customers can find you.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _photoPicker(),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, size) {
                      final width = size.maxWidth >= OnlineShell.twoColMinWidth
                          ? (size.maxWidth - 12) / 2
                          : size.maxWidth;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: width,
                            child: _field(
                              _name,
                              'Business name',
                              CupertinoIcons.building_2_fill,
                              maxLength: 160,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: TextFormField(
                              controller: _phone,
                              style: const TextStyle(fontSize: 13),
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [PkPhoneInputFormatter()],
                              decoration: _decoration(
                                'Business phone',
                                CupertinoIcons.phone,
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
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontSize: 13,
                                    color: AppColors.homeInk,
                                  ),
                              icon: const Icon(
                                CupertinoIcons.chevron_down,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              decoration: _decoration(
                                'Business type',
                                CupertinoIcons.square_grid_2x2,
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
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontSize: 13,
                                    color: AppColors.homeInk,
                                  ),
                              icon: const Icon(
                                CupertinoIcons.chevron_down,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              decoration: _decoration(
                                'City',
                                CupertinoIcons.building_2_fill,
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
                              CupertinoIcons.location,
                            ),
                          ),
                          SizedBox(
                            width: size.maxWidth,
                            child: _field(
                              _address,
                              'Address',
                              CupertinoIcons.location_solid,
                              maxLength: 250,
                              lines: 2,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_photoError != null) ...[
                    Text(
                      _photoError!,
                      key: const Key('business-photo-error'),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
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
                    icon: CupertinoIcons.check_mark,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      iconSize: 18,
                      textStyle: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
