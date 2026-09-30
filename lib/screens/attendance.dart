import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/session.dart';
import '../core/ui.dart';

/// Read-only. No month filter on the server — page through /timesheet/
/// (newest first) and group client-side; Sync / Mark Attendance stay on the website.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _A();
}

class _A extends State<AttendanceScreen> {
  List<Map<String, dynamic>> rows = [];
  String? error;
  bool loading = true;
  String? month; // 'YYYY-MM', null = all loaded

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final all = await Api.i.getAll('/timesheet/');
      rows = all.where((r) => r['employee_no'] == Session.i.employeeNo).toList(); // own days only
      if (rows.isNotEmpty) month ??= '${rows.first['work_date']}'.substring(0, 7);
    } catch (e) {
      error = errText(e);
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final months = {for (final r in rows) '${r['work_date']}'.substring(0, 7)}.toList()..sort((a, b) => b.compareTo(a));
    final shown = month == null ? rows : rows.where((r) => '${r['work_date']}'.startsWith(month!)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('My Attendance'), actions: [
        if (months.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DropdownButton<String>(
              value: month,
              underline: const SizedBox(),
              items: [for (final m in months) DropdownMenuItem(value: m, child: Text(m))],
              onChanged: (m) => setState(() => month = m),
            ),
          ),
      ]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          if (error != null) Center(child: Text(error!)),
          if (!loading && shown.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No attendance records', style: TextStyle(color: kMuted)))),
          for (final r in shown)
            Panel(
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${r['work_date']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('In ${r['check_in'] ?? '-'}   Out ${r['check_out'] ?? '-'}', style: const TextStyle(color: kMuted, fontSize: 12)),
                    if (r['check_in'] != null && r['check_out'] == null) const Padding(padding: EdgeInsets.only(top: 4), child: StatusChip('Missing check-out')),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${r['hours_worked'] ?? '-'} h', style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (r['overtime_hours'] != null)
                    Text('${(r['overtime_hours'] as num) >= 0 ? 'OT' : 'Short'} ${(r['overtime_hours'] as num).abs()}h', style: TextStyle(fontSize: 11, color: (r['overtime_hours'] as num) >= 0 ? kTeal : Colors.orange)),
                  Text('${r['source'] ?? ''}', style: const TextStyle(fontSize: 10, color: kMuted)),
                ]),
              ]),
            ),
          if (loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
        ]),
      ),
    );
  }
}
