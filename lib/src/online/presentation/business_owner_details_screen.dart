import 'package:flutter/material.dart';
import '../../core/utils/pk_cnic.dart';
import '../../core/utils/pk_phone.dart';
import '../data/business_workspace.dart';
import '../domain/online_models.dart';
import 'widgets/business_photo.dart';
import 'widgets/online_widgets.dart';

class BusinessOwnerDetailsScreen extends StatefulWidget {
  const BusinessOwnerDetailsScreen({super.key, required this.workspace});
  final BusinessWorkspace workspace;
  @override
  State<BusinessOwnerDetailsScreen> createState() =>
      _BusinessOwnerDetailsScreenState();
}

class _BusinessOwnerDetailsScreenState
    extends State<BusinessOwnerDetailsScreen> {
  late Future<OnlineWorkspace> _details = widget.workspace.repository
      .loadWorkspace();
  late final Future<String?> _photo = widget.workspace.repository
      .profilePhoto();
  void _reload() =>
      setState(() => _details = widget.workspace.repository.loadWorkspace());
  String _date(DateTime? date) => date == null
      ? 'Not set'
      : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) => OnlinePage(
    title: 'Business Details',
    actions: [
      IconButton(
        tooltip: 'Refresh details',
        onPressed: _reload,
        icon: const Icon(Icons.refresh),
      ),
    ],
    children: [
      RemoteContent<OnlineWorkspace>(
        future: _details,
        onRetry: _reload,
        builder: (account) {
          final owned = account.businesses.where(
            (b) => b.id == widget.workspace.business.id,
          );
          final isOwner = owned.isNotEmpty;
          final business = isOwner ? owned.first : widget.workspace.business;
          final profile = account.profile;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DetailSection(
                title: 'Business details',
                children: [
                  BusinessPhoto(
                    repository: widget.workspace.repository,
                    business: business,
                    width: 76,
                    height: 76,
                  ),
                  const SizedBox(height: 16),
                  _DetailRow('Business name', business.name),
                  _DetailRow(
                    'Business phone',
                    PkPhone.localNumber(business.phone),
                  ),
                  _DetailRow('Business type', business.type),
                  _DetailRow('City', business.city),
                  _DetailRow('Area', business.area),
                  _DetailRow('Address', business.address),
                  _DetailRow(
                    'Approval',
                    business.isActive ? 'Approved' : 'Waiting for approval',
                  ),
                  _DetailRow('Business ID', business.id),
                ],
              ),
              const SizedBox(height: 20),
              if (isOwner)
                _DetailSection(
                  title: 'Owner details',
                  children: [
                    FutureBuilder<String?>(
                      future: _photo,
                      builder: (context, snapshot) => CircleAvatar(
                        radius: 32,
                        backgroundColor: const Color(0xFFF0F4F1),
                        child: snapshot.data == null
                            ? const Icon(
                                Icons.person_outline,
                                color: Color(0xFF086744),
                              )
                            : ClipOval(
                                child: Image.network(
                                  snapshot.data!,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const Icon(Icons.person_outline),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DetailRow('Owner name', account.account.name),
                    _DetailRow(
                      'Personal phone',
                      PkPhone.localNumber(profile?.phone),
                    ),
                    _DetailRow('CNIC', PkCnic.display(profile?.cnic ?? '')),
                    _DetailRow('Date of birth', _date(profile?.dateOfBirth)),
                    _DetailRow('Working since', _date(profile?.workStartedOn)),
                    _DetailRow(
                      'Experience',
                      profile?.experienceAt(DateTime.now()) ?? 'Not set',
                    ),
                    _DetailRow('Profile code', profile?.code ?? ''),
                  ],
                )
              else
                const Text(
                  'Personal owner details are visible to the business owner.',
                  style: TextStyle(color: Color(0xFF797E86)),
                ),
            ],
          );
        },
      ),
    ],
  );
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFECEDEF)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 18),
        ...children,
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF858A94)),
        ),
        const SizedBox(height: 4),
        SelectableText(
          value.trim().isEmpty ? 'Not set' : value,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF202430),
            height: 1.4,
          ),
        ),
      ],
    ),
  );
}
