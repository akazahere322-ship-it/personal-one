import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/session.dart';
import '../core/ui.dart';

/// Show only the person's own messages: a manager's /notifications/ also
/// contains their team's, which are not theirs to read.
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});
  @override
  State<InboxScreen> createState() => _I();
}

class _I extends State<InboxScreen> {
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
      final all = await Api.i.getAll('/notifications/');
      rows = all.where((r) => r['recipient_employee_no'] == Session.i.employeeNo).toList();
    } catch (e) {
      error = errText(e);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _open(Map<String, dynamic> r) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => _MsgDetail(msg: r)));
    _load();
  }

  IconData _icon(String t) => switch (t) { 'approval_result' => Icons.fact_check_outlined, 'circular' => Icons.campaign_outlined, _ => Icons.mail_outline };

  @override
  Widget build(BuildContext context) {
    final unread = rows.where((r) => r['is_read'] != true).length;
    return Scaffold(
      appBar: AppBar(title: Text(unread > 0 ? 'Inbox ($unread)' : 'Inbox')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          if (error != null) Center(child: Text(error!)),
          if (!loading && rows.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No messages', style: TextStyle(color: kMuted)))),
          for (final r in rows)
            Panel(
              onTap: () => _open(r),
              child: Row(children: [
                Icon(_icon('${r['notification_type']}'), color: r['is_read'] == true ? kMuted : kBlue),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${r['subject']}', style: TextStyle(fontWeight: r['is_read'] == true ? FontWeight.w500 : FontWeight.w800)),
                  Text('${r['sent_by'] ?? ''} · ${r['created_at'] ?? ''}', style: const TextStyle(color: kMuted, fontSize: 11)),
                ])),
                if (r['is_read'] != true) Container(width: 9, height: 9, decoration: const BoxDecoration(color: kBlue, shape: BoxShape.circle)),
              ]),
            ),
          if (loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
        ]),
      ),
    );
  }
}

class _MsgDetail extends StatefulWidget {
  final Map<String, dynamic> msg;
  const _MsgDetail({required this.msg});
  @override
  State<_MsgDetail> createState() => _M();
}

class _M extends State<_MsgDetail> {
  @override
  void initState() {
    super.initState();
    if (widget.msg['is_read'] != true) {
      Api.i.post('/notifications/${widget.msg['id']}/mark_read/').catchError((_) => null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.msg;
    return Scaffold(
      appBar: AppBar(title: const Text('Message')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('${m['subject']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        Text('${m['sent_by'] ?? ''} · ${m['created_at'] ?? ''}', style: const TextStyle(color: kMuted, fontSize: 12)),
        const SizedBox(height: 14),
        Text('${m['message'] ?? ''}', style: const TextStyle(fontSize: 14, height: 1.5)),
      ]),
    );
  }
}
