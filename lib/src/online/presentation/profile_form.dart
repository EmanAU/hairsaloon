import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/utils/pk_phone.dart';
import '../domain/online_models.dart';
import '../domain/online_repository.dart';
import 'widgets/online_widgets.dart';

class ProfileForm extends StatefulWidget {
  const ProfileForm({
    super.key,
    required this.repository,
    this.profile,
    this.name = '',
    this.onboarding = false,
    this.onSaved,
  });
  final OnlineRepository repository;
  final PersonalProfile? profile;
  final String name;
  final bool onboarding;
  final Future<void> Function()? onSaved;
  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  static const _ink = Color(0xFF14202D);
  static const _muted = Color(0xFF718094);
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.name);
  late final _phone = TextEditingController(
    text: PkPhone.localNumber(widget.profile?.phone),
  );
  late final _cnic = TextEditingController(text: widget.profile?.cnic);
  late DateTime? _birth = widget.profile?.dateOfBirth;
  late DateTime? _started = widget.profile?.workStartedOn;
  late final Future<String?> _photoUrl = widget.profile?.photoPath == null
      ? Future.value(null)
      : widget.repository.profilePhoto();
  Uint8List? _photo;
  String? _extension;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _cnic.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      imageQuality: 85,
    );
    if (file == null) return;
    final extension = file.name.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'webp'].contains(extension) ||
        await file.length() > 2 * 1024 * 1024) {
      throw const OnlineFailure('Choose a JPG, PNG or WebP photo up to 2 MB.');
    }
    final bytes = await file.readAsBytes();
    if (mounted) {
      setState(() {
        _photo = bytes;
        _extension = extension;
      });
    }
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (_birth == null || _started == null) {
      throw const OnlineFailure(
        'Choose your date of birth and work start date.',
      );
    }
    if (_started!.isBefore(_birth!)) {
      throw const OnlineFailure(
        'Work start date must be after your date of birth.',
      );
    }
    if (_photo == null && (widget.profile?.photoPath?.isEmpty ?? true)) {
      throw const OnlineFailure('Add your profile photo to continue.');
    }
    setState(() => _saving = true);
    try {
      await widget.repository.saveProfile(
        name: _name.text,
        phone: _phone.text,
        cnic: _cnic.text,
        dateOfBirth: _birth!,
        workStartedOn: _started!,
      );
      if (_photo != null) {
        await widget.repository.uploadProfilePhoto(_photo!, _extension!);
      }
      if (!mounted) return;
      if (widget.onSaved != null) {
        await widget.onSaved!();
      } else {
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String label, IconData icon, {String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 21, color: _muted),
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE1E5EA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE1E5EA)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      );

  Widget _date(
    String label,
    DateTime? value,
    ValueChanged<DateTime> changed, {
    DateTime? firstDate,
  }) => InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: () async {
      final today = DateUtils.dateOnly(DateTime.now());
      final first = firstDate ?? DateTime(1900);
      final initial =
          value ?? (label == 'Date of birth' ? DateTime(2000) : today);
      final date = await showDatePicker(
        context: context,
        initialDate: initial.isBefore(first) ? first : initial,
        firstDate: first,
        lastDate: today,
      );
      if (date != null && mounted) setState(() => changed(date));
    },
    child: InputDecorator(
      decoration: _decoration(label, Icons.calendar_month_outlined),
      child: Text(
        value == null
            ? 'Select date'
            : MaterialLocalizations.of(context).formatMediumDate(value),
        style: TextStyle(color: value == null ? _muted : _ink),
      ),
    ),
  );

  Widget _photoPicker() => Column(
    children: [
      FutureBuilder<String?>(
        future: _photoUrl,
        builder: (context, snapshot) {
          final ImageProvider? image = _photo != null
              ? MemoryImage(_photo!)
              : snapshot.data != null
              ? NetworkImage(snapshot.data!)
              : null;
          return CircleAvatar(
            radius: 38,
            backgroundColor: const Color(0xFFF0F5DE),
            foregroundImage: image,
            onForegroundImageError: image == null ? null : (_, stack) {},
            child: const Icon(Icons.person_outline, color: _ink, size: 32),
          );
        },
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () async {
          try {
            await _choosePhoto();
          } catch (error) {
            if (mounted) {
              showMessage(
                context,
                error is OnlineFailure
                    ? error.message
                    : 'Could not open photo. Please retry.',
              );
            }
          }
        },
        child: Text(
          _photo == null && widget.profile?.photoPath == null
              ? 'Add photo'
              : 'Change photo',
        ),
      ),
      const Text('Up to 2 MB', style: TextStyle(fontSize: 11, color: _muted)),
    ],
  );

  Widget _fields() => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth >= 560
          ? (constraints.maxWidth - 16) / 2
          : constraints.maxWidth;
      final experience = PersonalProfile(
        code: '',
        phone: '',
        workStartedOn: _started,
      ).experienceAt(DateTime.now());
      return Wrap(
        spacing: 16,
        runSpacing: 18,
        children: [
          SizedBox(
            width: width,
            child: TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              decoration: _decoration('Full name', Icons.person_outline),
              validator: (value) =>
                  (value?.trim().isEmpty ?? true) || value!.trim().length > 120
                  ? 'Enter your full name (up to 120 characters)'
                  : null,
            ),
          ),
          SizedBox(
            width: width,
            child: TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              decoration: _decoration(
                'Mobile number',
                Icons.phone_outlined,
                hint: '03127712502',
              ),
              validator: PkPhone.localValidationError,
            ),
          ),
          SizedBox(
            width: width,
            child: TextFormField(
              controller: _cnic,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(13),
              ],
              decoration: _decoration(
                'CNIC',
                Icons.badge_outlined,
                hint: '13 digits without dashes',
              ),
              validator: (value) => RegExp(r'^\d{13}$').hasMatch(value ?? '')
                  ? null
                  : 'Enter your 13-digit CNIC',
            ),
          ),
          SizedBox(
            width: width,
            child: _date('Date of birth', _birth, (date) => _birth = date),
          ),
          SizedBox(
            width: width,
            child: _date(
              'Working since',
              _started,
              (date) => _started = date,
              firstDate: _birth,
            ),
          ),
          SizedBox(
            width: width,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Work experience',
                    style: TextStyle(fontSize: 12, color: _muted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    experience,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Personal profile',
          style: TextStyle(fontFamily: 'Roboto'),
        ),
        actions: [
          if (widget.onboarding)
            IconButton(
              tooltip: 'Sign out',
              onPressed: _saving ? null : widget.repository.signOut,
              icon: const Icon(Icons.logout),
            ),
        ],
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: _photoPicker()),
                    const SizedBox(height: 24),
                    _fields(),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ActionButton(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        label: widget.onboarding
                            ? 'Save & continue'
                            : 'Save profile',
                        onPressed: _save,
                        icon: Icons.arrow_forward_rounded,
                      ),
                    ),
                    if (!widget.onboarding && widget.profile != null) ...[
                      const SizedBox(height: 16),
                      _identifier('Profile code', widget.profile!.code),
                      if (widget.repository.userId != null)
                        _identifier('User ID', widget.repository.userId!),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _identifier(String label, String value) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label, style: const TextStyle(fontSize: 12, color: _muted)),
    subtitle: Text(value, style: const TextStyle(fontSize: 12)),
    trailing: IconButton(
      tooltip: 'Copy $label',
      icon: const Icon(Icons.copy, size: 18),
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: value));
        if (mounted) showMessage(context, '$label copied');
      },
    ),
  );
}
