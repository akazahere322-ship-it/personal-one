import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/session.dart';
import '../core/ui.dart';
import 'attendance.dart';
import 'circulars.dart';
import 'documents.dart';
import 'employees.dart';
import 'employee_form.dart';
import 'inbox.dart';
import 'leave.dart';
import 'payslips.dart';
import 'profile.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _S();
}

class _S extends State<Shell> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final s = Session.i;
    final tabs = <(String, IconData, Widget)>[
      ('Home', Icons.home_outlined, const HomeScreen()),
      if (s.has('employee_list')) ('Employees', Icons.people_outline, const EmployeeListScreen()),
      if (s.has('inbox')) ('Inbox', Icons.mail_outline, const InboxScreen()),
      ('More', Icons.grid_view_rounded, const ProfileScreen()),
    ];
    if (tab >= tabs.length) tab = 0;
    return Scaffold(
      body: IndexedStack(index: tab, children: [for (final t in tabs) t.$3]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: [for (final t in tabs) NavigationDestination(icon: Icon(t.$2), label: t.$1)],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _H();
}

class _H extends State<HomeScreen> {
  int? count;
  Map<String, dynamic>? summary; // GET /dashboard/summary/ - only sections this person may see

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    if (Session.i.has('employee_list')) {
      Api.i.get('/employees/').then((r) => mounted ? setState(() => count = r['count']) : null).catchError((_) {});
    }
    Api.i.get('/dashboard/summary/').then((r) => mounted ? setState(() => summary = Map<String, dynamic>.from(r)) : null).catchError((_) {});
  }

  void _open(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    final s = Session.i;
    final unread = summary?['notifications']?['unread'];
    // Cards come from pages[] (page_key). Unknown keys are ignored. Approvals = leave_management.edit.
    final cards = <(String, String, IconData, Color, Widget, int?)>[
      if (s.has('employee_list')) ('Employees', 'Manage employees', Icons.people, kBlue, const EmployeeListScreen(pushed: true), null),
      if (s.has('leave_management')) ('Leave', 'Requests & balance', Icons.event_available, kCyan, const LeaveScreen(), null),
      if (s.has('leave_management') && s.can('leave_management', 'edit')) ('Approvals', 'Approve or reject', Icons.fact_check, Colors.orange, const LeaveScreen(tab: 1), null),
      if (s.has('salary')) ('My Payslips', 'View & download', Icons.payments, kTeal, const PayslipsScreen(), null),
      if (s.has('labour_timesheet')) ('Attendance', 'Check-in / check-out', Icons.access_time, Colors.indigo, const AttendanceScreen(), null),
      if (s.has('circulars')) ('Announcements', 'Company circulars', Icons.campaign, Colors.deepOrange, const CircularsScreen(), null),
      if (s.has('inbox')) ('Inbox', 'Messages', Icons.mail, Colors.pink, const InboxScreen(), unread is int ? unread : null),
      if (s.has('employee_docs')) ('My Documents', 'Your documents', Icons.folder_shared, Colors.brown, const DocumentsScreen(), null),
      ('Profile', 'View profile', Icons.person, Colors.purple, const ProfileScreen(pushed: true), null),
    ];
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await s.refresh();
            _load();
          },
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              CircleAvatar(radius: 24, backgroundColor: kBlue.withValues(alpha: .12), child: Text(s.name.isEmpty ? '?' : s.name[0], style: const TextStyle(color: kBlue, fontWeight: FontWeight.w700))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Good Day,', style: TextStyle(color: kMuted, fontSize: 12)),
                Text(s.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                Text(s.company, style: const TextStyle(color: kMuted, fontSize: 12)),
              ])),
            ]),
            const SizedBox(height: 16),
            if (s.has('employee_list'))
              InkWell(
                onTap: () => _open(const EmployeeListScreen(pushed: true)),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    const Icon(Icons.groups, color: Colors.white, size: 38),
                    const SizedBox(width: 14),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Total Employees', style: TextStyle(color: Colors.white70)),
                      Text('${count ?? '-'}', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                    ]),
                    const Spacer(),
                    const Icon(Icons.chevron_right, color: Colors.white),
                  ]),
                ),
              ),
            // Home summary: leave balance, pending, unread messages, documents expiring - one call.
            if (summary != null) ...[
              const SizedBox(height: 12),
              Row(children: [
                if (summary!['leave'] != null) Expanded(child: _mini('Annual Leave', '${summary!['leave']['annual_balance']}', 'days left', kCyan)),
                if (summary!['leave'] != null) const SizedBox(width: 8),
                if (summary!['documents'] != null) Expanded(child: _mini('Docs Expiring', '${summary!['documents']['expiring_soon']}', '${summary!['documents']['expired']} expired', Colors.orange)),
              ]),
            ],
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.35,
              children: [
                for (final c in cards)
                  Panel(
                    onTap: () => _open(c.$5),
                    child: Stack(children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(c.$3, color: c.$4, size: 30),
                        const SizedBox(height: 8),
                        Text(c.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(c.$2, style: const TextStyle(color: kMuted, fontSize: 11)),
                      ]),
                      if (c.$6 != null && c.$6! > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                            child: Text('${c.$6}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                        ),
                    ]),
                  ),
              ],
            ),
            if (s.can('employee_list', 'create')) ...[
              const SizedBox(height: 12),
              const Text('Quick Actions', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () => _open(const EmployeeFormScreen()),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Employee')),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _mini(String label, String big, String sub, Color color) => Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: kMuted, fontSize: 12)),
    Text(big, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
    Text(sub, style: const TextStyle(color: kMuted, fontSize: 11)),
  ]));
}
