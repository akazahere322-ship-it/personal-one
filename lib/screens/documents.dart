import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api.dart';
import '../core/session.dart';
import '../core/ui.dart';

/// Own documents (is_current true and employee_no = signed-in person);
/// a manager's list also has their team's, filtered out here.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});
  @override
  State<DocumentsScreen> createState() => _D();
}

class _D extends State<DocumentsScreen> {
  List<Map<String, dynamic>> rows = [];
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final all = await Api.i.getAll('/documents/');
      rows = all.where((r) => r['is_current'] == true && r['employee_no'] == Session.i.employeeNo).toList();
    } catch (e) {
      error = errText(e);
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('My Documents')),
        floatingActionButton: Session.i.can('employee_docs', 'create')
            ? FloatingActionButton.extended(
                backgroundColor: kBlue,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload'),
                onPressed: () async {
                  final ok = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => const _Upload());
                  if (ok == true) _load();
                })
            : null,
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.all(12), children: [
            if (error != null) Center(child: Text(error!)),
            if (!loading && rows.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No documents on file', style: TextStyle(color: kMuted)))),
            for (final d in rows)
              Panel(child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${d['doc_type']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${d['doc_number'] ?? ''}', style: const TextStyle(color: kMuted, fontSize: 12)),
                  if (d['expiry_date'] != null) Text('Expires ${d['expiry_date']}', style: const TextStyle(color: kMuted, fontSize: 12)),
                  const SizedBox(height: 4),
                  StatusChip('${d['expiry_state'] ?? ''}'),
                ])),
                if (d['doc_file'] != null)
                  IconButton(icon: const Icon(Icons.open_in_new), onPressed: () => launchUrl(Uri.parse(d['doc_file']), mode: LaunchMode.externalApplication)),
                for (final ex in (d['extra_files'] ?? []))
                  IconButton(icon: const Icon(Icons.attach_file), onPressed: () => launchUrl(Uri.parse(ex['file']), mode: LaunchMode.externalApplication)),
              ])),
            if (loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          ]),
        ),
      );
}

class _Upload extends StatefulWidget {
  const _Upload();
  @override
  State<_Upload> createState() => _U();
}

class _U extends State<_Upload> {
  String? type;
  final number = TextEditingController();
  String? issue, expiry;
  List<PlatformFile> pages = []; // first = main file, more = extra pages
  bool busy = false;

  Future<void> _pick() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif', 'gif', 'doc', 'docx']);
    if (files.isEmpty) return;
    for (final file in files) {
      final size = file.lengthSync() ?? await file.length();
      if ((size ?? 0) > 10 * 1024 * 1024) {
        if (!mounted) return;
        messenger?.showSnackBar(const SnackBar(content: Text('Max 10 MB per file')));
        return;
      }
    }
    if (!mounted) return;
    setState(() => pages = files);
  }

  Future<void> _submit() async {
    if (type == null || pages.isEmpty) {
      if (!mounted) return;
      return toast(context, 'Choose a document type and at least one file');
    }
    final id = Session.i.employeeId;
    if (id == null) {
      if (!mounted) return;
      return toast(context, 'No employee record linked to this account.');
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    setState(() => busy = true);
    try {
      await Api.i.multipartMulti('/documents/', {
        'employee_id': '$id',
        'doc_type': type!,
        if (number.text.trim().isNotEmpty) 'doc_number': number.text.trim(),
        if (expiry != null) 'expiry_date': expiry!,
        if (issue != null) 'issue_date': issue!,
      }, 'doc_files', [for (final p in pages) p.path!]);
      if (!mounted) return;
      navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(SnackBar(content: Text(errText(e))));
    }
    if (!mounted) return;
    setState(() => busy = false);
  }

  Widget _d(String label, String? val, ValueChanged<String> set) => InkWell(
      onTap: () async {
        final d = await pickDate(context, val);
        if (d != null) set(d);
      },
      child: InputDecorator(decoration: InputDecoration(labelText: label), child: Text(val ?? 'Select')));

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Upload Document', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Document type'),
                items: [for (final t in Session.i.documentTypes) DropdownMenuItem(value: t, child: Text(t))],
                onChanged: (x) => setState(() => type = x)),
            const SizedBox(height: 12),
            TextField(controller: number, decoration: const InputDecoration(labelText: 'Document number')),
            const SizedBox(height: 12),
            Row(children: [Expanded(child: _d('Issue date (optional)', issue, (d) => setState(() => issue = d))), const SizedBox(width: 10), Expanded(child: _d('Expiry date', expiry, (d) => setState(() => expiry = d)))]),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: _pick, icon: const Icon(Icons.file_upload_outlined), label: Text(pages.isEmpty ? 'Choose file(s) — front, then back' : '${pages.length} file(s) selected')),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : _submit, child: busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Upload'))),
          ]),
        ),
      );
}
