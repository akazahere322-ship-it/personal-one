import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api.dart';
import '../core/ui.dart';

/// Read-only. Server already filters to what this person may see (everyone /
/// their department / them by name) — do not filter again in the app.
class CircularsScreen extends StatefulWidget {
  const CircularsScreen({super.key});
  @override
  State<CircularsScreen> createState() => _C();
}

class _C extends State<CircularsScreen> {
  late Future<List<Map<String, dynamic>>> f;
  @override
  void initState() {
    super.initState();
    f = Api.i.getAll('/circulars/');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Announcements')),
        body: FutureBuilder(
          future: f,
          builder: (c, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) return Center(child: Text(errText(snap.error!)));
            final l = snap.data!;
            if (l.isEmpty) return const Center(child: Text('No announcements', style: TextStyle(color: kMuted)));
            return RefreshIndicator(
              onRefresh: () async => setState(() => f = Api.i.getAll('/circulars/')),
              child: ListView(padding: const EdgeInsets.all(12), children: [
                for (final e in l)
                  Panel(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CircularDetail(id: e['id']))),
                    child: Row(children: [
                      const Icon(Icons.campaign_outlined, color: kBlue),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${e['subject']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${e['issued_date'] ?? ''}', style: const TextStyle(color: kMuted, fontSize: 12)),
                      ])),
                      const Icon(Icons.chevron_right, color: kMuted),
                    ]),
                  ),
              ]),
            );
          },
        ),
      );
}

class CircularDetail extends StatelessWidget {
  final int id;
  const CircularDetail({super.key, required this.id});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Announcement')),
        body: FutureBuilder(
          future: Api.i.get('/circulars/$id/'),
          builder: (c, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) return Center(child: Text(errText(snap.error!)));
            final e = Map<String, dynamic>.from(snap.data);
            return ListView(padding: const EdgeInsets.all(16), children: [
              Text('${e['subject']}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              Text('${e['serial_no'] ?? ''} · ${e['issued_by'] ?? ''} · ${e['issued_date'] ?? ''}', style: const TextStyle(color: kMuted, fontSize: 12)),
              const SizedBox(height: 14),
              Text('${e['body'] ?? ''}', style: const TextStyle(fontSize: 14, height: 1.5)),
              if (e['attachment'] != null) ...[
                const SizedBox(height: 20),
                OutlinedButton.icon(onPressed: () => launchUrl(Uri.parse(e['attachment']), mode: LaunchMode.externalApplication), icon: const Icon(Icons.attach_file), label: const Text('Open attachment')),
              ],
            ]);
          },
        ),
      );
}
