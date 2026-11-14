import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db.dart';
import 'screens.dart';
import 'svc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // needs android/app/google-services.json
  final p = await SharedPreferences.getInstance();
  guest.value = p.getBool('guest') ?? false;
  await DB.db;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Mera Khata',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: green),
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
              backgroundColor: green,
              foregroundColor: Colors.white,
              titleTextStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        home: const Gate(),
      );
}

/// Login stays forever: Firebase restores the session on every start,
/// guest choice is saved in SharedPreferences. Only Logout clears it.
class Gate extends StatelessWidget {
  const Gate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        initialData: FirebaseAuth.instance.currentUser,
        builder: (c, s) => ValueListenableBuilder<bool>(
          valueListenable: guest,
          builder: (c, g, _) => (s.data != null || g) ? const Shell() : const LoginPage(),
        ),
      );
}
