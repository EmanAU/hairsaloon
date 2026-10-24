import '../../core/utils/pk_cnic.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/toast_service.dart';
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
  static const _ink = AppColors.homeInk;
  static const _muted = AppColors.textSecondary;
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.name);
  late final _phone = TextEditingController(
    text: PkPhone.localNumber(widget.profile?.phone),
  );
  late final _cnic = TextEditingController(
    text: PkCnic.display(widget.profile?.cnic),
  );
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
        cnic: PkCnic.digits(_cnic.text),
        dateOfBirth: _birth!,
        workStartedOn: _started!,
        photoBytes: _photo,
        photoExtension: _extension,
      );
      if (!mounted) return;
      ToastService.success('Profile saved', context);
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
        labelStyle: const TextStyle(fontSize: 12, color: _muted),
        hintStyle: const TextStyle(fontSize: 12, color: AppColors.iconMuted),
        errorStyle: const TextStyle(fontSize: 10.5),
        errorMaxLines: 2,
        prefixIcon: Icon(icon, size: 18, color: _muted),
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
          borderSide: const BorderSide(color: _ink),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 16,
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
      FocusScope.of(context).unfocus();
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
      decoration: _decoration(label, CupertinoIcons.calendar),
      child: Text(
        value == null
            ? 'Select date'
            : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}',
        style: TextStyle(fontSize: 12, color: value == null ? _muted : _ink),
      ),
    ),
  );

  Future<void> _pickPhoto() async {
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
  }

  Widget _photoPicker() => Material(
    color: const Color(0xFFF8F9F6),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: _pickPhoto,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
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
                  radius: 28,
                  backgroundColor: const Color(0xFFEBF1DC),
                  foregroundImage: image,
                  onForegroundImageError: image == null ? null : (_, stack) {},
                  child: const Icon(
                    CupertinoIcons.person_crop_circle,
                    color: _ink,
                    size: 34,
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
                    _photo == null && widget.profile?.photoPath == null
                        ? 'Add photo'
                        : 'Change photo',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'A clear photo of you · up to 2 MB',
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.4,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(CupertinoIcons.chevron_right, size: 14, color: _muted),
          ],
        ),
      ),
    ),
  );

  Widget _fields() => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth >= OnlineShell.twoColMinWidth
          ? (constraints.maxWidth - 12) / 2
          : constraints.maxWidth;
      final dateWidth = (constraints.maxWidth - 12) / 2;
      final experience = PersonalProfile(
        code: '',
        phone: '',
        workStartedOn: _started,
      ).experienceAt(DateTime.now());
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: width,
            child: TextFormField(
              controller: _name,
              style: const TextStyle(fontSize: 13),
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              decoration: _decoration('Full name', CupertinoIcons.person),
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
              style: const TextStyle(fontSize: 13),
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              inputFormatters: [PkPhoneInputFormatter()],
              decoration: _decoration(
                'Mobile number',
                CupertinoIcons.phone,
                hint: '03465501748',
              ),
              validator: PkPhone.localValidationError,
            ),
          ),
          SizedBox(
            width: width,
            child: TextFormField(
              controller: _cnic,
              style: const TextStyle(fontSize: 13),
              textInputAction: TextInputAction.done,
              keyboardType: TextInputType.number,
              inputFormatters: [PkCnicInputFormatter()],
              decoration: _decoration(
                'CNIC',
                CupertinoIcons.person_crop_rectangle,
                hint: '12345-1234567-1',
              ),
              validator: (value) =>
                  PkCnic.isValid(value) ? null : 'Enter your 13-digit CNIC',
            ),
          ),
          SizedBox(
            width: dateWidth,
            child: _date('Date of birth', _birth, (date) => _birth = date),
          ),
          SizedBox(
            width: dateWidth,
            child: _date(
              'Working since',
              _started,
              (date) => _started = date,
              firstDate: _birth,
            ),
          ),
          Container(
            width: constraints.maxWidth,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.briefcase, size: 16, color: _muted),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'Work experience',
                    style: TextStyle(fontSize: 11, color: _muted),
                  ),
                ),
                Flexible(
                  child: Text(
                    experience,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _ink,
                    ),
                  ),
                ),
              ],
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
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        leading: widget.onboarding
            ? null
            : IconButton(
                tooltip: 'Back',
                onPressed: _saving ? null : () => Navigator.maybePop(context),
                icon: const Icon(CupertinoIcons.back),
              ),
        title: const Text(
          'Personal profile',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        actions: [
          if (widget.onboarding)
            IconButton(
              tooltip: 'Sign out',
              onPressed: _saving ? null : widget.repository.signOut,
              icon: const Icon(CupertinoIcons.square_arrow_right, size: 21),
            ),
        ],
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your personal details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.35,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Add your photo and details to set up your profile.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.5,
                      color: _muted,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _photoPicker(),
                  const SizedBox(height: 18),
                  _fields(),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ActionButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        iconSize: 18,
                        textStyle: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      label: widget.onboarding
                          ? 'Save & continue'
                          : 'Save profile',
                      onPressed: _save,
                      icon: CupertinoIcons.arrow_right,
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
  );

  Widget _identifier(String label, String value) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label, style: const TextStyle(fontSize: 12, color: _muted)),
    subtitle: Text(value, style: const TextStyle(fontSize: 12)),
    trailing: IconButton(
      tooltip: 'Copy $label',
      icon: const Icon(CupertinoIcons.doc_on_doc, size: 17),
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: value));
        if (mounted) showMessage(context, '$label copied');
      },
    ),
  );
}
