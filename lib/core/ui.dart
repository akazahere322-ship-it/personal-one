import 'package:flutter/material.dart';
import 'api.dart';

const kBlue = Color(0xFF1E6BE5), kCyan = Color(0xFF00B4D8), kTeal = Color(0xFF00C853);
const kBg = Color(0xFFF7FBFA), kText = Color(0xFF1F2937), kMuted = Color(0xFF6B7280), kBorder = Color(0xFFE5E7EB);

ThemeData appTheme() => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: kBlue, primary: kBlue),
      scaffoldBackgroundColor: kBg,
      appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: kText, elevation: 0, scrolledUnderElevation: 0),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)),
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
    );

void toast(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
String errText(Object e) => e is ApiException ? e.message : 'Something went wrong. Check your connection.';

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.onTap});
  @override
  Widget build(BuildContext c) => Card(
        elevation: 0,
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: kBorder)),
        child: InkWell(borderRadius: BorderRadius.circular(14), onTap: onTap, child: Padding(padding: padding, child: child)),
      );
}

class Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const Section(this.title, this.children, {super.key});
  @override
  Widget build(BuildContext c) => Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 8),
        ...children,
      ]));
}

class KV extends StatelessWidget {
  final String k;
  final dynamic v;
  const KV(this.k, this.v, {super.key});
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(k, style: const TextStyle(color: kMuted, fontSize: 13))),
          Expanded(child: Text((v == null || '$v'.isEmpty) ? '-' : '$v', textAlign: TextAlign.end, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ]),
      );
}

class StatusChip extends StatelessWidget {
  final String s;
  const StatusChip(this.s, {super.key});
  @override
  Widget build(BuildContext c) {
    final col = switch (s.toLowerCase()) {
      'approved' || 'active' || 'valid' => kTeal,
      'rejected' || 'expired' || 'inactive' => Colors.red,
      'pending' || 'expiring' || 'on leave' => Colors.orange,
      _ => kMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: col.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
      child: Text(s, style: TextStyle(color: col, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

Future<String?> pickDate(BuildContext c, [String? current]) async {
  final d = await showDatePicker(
      context: c, initialDate: DateTime.tryParse(current ?? '') ?? DateTime.now(), firstDate: DateTime(1940), lastDate: DateTime(2100));
  if (d == null) return null;
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
