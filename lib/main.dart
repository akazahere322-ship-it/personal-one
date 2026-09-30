import 'package:flutter/material.dart';
import 'core/api.dart';
import 'core/session.dart';
import 'core/ui.dart';
import 'screens/login.dart';
import 'screens/shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.i.loadCompany();
  await Session.i.restore(); // GET /auth/session/ with the saved token
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Session.i,
        builder: (_, __) => MaterialApp(
          title: 'HRM',
          debugShowCheckedModeBanner: false,
          theme: appTheme(),
          home: Session.i.loggedIn ? const Shell() : const LoginScreen(),
        ),
      );
}
