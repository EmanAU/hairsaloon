import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/utils/pk_phone.dart';
import '../domain/online_models.dart';
import '../domain/online_repository.dart';
import 'widgets/online_widgets.dart';

class ProfileForm extends StatefulWidget {
  const ProfileForm({super.key, required this.repository, this.profile});
  final OnlineRepository repository;
  final PersonalProfile? profile;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  final _form = GlobalKey<FormState>();
  late final _phone = TextEditingController(text: widget.profile?.phone);
  late final _cnic = TextEditingController(text: widget.profile?.cnic);
  late DateTime? _birth = widget.profile?.dateOfBirth;

  @override
  void dispose() {
    _phone.dispose();
    _cnic.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_birth == null) {
      showMessage(context, 'Choose your date of birth');
      return;
    }
    await widget.repository.saveProfile(
      phone: _phone.text,
      cnic: _cnic.text,
      dateOfBirth: _birth!,
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => OnlinePage(
    title: 'Personal profile',
    children: [
      const Text(
        'Create your barber profile. Your mobile number is also your SIM contact number.',
      ),
      const SizedBox(height: 20),
      if (widget.profile != null) ...[
        FutureBuilder<String?>(
          future: widget.repository.profilePhoto(),
          builder: (context, snapshot) => snapshot.data == null
              ? const SizedBox.shrink()
              : Image.network(
                  snapshot.data!,
                  height: 120,
                  errorBuilder: (_, error, stack) => const Icon(Icons.person),
                ),
        ),
        ActionButton(
          label: 'Change profile photo',
          icon: Icons.photo_camera,
          onPressed: () async {
            final file = await ImagePicker().pickImage(
              source: ImageSource.gallery,
              maxWidth: 1000,
              imageQuality: 85,
            );
            if (file == null) return;
            await widget.repository.uploadProfilePhoto(
              await file.readAsBytes(),
              file.name.split('.').last.toLowerCase(),
            );
            if (mounted) setState(() {});
          },
        ),
      ] else
        const Text('Save your profile to add a photo.'),
      Form(
        key: _form,
        child: Column(
          children: [
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(
                labelText: 'Mobile number',
                hintText: '03XXXXXXXXX',
              ),
              keyboardType: TextInputType.phone,
              validator: (value) => PkPhone.validationError(value),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cnic,
              decoration: const InputDecoration(labelText: 'CNIC'),
              keyboardType: TextInputType.number,
              validator: (value) =>
                  RegExp(
                    r'^\d{13}$',
                  ).hasMatch((value ?? '').replaceAll('-', '').trim())
                  ? null
                  : 'Enter your 13-digit CNIC',
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date of birth'),
              subtitle: Text(
                _birth == null
                    ? 'Select date'
                    : MaterialLocalizations.of(
                        context,
                      ).formatMediumDate(_birth!),
              ),
              trailing: const Icon(Icons.calendar_month),
              onTap: () async {
                final result = await showDatePicker(
                  context: context,
                  initialDate: _birth ?? DateTime(2000),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (result != null && mounted) setState(() => _birth = result);
              },
            ),
            ActionButton(
              label: 'Save profile',
              onPressed: _save,
              icon: Icons.check,
            ),
          ],
        ),
      ),
    ],
  );
}
