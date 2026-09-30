import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../core/api.dart';
import '../core/session.dart';
import '../core/ui.dart';

Future<void> downloadPayslip(BuildContext c, Map<String, dynamic> p) async {
  try {
    final (bytes, name) = await Api.i.download('/payroll/payslips/${p['id']}/download/', 'Payslip_${p['id']}.pdf');
    final f = File('${(await getTemporaryDirectory()).path}/$name');
    await f.writeAsBytes(bytes);
    await OpenFilex.open(f.path);
  } catch (e) {
    if (c.mounted) toast(c, errText(e));
  }
}

class PayslipsScreen extends StatefulWidget {
  const PayslipsScreen({super.key});
  @override
  State<PayslipsScreen> createState() => _P();
}

class _P extends State<PayslipsScreen> {
  late Future<List<Map<String, dynamic>>> f;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => f = Api.i.getAll('/payroll/payslips/').then((l) => l.where((p) => p['employee_no'] == Session.i.employeeNo).toList()); // own only

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('My Payslips')),
        body: FutureBuilder(
          future: f,
          builder: (c, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) return Center(child: Text(errText(snap.error!)));
            final l = snap.data!;
            if (l.isEmpty) return const Center(child: Text('No payslips', style: TextStyle(color: kMuted)));
            return RefreshIndicator(
              onRefresh: () async => setState(_reload),
              child: ListView(padding: const EdgeInsets.all(12), children: [
                for (final p in l)
                  Panel(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PayslipDetail(p: p))),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${p['month_display']} ${p['year']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('Net pay: ${p['currency']} ${p['net_pay']}', style: const TextStyle(color: kMuted, fontSize: 12)),
                        const SizedBox(height: 4),
                        StatusChip('${p['status']}'),
                      ])),
                      IconButton(
                        icon: const Icon(Icons.download),
                        onPressed: p['status'] == 'Approved' ? () => downloadPayslip(context, p) : null, // greyed unless Approved
                      ),
                    ]),
                  ),
              ]),
            );
          },
        ),
      );
}

class PayslipDetail extends StatelessWidget {
  final Map<String, dynamic> p;
  const PayslipDetail({super.key, required this.p});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('${p['month_display']} ${p['year']}')),
        body: FutureBuilder(
          future: Api.i.get('/payroll/payslips/${p['id']}/breakdown/'),
          builder: (c, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) return Center(child: Text(errText(snap.error!)));
            final b = Map<String, dynamic>.from(snap.data);
            final cur = '${b['currency'] ?? ''}';
            return ListView(padding: const EdgeInsets.all(12), children: [
              Section('Earnings', [
                KV('Basic', '$cur ${b['basic']}'),
                for (final a in (b['allowances'] ?? [])) KV('${a['type']}', '$cur ${a['amount']}'),
                KV('Overtime', '$cur ${b['ot_amount']}'),
                for (final x in (b['bonus_items'] ?? [])) KV('${x['type'] ?? 'Bonus'}', '$cur ${x['amount']}'),
                KV('Total Earnings', '$cur ${b['total_earnings']}'),
              ]),
              Section('Deductions', [
                if ((b['deduction_items'] ?? []).isEmpty) const KV('None', ''),
                for (final x in (b['deduction_items'] ?? [])) KV('${x['type']}', '$cur ${x['amount']}'),
              ]),
              Panel(child: Row(children: [const Expanded(child: Text('Net Pay', style: TextStyle(fontWeight: FontWeight.w700))), Text('$cur ${b['net_pay']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kBlue))])),
              if (b['status'] == 'Approved') FilledButton.icon(onPressed: () => downloadPayslip(context, p), icon: const Icon(Icons.picture_as_pdf), label: const Text('Download PDF')),
            ]);
          },
        ),
      );
}
