import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/utils/pk_phone.dart';
import '../../features/business_profile/domain/business_options.dart';
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
  late final _phone = TextEditingController(
    text: PkPhone.localNumber(widget.business?.phone),
  );
  late final _city = TextEditingController(text: widget.business?.city);
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

  @override
  void dispose() {
    for (final field in [_name, _phone, _city, _area, _address]) {
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
      final extension = file.name.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'webp'].contains(extension) ||
          await file.length() > 2 * 1024 * 1024) {
        throw const OnlineFailure(
          'Choose a JPG, PNG or WebP photo up to 2 MB.',
        );
      }
      final bytes = await file.readAsBytes();
      if (mounted) {
        setState(() {
          _photo = bytes;
          _extension = extension;
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
      _savedId = await widget.repository.saveBusiness(
        id: _savedId,
        name: _name.text,
        phone: _phone.text,
        type: _type,
        city: _city.text,
        area: _area.text,
        address: _address.text,
      );
      if (_photo != null) {
        await widget.repository.uploadBusinessPhoto(
          _savedId!,
          _photo!,
          _extension!,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String label, IconData icon, {String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 21, color: const Color(0xFF718094)),
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE1E5EA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE1E5EA)),
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
                      color: Color(0xFFF0F5DE),
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
        style: TextStyle(color: Color(0xFF718094), fontSize: 11),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          widget.business == null ? 'Register business' : 'Edit business',
          style: const TextStyle(fontFamily: 'Roboto'),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
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
                        final width = size.maxWidth >= 560
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
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(11),
                                ],
                                decoration: _decoration(
                                  'Business phone',
                                  Icons.phone_outlined,
                                  hint: '03127712502',
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
                              child: _field(
                                _city,
                                'City',
                                Icons.location_city_outlined,
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
                    ActionButton(
                      label: 'Save business',
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
    ),
  );
}
