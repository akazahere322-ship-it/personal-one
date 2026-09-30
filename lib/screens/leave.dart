import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api.dart';
import '../core/session.dart';
import '../core/ui.dart';

class LeaveScreen extends StatefulWidget {
  final int tab;
  const LeaveScreen({super.key, this.tab = 0});
  @override
  State<LeaveScreen> createState() => _L();
}

class _L extends State<LeaveScreen> {
  Map<String, dynamic>? bal;
  List<Map<String, dynamic>> rows = [];
  String? error;
  bool loading = true;
  Session get s => Session.i;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final r = await Future.wait([Api.i.getAll('/leave/'), Api.i.get('/leave/balance/').catchError((_) => null)]);
      rows = r[0] as List<Map<String, dynamic>>;
      bal = r[1] == null ? null : Map<String, dynamic>.from(r[1] as Map);
    } catch (e) {
      error = errText(e);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _decide(Map<String, dynamic> r, bool approve) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final res = await Api.i.post('/leave/${r['id']}/${approve ? 'approve' : 'reject'}/');
      if (!mounted) return;
      messenger?.showSnackBar(SnackBar(content: Text(res is Map && res['result'] == 'advanced' ? 'Moved to next approver (still pending)' : (approve ? 'Approved' : 'Rejected'))));
    } catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(SnackBar(content: Text(errText(e))));
    }
    _load();
  }

  Widget _bal(String t, String p) => Expanded(
          child: Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t, style: const TextStyle(color: kMuted, fontSize: 12)),
        Text('${bal?['${p}_balance'] ?? '-'}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: kBlue)),
        Text('of ${bal?['${p}_entitled'] ?? '-'} days · taken ${bal?['${p}_taken'] ?? '-'}', style: const TextStyle(fontSize: 11, color: kMuted)),
      ])));

  Widget _tile(Map<String, dynamic> r, {bool approvals = false}) => Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(approvals ? '${r['employee_name']}' : '${r['leave_type']}', style: const TextStyle(fontWeight: FontWeight.w700))),
          StatusChip('${r['status']}'),
        ]),
        if (approvals) Text('${r['leave_type']}', style: const TextStyle(color: kMuted, fontSize: 12)),
        Text('${r['start_date']} → ${r['end_date']}  (${r['days']} days)', style: const TextStyle(fontSize: 13)),
        if ('${r['reason'] ?? ''}'.isNotEmpty) Text('${r['reason']}', style: const TextStyle(color: kMuted, fontSize: 12)),
        if (r['attachment'] != null)
          InkWell(
            onTap: () => launchUrl(Uri.parse(r['attachment']), mode: LaunchMode.externalApplication),
            child: const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.attach_file, size: 16, color: kBlue), SizedBox(width: 4), Text('Attachment', style: TextStyle(color: kBlue, fontSize: 12))]),
            ),
          ),
        if (approvals) ...[
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => _decide(r, false), child: const Text('Reject'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(40)), onPressed: () => _decide(r, true), child: const Text('Approve'))),
          ]),
        ],
      ]));

  @override
  Widget build(BuildContext context) {
    final approver = s.can('leave_management', 'edit');
    final mine = rows.where((r) => r['employee_no'] == s.employeeNo).toList();
    final pending = rows.where((r) => r['status'] == 'Pending' && r['employee_no'] != s.employeeNo).toList(); // never own
    Widget body(List<Widget> kids) => RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(12), children: [
          if (error != null) Center(child: Text(error!)),
          ...kids,
          if (loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
        ]));
    return DefaultTabController(
      length: approver ? 2 : 1,
      initialIndex: approver ? widget.tab : 0,
      child: Scaffold(
        appBar: AppBar(title: const Text('Leave'), bottom: approver ? const TabBar(tabs: [Tab(text: 'My Leave'), Tab(text: 'Approvals')]) : null),
        floatingActionButton: s.can('leave_management', 'create')
            ? FloatingActionButton.extended(
                backgroundColor: kBlue,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add),
                label: const Text('New request'),
                onPressed: () async {
                  final ok = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => const _NewLeave());
                  if (ok == true) _load();
                })
            : null,
        body: TabBarView(children: [
          body([
            Row(children: [_bal('Annual Leave', 'annual'), const SizedBox(width: 8), _bal('Sick Leave', 'sick')]),
            if (bal != null) Text('Pending requests: ${bal!['pending']}', style: const TextStyle(color: kMuted)),
            const SizedBox(height: 8),
            for (final r in mine) _tile(r),
            if (!loading && mine.isEmpty) const Center(child: Text('No leave requests', style: TextStyle(color: kMuted))),
          ]),
          if (approver)
            body([
              for (final r in pending) _tile(r, approvals: true),
              if (!loading && pending.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Nothing waiting for approval', style: TextStyle(color: kMuted)))),
            ]),
        ]),
      ),
    );
  }
}

class _NewLeave extends StatefulWidget {
  const _NewLeave();
  @override
  State<_NewLeave> createState() => _N();
}

class _N extends State<_NewLeave> {
  bool singleDay = true; // default ON, like the website
  String? type, date, from, to;
  final reason = TextEditingController();
  PlatformFile? attachment;
  bool busy = false;

  Future<void> _pickAttachment() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif', 'gif', 'doc', 'docx']);
    if (file == null) return;
    final size = file.lengthSync() ?? await file.length();
    if ((size ?? 0) > 10 * 1024 * 1024) {
      if (!mounted) return;
      messenger?.showSnackBar(const SnackBar(content: Text('Max 10 MB')));
      return;
    }
    if (!mounted) return;
    setState(() => attachment = file);
  }

  Future<void> _submit() async {
    final start = singleDay ? date : from;
    final end = singleDay ? date : to;
    if (type == null || start == null || end == null) {
      if (!mounted) return;
      return toast(context, 'Choose leave type and date${singleDay ? '' : 's'}');
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    setState(() => busy = true);
    try {
      // "days" is NOT sent - the server counts it (end - start + 1).
      final fields = {'leave_type': type!, 'start_date': start, 'end_date': end, 'reason': reason.text.trim()};
      if (attachment != null) {
        await Api.i.multipart('POST', '/leave/', fields, {'attachment': attachment!.path!});
      } else {
        await Api.i.post('/leave/', fields);
      }
      if (!mounted) return;
      navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(SnackBar(content: Text(errText(e))));
    }
    if (!mounted) return;
    setState(() => busy = false);
  }

  Widget _d(String label, String? val, ValueChanged<String> set) => Expanded(
      child: InkWell(
          onTap: () async {
            final d = await pickDate(context, val);
            if (d != null) set(d);
          },
          child: InputDecorator(decoration: InputDecoration(labelText: label), child: Text(val ?? 'Select'))));

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('New Leave Request', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Leave type'),
                items: [for (final t in Session.i.lookup('LEAVE_TYPE')) DropdownMenuItem(value: t, child: Text(t))],
                onChanged: (x) => setState(() => type = x)),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Single day'),
              subtitle: const Text('Leave for one day only', style: TextStyle(fontSize: 12, color: kMuted)),
              value: singleDay,
              onChanged: (v) => setState(() => singleDay = v),
            ),
            const SizedBox(height: 6),
            if (singleDay)
              _d('Date', date, (d) => setState(() => date = d))
            else
              Row(children: [_d('From', from, (d) => setState(() => from = d)), const SizedBox(width: 10), _d('To', to, (d) => setState(() => to = d))]),
            const SizedBox(height: 12),
            TextField(controller: reason, maxLines: 2, decoration: const InputDecoration(labelText: 'Reason')),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickAttachment,
              icon: const Icon(Icons.attach_file),
              label: Text(attachment?.name ?? 'Attach file (optional)', overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : _submit, child: busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Submit'))),
          ]),
        ),
      );
}
