import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db.dart';
import 'main.dart';
import 'screens2.dart';
import 'svc.dart';

String rs(num n) => 'Rs ${NumberFormat('#,##0.##').format(n)}';
double bal(M c) => (c['balance'] as num).toDouble();
void snack(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m, style: const TextStyle(fontSize: 20))));

Future<bool> confirm(BuildContext c, String msg) async =>
    await showDialog<bool>(
        context: c,
        builder: (d) => AlertDialog(
              title: Text(msg, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Nahi / نہیں', style: TextStyle(fontSize: 22))),
                FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: red),
                    onPressed: () => Navigator.pop(d, true),
                    child: const Text('Haan / ہاں', style: TextStyle(fontSize: 22))),
              ],
            )) ??
    false;

Widget avatar(M c, double r) {
  final p = c['photo'] as String?;
  final ok = p != null && File(p).existsSync();
  return CircleAvatar(
      radius: r,
      backgroundColor: Colors.grey.shade300,
      backgroundImage: ok ? FileImage(File(p)) : null,
      child: ok ? null : Icon(Icons.person, size: r, color: Colors.grey.shade600));
}

class BigBtn extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String urdu, roman;
  final VoidCallback onTap;
  const BigBtn(this.color, this.icon, this.urdu, this.roman, this.onTap, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          height: 112,
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
            onPressed: onTap,
            child: Row(children: [
              Icon(icon, size: 58),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(urdu, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                Text(roman, style: const TextStyle(fontSize: 18)),
              ])),
            ]),
          ),
        ),
      );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool busy = false;
  Future<void> google() async {
    if (!firebaseReady) {
      snack(context, 'Google Login abhi tayyar ho raha hai. Abhi Bina Login Chalao dabayein.');
      return;
    }
    setState(() => busy = true);
    try {
      final g = await GoogleSignIn().signIn();
      if (g == null) return;
      final a = await g.authentication;
      await FirebaseAuth.instance.signInWithCredential(GoogleAuthProvider.credential(accessToken: a.accessToken, idToken: a.idToken));
      (await SharedPreferences.getInstance()).setBool('logged_in', true);
    } catch (e) {
      if (mounted) snack(context, 'Login nahi ho saka. Internet check karein.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.menu_book, size: 110, color: green),
              const SizedBox(height: 12),
              const Text('Mera Khata', style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: green)),
              const Text('Safe Udhar Book • محفوظ ادھار کھاتا', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 48),
              BigBtn(blue, Icons.login, 'گوگل سے لاگ ان', 'Google Se Login Karo', busy ? () {} : google),
              BigBtn(Colors.grey.shade700, Icons.person_outline, 'بغیر لاگ ان کے چلاؤ', 'Bina Login Ke Chalao', () async {
                (await SharedPreferences.getInstance()).setBool('guest', true);
                guest.value = true;
              }),
              if (busy) const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
              const SizedBox(height: 16),
              const Text('Ek baar login karein, hamesha login rahenge.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
            ]),
          ),
        ),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int i = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Svc.autoBackup();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused || s == AppLifecycleState.resumed) Svc.autoBackup();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: i, children: const [HomePage(), CustomerList(), BackupPage(), SettingsPage()]),
        bottomNavigationBar: NavigationBar(
          height: 78,
          selectedIndex: i,
          onDestinationSelected: (v) => setState(() => i = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home, size: 30), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.people, size: 30), label: 'Sab Khate'),
            NavigationDestination(icon: Icon(Icons.cloud_upload, size: 30), label: 'Backup'),
            NavigationDestination(icon: Icon(Icons.settings, size: 30), label: 'Settings'),
          ],
        ),
      );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _flow(BuildContext c, String type) async {
    final cust = await Navigator.push<M>(c, MaterialPageRoute(builder: (_) => const CustomerList(pick: true)));
    if (cust != null && c.mounted) Navigator.push(c, MaterialPageRoute(builder: (_) => AddEntryPage(cust, type)));
  }

  Widget _total(String urdu, String roman, double v, Color col) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: col.withOpacity(.1), border: Border.all(color: col, width: 2), borderRadius: BorderRadius.circular(18)),
        child: Column(children: [
          Text(urdu, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: col)),
          Text(roman, style: TextStyle(fontSize: 14, color: col)),
          const SizedBox(height: 6),
          FittedBox(child: Text(rs(v), style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: col))),
        ]),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mera Khata • میرا کھاتا')),
        body: ValueListenableBuilder<int>(
          valueListenable: DB.tick,
          builder: (c, _, __) => FutureBuilder<List<M>>(
            future: DB.customers(),
            builder: (c, s) {
              double lena = 0, dena = 0;
              for (final x in s.data ?? <M>[]) {
                final b = bal(x);
                b > 0 ? lena += b : dena -= b;
              }
              return ListView(padding: const EdgeInsets.all(16), children: [
                Row(children: [
                  Expanded(child: _total('کتنا لینا ہے', 'Kitna Lena Hai', lena, green)),
                  const SizedBox(width: 12),
                  Expanded(child: _total('کتنا دینا ہے', 'Kitna Dena Hai', dena, red)),
                ]),
                const SizedBox(height: 16),
                BigBtn(green, Icons.add_circle, 'پیسے ملے / واپس آئے', 'Paisa Mila / Wapis Aaya', () => _flow(c, 'received')),
                BigBtn(red, Icons.remove_circle, 'ادھار دیا', 'Udhar Diya', () => _flow(c, 'given')),
                BigBtn(blue, Icons.person_add, 'نیا کھاتا بناؤ / نیا بندہ', 'Naya Khata Banao / Naya Banda Add Karo',
                    () => Navigator.push(c, MaterialPageRoute(builder: (_) => const AddCustomerPage()))),
              ]);
            },
          ),
        ),
      );
}
        BigBtn(red, Icons.logout, 'لاگ آؤٹ', 'Logout', () async {
          if (!await confirm(context, 'Pakka Logout Karna Hai?')) return;
          if (firebaseReady) {
            try {
              await GoogleSignIn().signOut();
              await FirebaseAuth.instance.signOut();
            } catch (_) {}
          }
          final p = await SharedPreferences.getInstance();
          await p.setBool('guest', false);
          await p.setBool('logged_in', false);
          guest.value = false;
        }),
      ]),
    );
  }
}

class RecyclePage extends StatelessWidget {
  const RecyclePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Recycle Bin')),
        body: ValueListenableBuilder<int>(
          valueListenable: DB.tick,
          builder: (c, _, __) => FutureBuilder<List<M>>(
            future: DB.deleted(),
            builder: (c, s) {
              final l = s.data ?? <M>[];
              if (l.isEmpty) return const Center(child: Text('Recycle Bin khali hai', style: TextStyle(fontSize: 24)));
              return ListView(
                  children: l.map((x) {
                final left = 30 - DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(x['deleted_at'] as int)).inDays;
                return Card(
                    child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: avatar(x, 30),
                  title: Text('${x['name']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  subtitle: Text('$left din baaki', style: const TextStyle(fontSize: 16)),
                  trailing: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: green),
                      icon: const Icon(Icons.restore),
                      label: const Text('Wapis Lao', style: TextStyle(fontSize: 18)),
                      onPressed: () => DB.restore(x['id'] as int)),
                ));
              }).toList());
            },
          ),
        ),
      );
}
