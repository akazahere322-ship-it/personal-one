import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/session.dart';
import '../core/ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _S();
}

class _S extends State<LoginScreen> {
  final u = TextEditingController(), p = TextEditingController();
  bool hide = true, busy = false;
  Company selectedCompany = Api.i.company;

  Future<void> _go() async {
    if (u.text.trim().isEmpty || p.text.isEmpty) return toast(context, 'Enter username and password');
    setState(() => busy = true);
    try {
      await Api.i.setCompany(selectedCompany);
      await Session.i.login(u.text.trim(), p.text);
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(24), children: [
            const SizedBox(height: 40),
            const Icon(Icons.groups_rounded, size: 64, color: kBlue),
            const Center(child: Text('HRM', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: kBlue))),
            const Center(child: Text('Human Resource Management', style: TextStyle(color: kMuted))),
            const SizedBox(height: 40),
            const Text('Welcome Back 👋', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            const Text('Sign in to continue', style: TextStyle(color: kMuted)),
            const SizedBox(height: 24),
            DropdownButtonFormField<Company>(
              initialValue: selectedCompany,
              decoration: const InputDecoration(labelText: 'Company'),
              items: const [
                DropdownMenuItem(value: Company.sbig, child: Text('SBIG')),
                DropdownMenuItem(value: Company.meltis, child: Text('Meltis')),
              ],
              onChanged: busy ? null : (company) {
                if (company != null) setState(() => selectedCompany = company);
              },
            ),
            const SizedBox(height: 14),
            TextField(controller: u, decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline))),
            const SizedBox(height: 14),
            TextField(
                controller: p,
                obscureText: hide,
                onSubmitted: (_) => _go(),
                decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(icon: Icon(hide ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => hide = !hide)))),
            const SizedBox(height: 24),
            FilledButton(onPressed: busy ? null : _go, child: busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Login')),
          ]),
        ),
      );
}
