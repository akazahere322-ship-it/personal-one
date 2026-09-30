import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api.dart';
import '../core/session.dart';
import '../core/ui.dart';

class ProfileScreen extends StatelessWidget {
  final bool pushed;
  const ProfileScreen({super.key, this.pushed = false});

  @override
  Widget build(BuildContext context) {
    final s = Session.i;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), automaticallyImplyLeading: pushed),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Panel(child: Row(children: [
          CircleAvatar(radius: 30, backgroundColor: kBlue.withValues(alpha: .12), child: Text(s.name.isEmpty ? '?' : s.name[0], style: const TextStyle(fontSize: 22, color: kBlue))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            Text('${s.role} · ${s.company}', style: const TextStyle(color: kMuted, fontSize: 12)),
          ])),
        ])),
        Section('Account', [KV('Employee No', s.employeeNo), KV('Company', s.company), KV('Role', s.role), KV('Data scope', s.scope)]),
        if (s.can('employee_list', 'view'))
          FutureBuilder(
            future: Api.i.get('/employees/me/'),
            builder: (c, snap) {
              if (!snap.hasData) return const SizedBox();
              final e = Map<String, dynamic>.from(snap.data as Map);
              return Column(children: [
                Section('My Details', [
                  KV('Designation', e['designation']), KV('Department', e['department']), KV('Joining Date', e['join_date']),
                  KV('Phone', e['phone']), KV('Email', e['email']), KV('Reports To', e['reports_to_name']),
                ]),
                // Bank Details card - read-only, only shown when a bank account is on file.
                if (e['bank_country'] != null)
                  Section('Bank Details', [
                    KV('Country', e['bank_country']),
                    KV('Bank', e['bank_name']),
                    KV('Branch', e['bank_branch']),
                    KV('Account holder', e['bank_account_holder']),
                    KV('Account number', e['bank_account_number']),
                    if (e['bank_country'] == 'UAE') KV('IBAN', e['bank_iban']) else KV('IFSC', e['bank_ifsc']),
                    if (e['bank_document'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: TextButton.icon(
                          onPressed: () => launchUrl(Uri.parse(e['bank_document']), mode: LaunchMode.externalApplication),
                          icon: const Icon(Icons.description_outlined, size: 18),
                          label: const Text('View document'),
                        ),
                      ),
                  ]),
              ]);
            },
          ),
        Panel(onTap: () => showDialog(context: context, builder: (_) => const _ChangePw()), child: const Row(children: [Icon(Icons.lock_reset, color: kBlue), SizedBox(width: 12), Text('Change Password')])),
        Panel(
            onTap: () => Session.i.logout(),
            child: const Row(children: [Icon(Icons.logout, color: Colors.red), SizedBox(width: 12), Text('Logout', style: TextStyle(color: Colors.red))])),
      ]),
    );
  }
}

class _ChangePw extends StatefulWidget {
  const _ChangePw();
  @override
  State<_ChangePw> createState() => _C();
}

class _C extends State<_ChangePw> {
  final cur = TextEditingController(), nw = TextEditingController();
  bool h1 = true, h2 = true, busy = false;
  String? err;

  Future<void> _save() async {
    setState(() { busy = true; err = null; });
    try {
      await Api.i.post('/auth/change-password/', {'current_password': cur.text, 'new_password': nw.text}); // stay signed in
      if (!mounted) return;
      Navigator.pop(context);
      toast(context, 'Password updated');
    } catch (e) {
      err = errText(e);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: cur, obscureText: h1, decoration: InputDecoration(labelText: 'Current password', errorText: err, suffixIcon: IconButton(icon: Icon(h1 ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => h1 = !h1)))),
          const SizedBox(height: 12),
          TextField(controller: nw, obscureText: h2, decoration: InputDecoration(labelText: 'New password', suffixIcon: IconButton(icon: Icon(h2 ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => h2 = !h2)))),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(90, 44)), onPressed: busy ? null : _save, child: const Text('Save'))],
      );
}
