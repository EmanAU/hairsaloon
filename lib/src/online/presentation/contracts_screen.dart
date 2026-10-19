import 'package:flutter/material.dart';
import '../domain/online_models.dart';
import '../domain/online_repository.dart';
import 'widgets/online_widgets.dart';

class ContractsScreen extends StatefulWidget {
  const ContractsScreen({super.key, required this.repository, this.employee});
  final OnlineRepository repository;
  final SalonStaff? employee;

  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen> {
  late Future<List<WorkContract>> _contracts = _load();
  Future<List<WorkContract>> _load() =>
      widget.repository.contracts(employeeId: widget.employee?.id);
  void _refresh() => setState(() => _contracts = _load());

  Future<void> _release(WorkContract contract) async {
    final reason = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _ReleaseReason()),
    );
    if (reason == null) return;
    await widget.repository.releaseContract(contract.id, reason);
    if (mounted) _refresh();
  }

  Widget _card(WorkContract contract) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            contract.businessName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            '${contract.kind.toUpperCase()} · ${contract.displayStatus}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text('From: ${contract.startsAt.toLocal()}'),
          Text('To: ${contract.endsAt?.toLocal() ?? 'Until released'}'),
          Text(
            'Salary: ${contract.salary.toStringAsFixed(2)} · Commission: ${contract.commission}%',
          ),
          if (contract.terms.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(contract.terms),
            ),
          if (contract.endingSoon)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Reminder: this contract ends within 7 days.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          if (contract.releaseReason != null)
            Text('Released: ${contract.releaseReason}'),
          if (widget.employee == null &&
              (contract.status == 'accepted' || contract.status == 'draft'))
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Your owner set these terms. Contact them if anything looks wrong.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          if (widget.employee != null && contract.canRelease)
            ActionButton(
              label: 'Release employee',
              onPressed: () => _release(contract),
            ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => OnlinePage(
    title: widget.employee?.name ?? 'My contracts',
    actions: [
      IconButton(
        tooltip: 'Refresh contracts',
        onPressed: _refresh,
        icon: const Icon(Icons.refresh),
      ),
    ],
    children: [
      if (widget.employee != null)
        ActionButton(
          label: 'Propose contract',
          icon: Icons.add,
          onPressed: () async {
            final saved = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => _ContractForm(
                  repository: widget.repository,
                  employee: widget.employee!,
                ),
              ),
            );
            if (saved == true && mounted) _refresh();
          },
        ),
      RemoteContent<List<WorkContract>>(
        future: _contracts,
        onRetry: _refresh,
        builder: (contracts) => contracts.isEmpty
            ? const Text('No contracts yet.')
            : Column(children: contracts.map(_card).toList()),
      ),
    ],
  );
}

class _ReleaseReason extends StatefulWidget {
  const _ReleaseReason();
  @override
  State<_ReleaseReason> createState() => _ReleaseReasonState();
}

class _ReleaseReasonState extends State<_ReleaseReason> {
  final _reason = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OnlinePage(
    title: 'Release employee',
    children: [
      const Text(
        'This ends the contract now. Its history will remain available.',
      ),
      Form(
        key: _form,
        child: TextFormField(
          controller: _reason,
          decoration: const InputDecoration(labelText: 'Reason for release'),
          maxLength: 1000,
          validator: (value) => value == null || value.trim().isEmpty
              ? 'A reason is required'
              : null,
        ),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _reason.text.trim());
          }
        },
        child: const Text('Confirm release'),
      ),
    ],
  );
}

class _ContractForm extends StatefulWidget {
  const _ContractForm({required this.repository, required this.employee});
  final OnlineRepository repository;
  final SalonStaff employee;
  @override
  State<_ContractForm> createState() => _ContractFormState();
}

class _ContractFormState extends State<_ContractForm> {
  final _form = GlobalKey<FormState>();
  final _salary = TextEditingController(text: '0');
  final _commission = TextEditingController(text: '0');
  final _terms = TextEditingController();
  String _kind = 'permanent';
  DateTime _starts = DateTime.now();
  DateTime _ends = DateTime.now().add(const Duration(days: 30));

  @override
  void dispose() {
    _salary.dispose();
    _commission.dispose();
    _terms.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool start) async {
    final initial = start ? _starts : _ends;
    final day = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    setState(() {
      final selected = DateTime(
        day.year,
        day.month,
        day.day,
        time.hour,
        time.minute,
      );
      if (start) {
        _starts = selected;
      } else {
        _ends = selected;
      }
    });
  }

  String? _number(String? value, double maximum) {
    final number = double.tryParse(value?.trim() ?? '');
    return number == null ||
            !number.isFinite ||
            number < 0 ||
            number > maximum ||
            !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value!.trim())
        ? 'Enter a valid amount up to $maximum'
        : null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final ends = _kind == 'permanent'
        ? null
        : _kind == 'daily'
        ? _starts.add(const Duration(hours: 24))
        : _ends;
    if (ends != null &&
        (!ends.isAfter(_starts) || !ends.isAfter(DateTime.now()))) {
      showMessage(
        context,
        'End time must be after the start time and in the future.',
      );
      return;
    }
    await widget.repository.proposeContract(
      employeeId: widget.employee.id,
      kind: _kind,
      starts: _starts,
      ends: ends,
      salary: double.parse(_salary.text),
      commission: double.parse(_commission.text),
      terms: _terms.text,
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => OnlinePage(
    title: 'Propose contract',
    children: [
      Text(
        'For ${widget.employee.name}. Terms take effect immediately. The employee is notified only.',
      ),
      Form(
        key: _form,
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Contract type'),
              items: const [
                DropdownMenuItem(value: 'permanent', child: Text('Permanent')),
                DropdownMenuItem(
                  value: 'daily',
                  child: Text('Daily (24 hours)'),
                ),
                DropdownMenuItem(value: 'fixed', child: Text('Fixed term')),
              ],
              onChanged: (value) => setState(() => _kind = value!),
            ),
            ListTile(
              title: const Text('Starts'),
              subtitle: Text('$_starts'),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () => _pickDate(true),
            ),
            if (_kind == 'fixed')
              ListTile(
                title: const Text('Ends'),
                subtitle: Text('$_ends'),
                trailing: const Icon(Icons.edit_calendar),
                onTap: () => _pickDate(false),
              ),
            TextFormField(
              controller: _salary,
              decoration: const InputDecoration(labelText: 'Basic salary'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) => _number(value, 9999999999.99),
            ),
            TextFormField(
              controller: _commission,
              decoration: const InputDecoration(labelText: 'Commission (%)'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) => _number(value, 100),
            ),
            TextFormField(
              controller: _terms,
              decoration: const InputDecoration(
                labelText: 'Terms (including salary period)',
              ),
              minLines: 3,
              maxLines: 6,
            ),
            ActionButton(label: 'Save contract', onPressed: _save),
          ],
        ),
      ),
    ],
  );
}
