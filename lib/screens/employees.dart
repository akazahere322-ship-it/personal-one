import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api.dart';
import '../core/session.dart';
import '../core/ui.dart';
import 'employee_form.dart';

class EmployeeListScreen extends StatefulWidget {
  final bool pushed;
  const EmployeeListScreen({super.key, this.pushed = false});
  @override
  State<EmployeeListScreen> createState() => _S();
}

class _S extends State<EmployeeListScreen> {
  final items = <Map<String, dynamic>>[];
  final sc = ScrollController();
  String? next = '/employees/', error;
  int count = 0;
  bool loading = false;
  String q = '';

  @override
  void initState() {
    super.initState();
    sc.addListener(() {
      if (sc.position.pixels > sc.position.maxScrollExtent - 200) _load();
    });
    _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      items.clear();
      next = '/employees/';
    }
    if (next == null || loading) return;
    setState(() { loading = true; error = null; });
    try {
      final r = await Api.i.get(next!);
      items.addAll(List<Map<String, dynamic>>.from(r['results']));
      next = r['next'];
      count = r['count'] ?? items.length;
    } catch (e) {
      error = errText(e);
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final shown = items.where((e) => '${e['full_name']} ${e['designation']} ${e['department']} ${e['employee_no']}'.toLowerCase().contains(q.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Employees'), actions: [
        if (Session.i.can('employee_list', 'create'))
          IconButton(
              icon: const Icon(Icons.add_box_rounded, color: kBlue),
              onPressed: () async {
                if (await Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeFormScreen())) == true) _load(reset: true);
              }),
      ]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(onChanged: (v) => setState(() => q = v), decoration: const InputDecoration(hintText: 'Search employees...', prefixIcon: Icon(Icons.search), isDense: true))),
        Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('$count employees', style: const TextStyle(fontWeight: FontWeight.w600)))),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _load(reset: true),
            child: ListView(controller: sc, padding: const EdgeInsets.all(12), children: [
              if (error != null) Padding(padding: const EdgeInsets.all(20), child: Text(error!, textAlign: TextAlign.center)),
              for (final e in shown)
                Panel(
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => EmployeeDetailScreen(id: e['id'])));
                    _load(reset: true);
                  },
                  child: Row(children: [
                    CircleAvatar(backgroundImage: e['photo'] != null ? NetworkImage(e['photo']) : null, child: e['photo'] == null ? Text('${e['full_name'] ?? '?'}'[0]) : null),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${e['full_name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('${e['designation'] ?? ''}', style: const TextStyle(color: kMuted, fontSize: 12)),
                      Text('${e['department'] ?? ''}', style: const TextStyle(color: kMuted, fontSize: 12)),
                    ])),
                    const Icon(Icons.chevron_right, color: kMuted),
                  ]),
                ),
              if (loading) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
            ]),
          ),
        ),
      ]),
    );
  }
}

class EmployeeDetailScreen extends StatefulWidget {
  final int id;
  final bool me;
  const EmployeeDetailScreen({super.key, required this.id, this.me = false});
  @override
  State<EmployeeDetailScreen> createState() => _D();
}

class _D extends State<EmployeeDetailScreen> {
  late Future<dynamic> f;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => f = Api.i.get('/employees/${widget.id}/');

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: f,
        builder: (c, snap) {
          if (snap.connectionState != ConnectionState.done) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
          if (snap.hasError) return Scaffold(appBar: AppBar(), body: Center(child: Text(errText(snap.error!))));
          final e = Map<String, dynamic>.from(snap.data);
          final docs = List<Map<String, dynamic>>.from(e['documents'] ?? []);
          return Scaffold(
            appBar: AppBar(title: const Text('Employee Details'), actions: [
              if (Session.i.can('employee_list', 'edit'))
                IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () async {
                      if (await Navigator.push(context, MaterialPageRoute(builder: (_) => EmployeeFormScreen(existing: e))) == true) setState(_reload);
                    }),
            ]),
            body: ListView(padding: const EdgeInsets.all(12), children: [
              Panel(child: Row(children: [
                CircleAvatar(radius: 30, backgroundImage: e['photo'] != null ? NetworkImage(e['photo']) : null, child: e['photo'] == null ? const Icon(Icons.person) : null),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${e['full_name']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                  Text('${e['designation'] ?? ''} · ${e['department'] ?? ''}', style: const TextStyle(color: kMuted, fontSize: 12)),
                  Text('${e['employee_no'] ?? ''}', style: const TextStyle(color: kMuted, fontSize: 12)),
                ])),
                StatusChip('${e['status'] ?? ''}'),
              ])),
              Section('Personal Information', [
                KV('Date of Birth', e['dob']), KV('Gender', e['gender']), KV('Nationality', e['nationality']),
                KV('Phone', e['phone']), KV('Email', e['email']), KV('Address', e['address']),
              ]),
              Section('Work Information', [
                KV('Department', e['department']), KV('Designation', e['designation']), KV('Joining Date', e['join_date']),
                KV('Employment Type', e['employee_type']), KV('Reports To', e['reports_to_name']),
              ]),
              Section('Salary Information', [
                KV('Basic Pay', '${e['currency'] ?? ''} ${e['basic_salary'] ?? '-'}'),
                for (final a in (e['allowances'] ?? [])) KV('${a['type']}', '${e['currency'] ?? ''} ${a['amount']}'),
              ]),
              Section('Documents', [
                if (docs.isEmpty) const Text('No documents', style: TextStyle(color: kMuted)),
                for (final d in docs)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text('${d['doc_type']}'),
                    subtitle: Text('${d['doc_number'] ?? ''}${d['expiry_date'] != null ? '  · exp ${d['expiry_date']}' : ''}'),
                    trailing: d['file'] != null
                        ? Row(mainAxisSize: MainAxisSize.min, children: [StatusChip('${d['status']}'), TextButton(onPressed: () => launchUrl(Uri.parse(d['file']), mode: LaunchMode.externalApplication), child: const Text('View'))])
                        : StatusChip('${d['status']}'),
                  ),
              ]),
            ]),
          );
        },
      );
}
