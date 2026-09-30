import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api.dart';
import '../core/session.dart';
import '../core/ui.dart';

/// Add (existing == null) or Edit (PATCH, only changed fields) in 5 steps:
/// Personal, Work, Salary, Bank Details, Documents.
class EmployeeFormScreen extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const EmployeeFormScreen({super.key, this.existing});
  @override
  State<EmployeeFormScreen> createState() => _F();
}

class _F extends State<EmployeeFormScreen> {
  static const textKeys = [
    'full_name', 'dob', 'gender', 'nationality', 'phone', 'email', 'address',
    'department_id', 'designation', 'join_date', 'employee_type', 'reports_to_id',
    'basic_salary', 'currency',
    'bank_country', 'bank_name', 'bank_branch', 'bank_account_holder', 'bank_account_number', 'bank_iban', 'bank_ifsc',
  ];
  static const fileKeys = {'photo': 'Employee Photo'};
  final v = <String, String>{};
  final init = <String, String>{};
  final files = <String, PlatformFile>{};
  final documentFiles = <String, PlatformFile>{};
  PlatformFile? bankDoc;
  int? createdEmployeeId;
  List<Map<String, dynamic>> allowances = [];
  List<Map<String, dynamic>> managers = [];
  int step = 0;
  bool busy = false, allowEdited = false;
  final _key = GlobalKey<FormState>();

  bool get edit => widget.existing != null;
  Session get s => Session.i;
  List<String> get employeeDocumentTypes {
    final items = <String>{
      ...s.documentTypes,
      'Passport',
      'Emirates ID',
      'Visa',
      'Labour Card',
      'Health Insurance',
      'Driving License',
      'Educational Certificate',
    };
    return items.toList();
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      for (final k in textKeys) {
        if (e[k] != null) v[k] = '${e[k]}';
      }
      final d = s.departments.where((d) => d['name'] == e['department']);
      if (d.isNotEmpty) v['department_id'] = '${d.first['id']}';
      allowances = List<Map<String, dynamic>>.from((e['allowances'] ?? []).map((a) => {'type': '${a['type']}', 'amount': '${a['amount']}'}));
      init.addAll(v);
    }
    Api.i.get('/employees/').then((r) => setState(() => managers = List<Map<String, dynamic>>.from(r['results']))).catchError((_) {});
  }

  Widget tf(String k, String label, {TextInputType? kb, bool req = false, int lines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          key: ValueKey('$k-${v[k]}'),
          initialValue: v[k],
          keyboardType: kb,
          maxLines: lines,
          decoration: InputDecoration(labelText: req ? '$label *' : label),
          validator: req ? (x) => (x == null || x.trim().isEmpty) ? 'Required' : null : null,
          onChanged: (x) => v[k] = x,
        ),
      );

  Widget date(String k, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () async {
            final d = await pickDate(context, v[k]);
            if (d != null) setState(() => v[k] = d);
          },
          child: InputDecorator(decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today, size: 18)), child: Text(v[k] ?? 'YYYY-MM-DD', style: TextStyle(color: v[k] == null ? kMuted : kText))),
        ),
      );

  Widget dd(String k, String label, List<(String, String)> items) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: items.any((i) => i.$1 == v[k]) ? v[k] : null,
          decoration: InputDecoration(labelText: label),
          items: [for (final i in items) DropdownMenuItem(value: i.$1, child: Text(i.$2, overflow: TextOverflow.ellipsis))],
          onChanged: (x) => setState(() => v[k] = x ?? ''),
        ),
      );

  List<(String, String)> plain(List<String> l) => [for (final x in l) (x, x)];

  // IBAN: capitals, space every 4 chars, stop at AE + 21 digits (23 chars, spaces removed by server).
  Widget ibanField() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          key: ValueKey('iban-${v['bank_iban']}'),
          initialValue: v['bank_iban'],
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'IBAN', errorText: null, hintText: 'AE07 0331 2345 6789 0123 456'),
          inputFormatters: [UpperCaseTextFormatter(), _GroupFormatter(23, 4)],
          onChanged: (x) => v['bank_iban'] = x,
        ),
      );

  // IFSC: capitals, 11 characters (4 letters, 0, 6 letters/digits).
  Widget ifscField() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          key: ValueKey('ifsc-${v['bank_ifsc']}'),
          initialValue: v['bank_ifsc'],
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'IFSC', hintText: 'SBIN0001234'),
          inputFormatters: [UpperCaseTextFormatter(), LengthLimitingTextInputFormatter(11)],
          onChanged: (x) => v['bank_ifsc'] = x,
        ),
      );

  Future<void> submit() async {
    if (!(_key.currentState?.validate() ?? true) && step == 0) return;
    if ((v['full_name'] ?? '').trim().isEmpty) {
      setState(() => step = 0);
      if (!mounted) return;
      return toast(context, 'Full name is required');
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    final body = <String, String>{};
    for (final k in textKeys) {
      final x = (v[k] ?? '').trim();
      // bank_country empty on Edit clears the bank account - allow sending '' there.
      if (x.isEmpty) {
        if (edit && k == 'bank_country' && init['bank_country'] != null) body[k] = '';
        continue;
      }
      if (edit && init[k] == x) continue; // send only what changed
      body[k] = x;
    }
    final al = allowances.where((a) => '${a['amount']}'.isNotEmpty).toList();
    final sendAllow = edit ? allowEdited : al.isNotEmpty;
    setState(() => busy = true);
    try {
      final employeeId = edit ? widget.existing!['id'] : createdEmployeeId;
      final updating = employeeId != null;
      final path = updating ? '/employees/$employeeId/' : '/employees/';
      final allFiles = {...files, if (bankDoc != null) 'bank_document': bankDoc!};
      dynamic result;
      if (allFiles.isNotEmpty) {
        final f = {...body, if (sendAllow) 'allowances': _json(al)};
        result = await Api.i.multipart(updating ? 'PATCH' : 'POST', path, f, {for (final e in allFiles.entries) e.key: e.value.path!});
      } else {
        final j = <String, dynamic>{...body, if (sendAllow) 'allowances': al};
        result = updating ? await Api.i.patch(path, j) : await Api.i.post(path, j);
      }
      if (!edit && createdEmployeeId == null && result is Map && result['id'] != null) {
        createdEmployeeId = int.tryParse('${result['id']}');
      }
      final savedEmployeeId = edit ? widget.existing!['id'] : createdEmployeeId;
      if (documentFiles.isNotEmpty && savedEmployeeId == null) {
        throw StateError('Employee was saved, but its ID was not returned. Reload the employee before uploading documents.');
      }
      for (final entry in documentFiles.entries.toList()) {
        await Api.i.multipartMulti('/documents/', {
          'employee_id': '$savedEmployeeId',
          'doc_type': entry.key,
        }, 'doc_files', [entry.value.path!]);
        if (!mounted) return;
        documentFiles.remove(entry.key);
      }
      if (!mounted) return;
      messenger?.showSnackBar(SnackBar(content: Text(edit ? 'Employee updated' : 'Employee created')));
      if (!mounted) return;
      navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(SnackBar(content: Text(errText(e))));
    }
    if (!mounted) return;
    setState(() => busy = false);
  }

  String _json(List l) => '[${l.map((a) => '{"type":"${a['type']}","amount":"${a['amount']}"}').join(',')}]';

  @override
  Widget build(BuildContext context) {
    final country = (v['bank_country'] ?? '').trim();
    final steps = <Widget>[
      Form(key: _key, child: Column(children: [
        tf('full_name', 'Full Name', req: true),
        date('dob', 'Date of Birth'),
        dd('gender', 'Gender', plain(s.choice('gender'))),
        tf('nationality', 'Nationality'),
        tf('phone', 'Phone', kb: TextInputType.phone),
        tf('email', 'Email', kb: TextInputType.emailAddress),
        tf('address', 'Address', lines: 2),
      ])),
      Column(children: [
        dd('department_id', 'Department', [for (final d in s.departments) ('${d['id']}', '${d['name']}')]),
        dd('designation', 'Designation', plain(s.designations)),
        date('join_date', 'Joining Date'),
        dd('employee_type', 'Employment Type', plain(s.choice('employee_type'))),
        dd('reports_to_id', 'Reports To', [for (final m in managers) ('${m['id']}', '${m['full_name']}')]),
      ]),
      Column(children: [
        tf('basic_salary', 'Basic Pay', kb: TextInputType.number),
        dd('currency', 'Currency', plain(s.lookup('CURRENCY'))),
        const Align(alignment: Alignment.centerLeft, child: Text('Allowances', style: TextStyle(fontWeight: FontWeight.w700))),
        for (var i = 0; i < allowances.length; i++)
          Row(children: [
            Expanded(
                child: DropdownButtonFormField<String>(
              initialValue: s.lookup('ALLOWANCE_TYPE').contains(allowances[i]['type']) ? allowances[i]['type'] : null,
              decoration: const InputDecoration(labelText: 'Type', isDense: true),
              items: [for (final t in s.lookup('ALLOWANCE_TYPE')) DropdownMenuItem(value: t, child: Text(t))],
              onChanged: (x) => setState(() { allowances[i]['type'] = x; allowEdited = true; }),
            )),
            const SizedBox(width: 8),
            Expanded(child: TextFormField(initialValue: '${allowances[i]['amount']}', keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount', isDense: true), onChanged: (x) { allowances[i]['amount'] = x; allowEdited = true; })),
            IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { allowances.removeAt(i); allowEdited = true; })),
          ]),
        TextButton.icon(onPressed: () => setState(() { allowances.add({'type': null, 'amount': ''}); allowEdited = true; }), icon: const Icon(Icons.add), label: const Text('Add allowance')),
      ]),
      // Bank Details — country first; picking a country shows that country's bank list and code field.
      Column(children: [
        dd('bank_country', 'Bank country', [('', 'No bank account'), ...plain(s.choice('bank_country'))]),
        if (country == 'UAE') ...[
          dd('bank_name', 'Bank name', plain(s.lookup('BANK_UAE'))),
        ] else if (country == 'India') ...[
          dd('bank_name', 'Bank name', plain(s.lookup('BANK_INDIA'))),
        ],
        if (country.isNotEmpty) ...[
          tf('bank_branch', 'Branch'),
          tf('bank_account_holder', 'Account holder'),
          tf('bank_account_number', 'Account number'),
          if (country == 'UAE') ibanField(),
          if (country == 'India') ifscField(),
          Panel(
            onTap: () async {
              final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif', 'gif', 'doc', 'docx']);
              if (file == null) return;
              final size = file.lengthSync() ?? await file.length();
              if ((size ?? 0) > 10 * 1024 * 1024) {
                if (!context.mounted) return;
                return toast(context, 'Max 10 MB');
              }
              if (!context.mounted) return;
              setState(() => bankDoc = file);
            },
            child: Row(children: [
              const Icon(Icons.account_balance_outlined, color: kBlue),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Bank Document', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(bankDoc?.name ?? 'Passbook / bank letter / cheque', style: const TextStyle(color: kMuted, fontSize: 12), overflow: TextOverflow.ellipsis),
              ])),
              Icon(bankDoc != null ? Icons.check_circle : Icons.cloud_upload_outlined, color: bankDoc != null ? kTeal : kMuted),
            ]),
          ),
        ] else
          const Text('Choose a country to add bank details, or leave it as "No bank account".', style: TextStyle(color: kMuted, fontSize: 12)),
      ]),
      Column(children: [
        for (final e in fileKeys.entries)
          Panel(
            onTap: () async {
              final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif']);
              if (file == null) return;
              final size = file.lengthSync() ?? await file.length();
              if ((size ?? 0) > 10 * 1024 * 1024) {
                if (!context.mounted) return;
                return toast(context, 'Max 10 MB per file');
              }
              if (!context.mounted) return;
              setState(() => files[e.key] = file);
            },
            child: Row(children: [
              const Icon(Icons.person_outline, color: kBlue),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.value, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(files[e.key]?.name ?? 'Tap to upload', style: const TextStyle(color: kMuted, fontSize: 12), overflow: TextOverflow.ellipsis),
              ])),
              Icon(files.containsKey(e.key) ? Icons.check_circle : Icons.cloud_upload_outlined, color: files.containsKey(e.key) ? kTeal : kMuted),
            ]),
          ),
        for (final type in employeeDocumentTypes)
          Panel(
            onTap: () async {
              final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif', 'gif', 'doc', 'docx']);
              if (file == null) return;
              final size = file.lengthSync() ?? await file.length();
              if ((size ?? 0) > 10 * 1024 * 1024) {
                if (!context.mounted) return;
                return toast(context, 'Max 10 MB per file');
              }
              if (!context.mounted) return;
              setState(() => documentFiles[type] = file);
            },
            child: Row(children: [
              const Icon(Icons.description_outlined, color: kBlue),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(type, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(documentFiles[type]?.name ?? 'Tap to upload', style: const TextStyle(color: kMuted, fontSize: 12), overflow: TextOverflow.ellipsis),
              ])),
              Icon(documentFiles.containsKey(type) ? Icons.check_circle : Icons.cloud_upload_outlined, color: documentFiles.containsKey(type) ? kTeal : kMuted),
            ]),
          ),
      ]),
    ];
    const titles = ['Personal', 'Work', 'Salary', 'Bank', 'Documents'];
    return Scaffold(
      appBar: AppBar(title: Text(edit ? 'Edit Employee' : 'Add Employee')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            for (var i = 0; i < titles.length; i++) Expanded(child: Column(children: [
              CircleAvatar(radius: 13, backgroundColor: i <= step ? kBlue : kBorder, child: i < step ? const Icon(Icons.check, size: 14, color: Colors.white) : Text('${i + 1}', style: TextStyle(fontSize: 12, color: i <= step ? Colors.white : kMuted))),
              Text(titles[i], style: const TextStyle(fontSize: 11)),
            ])),
          ]),
        ),
        Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [Text('${titles[step]} Information', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), const SizedBox(height: 12), steps[step]])),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            if (step > 0) Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)), onPressed: () => setState(() => step--), child: const Text('Back'))),
            if (step > 0) const SizedBox(width: 10),
            Expanded(
                child: FilledButton(
                    onPressed: busy ? null : () => step < titles.length - 1 ? setState(() => step++) : submit(),
                    child: busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(step < titles.length - 1 ? 'Next' : (edit ? 'Save Changes' : 'Create Employee')))),
          ]),
        ),
      ]),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue n) => TextEditingValue(text: n.text.toUpperCase(), selection: n.selection);
}

/// Strips non-alphanumerics, caps total length, and inserts a space every [group] chars.
class _GroupFormatter extends TextInputFormatter {
  final int maxLen, group;
  _GroupFormatter(this.maxLen, this.group);
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue n) {
    var raw = n.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (raw.length > maxLen) raw = raw.substring(0, maxLen);
    final buf = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && i % group == 0) buf.write(' ');
      buf.write(raw[i]);
    }
    return TextEditingValue(text: buf.toString(), selection: TextSelection.collapsed(offset: buf.length));
  }
}
