import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db.dart';
import 'svc.dart';

// ---------- helpers ----------
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

// ---------- login ----------
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool busy = false;
  Future<void> google() async {
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

// ---------- shell with bottom nav ----------
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

// ---------- home ----------
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

// ---------- customer list (also used as picker) ----------
class CustomerList extends StatefulWidget {
  final bool pick;
  const CustomerList({super.key, this.pick = false});
  @override
  State<CustomerList> createState() => _CustomerListState();
}

class _CustomerListState extends State<CustomerList> {
  String q = '';
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.pick ? 'Kis ka? • کس کا؟' : 'Sab Khate • سب کھاتے')),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: blue,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.person_add, size: 30),
          label: const Text('Naya Banda', style: TextStyle(fontSize: 20)),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddCustomerPage())),
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              style: const TextStyle(fontSize: 22),
              onChanged: (v) => setState(() => q = v),
              decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 32),
                  hintText: 'Naam ya Number dhoondo',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: DB.tick,
              builder: (c, _, __) => FutureBuilder<List<M>>(
                future: DB.customers(q: q),
                builder: (c, s) {
                  final l = s.data ?? <M>[];
                  if (l.isEmpty) return const Center(child: Text('Koi khata nahi\nکوئی کھاتا نہیں', textAlign: TextAlign.center, style: TextStyle(fontSize: 24)));
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: l.length,
                    itemBuilder: (c, i) {
                      final x = l[i];
                      final b = bal(x);
                      final col = b > 0 ? green : (b < 0 ? red : Colors.grey);
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: avatar(x, 34),
                          title: Text('${x['name']}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          subtitle: Text('${x['phone'] ?? ''}', style: const TextStyle(fontSize: 16)),
                          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(rs(b.abs()), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: col)),
                            Text(b > 0 ? 'Usne Dena Hai' : (b < 0 ? 'Humne Dena Hai' : 'Hisaab Barabar'), style: TextStyle(fontSize: 14, color: col)),
                          ]),
                          onTap: () => widget.pick
                              ? Navigator.pop(c, x)
                              : Navigator.push(c, MaterialPageRoute(builder: (_) => CustomerPage(x['id'] as int))),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ]),
      );
}

// ---------- customer detail ----------
class CustomerPage extends StatelessWidget {
  final int id;
  const CustomerPage(this.id, {super.key});

  Widget _ic(IconData i, Color c, String t, VoidCallback f) => Expanded(
          child: InkWell(
        onTap: f,
        child: Column(children: [CircleAvatar(radius: 30, backgroundColor: c, child: Icon(i, color: Colors.white, size: 32)), const SizedBox(height: 4), Text(t, style: const TextStyle(fontSize: 16))]),
      ));

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: DB.tick,
        builder: (context, _, __) => FutureBuilder<List<dynamic>>(
          future: Future.wait([DB.customer(id), DB.entries(id)]),
          builder: (context, s) {
            if (!s.hasData || s.data![0] == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
            final c = s.data![0] as M;
            final es = s.data![1] as List<M>;
            final b = bal(c);
            final col = b > 0 ? green : (b < 0 ? red : Colors.grey);
            final phone = '${c['phone'] ?? ''}';
            return Scaffold(
              appBar: AppBar(title: Text('${c['name']}'), actions: [
                IconButton(
                    iconSize: 32,
                    icon: const Icon(Icons.delete),
                    onPressed: () async {
                      if (await confirm(context, 'Pakka Delete Karna Hai?') && context.mounted) {
                        await DB.softDelete(id);
                        if (context.mounted) {
                          Navigator.pop(context);
                          snack(context, 'Recycle Bin mein chala gaya (30 din tak wapis mil sakta hai)');
                        }
                      }
                    })
              ]),
              body: Column(children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    avatar(c, 56),
                    const SizedBox(height: 8),
                    Text(rs(b.abs()), style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: col)),
                    Text(b > 0 ? 'Usne Dena Hai • اس نے دینا ہے' : (b < 0 ? 'Humne Dena Hai • ہم نے دینا ہے' : 'Hisaab Barabar'), style: TextStyle(fontSize: 20, color: col)),
                    const SizedBox(height: 12),
                    Row(children: [
                      _ic(Icons.phone, green, 'Call', () => phone.isEmpty ? snack(context, 'Number nahi hai') : Svc.call(phone)),
                      _ic(Icons.chat, const Color(0xFF25D366), 'WhatsApp', () {
                        if (phone.isEmpty) return snack(context, 'Number nahi hai');
                        if (b <= 0) return snack(context, 'Is se kuch lena nahi hai');
                        Svc.whatsapp(phone, '${c['name']}', b);
                      }),
                      _ic(Icons.picture_as_pdf, blue, 'PDF', () => Svc.pdf(id: id)),
                    ]),
                  ]),
                ),
                Row(children: [
                  Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: _entryBtn(context, c, 'received', green, Icons.add, 'Paisa Mila'))),
                  Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: _entryBtn(context, c, 'given', red, Icons.remove, 'Udhar Diya'))),
                ]),
                const Divider(height: 24),
                Expanded(
                  child: ListView.builder(
                    itemCount: es.length,
                    itemBuilder: (c, i) {
                      final e = es[i];
                      final given = e['type'] == 'given';
                      return ListTile(
                        leading: Icon(given ? Icons.remove_circle : Icons.add_circle, color: given ? red : green, size: 38),
                        title: Text(rs(e['amount'] as num), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: given ? red : green)),
                        subtitle: Text('${DateFormat('dd-MM-yyyy').format(DateTime.fromMillisecondsSinceEpoch(e['date'] as int))}  ${e['note'] ?? ''}', style: const TextStyle(fontSize: 16)),
                        trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () async {
                              if (await confirm(c, 'Pakka Delete Karna Hai?')) DB.delEntry(e['id'] as int);
                            }),
                      );
                    },
                  ),
                ),
              ]),
            );
          },
        ),
      );

  Widget _entryBtn(BuildContext c, M cust, String type, Color col, IconData ic, String t) => SizedBox(
        height: 64,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: col, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          icon: Icon(ic, size: 32),
          label: Text(t, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => AddEntryPage(cust, type))),
        ),
      );
}

// ---------- add entry ----------
class AddEntryPage extends StatefulWidget {
  final M cust;
  final String type; // given | received
  const AddEntryPage(this.cust, this.type, {super.key});
  @override
  State<AddEntryPage> createState() => _AddEntryPageState();
}

class _AddEntryPageState extends State<AddEntryPage> {
  final amt = TextEditingController(), note = TextEditingController();
  DateTime date = DateTime.now();

  Future<void> save() async {
    final a = double.tryParse(amt.text.replaceAll(',', '').trim());
    if (a == null || a <= 0) return snack(context, 'Rupay likhein / روپے لکھیں');
    await DB.addEntry(widget.cust['id'] as int, a, widget.type, note.text.trim(), date);
    final n = a == a.roundToDouble() ? a.toInt().toString() : a.toString();
    final rec = widget.type == 'received';
    Svc.speak(rec ? '$n روپے جمع ہو گئے' : '$n روپے ادھار لکھ دیے');
    if (!mounted) return;
    snack(context, rec ? '$n Rupay Jama Ho Gaye' : '$n Rupay Udhar Likh Diye');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final rec = widget.type == 'received';
    final col = rec ? green : red;
    return Scaffold(
      appBar: AppBar(backgroundColor: col, title: Text(rec ? 'Paisa Mila • پیسے ملے' : 'Udhar Diya • ادھار دیا')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Row(children: [avatar(widget.cust, 32), const SizedBox(width: 14), Expanded(child: Text('${widget.cust['name']}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)))]),
        const SizedBox(height: 24),
        TextField(
          controller: amt,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: col),
          decoration: InputDecoration(labelText: 'Kitne Rupay? • کتنے روپے؟', prefixText: 'Rs ', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
        ),
        const SizedBox(height: 16),
        TextField(controller: note, style: const TextStyle(fontSize: 22), decoration: InputDecoration(labelText: 'Note (zaroori nahi)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(60)),
          icon: const Icon(Icons.calendar_today, size: 28),
          label: Text(DateFormat('dd-MM-yyyy').format(date), style: const TextStyle(fontSize: 22)),
          onPressed: () async {
            final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 1)));
            if (d != null) setState(() => date = d);
          },
        ),
        const SizedBox(height: 28),
        SizedBox(height: 72, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: col, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), icon: const Icon(Icons.check, size: 36), label: const Text('Save / محفوظ کرو', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)), onPressed: save)),
      ]),
    );
  }
}

// ---------- add customer ----------
class AddCustomerPage extends StatefulWidget {
  const AddCustomerPage({super.key});
  @override
  State<AddCustomerPage> createState() => _AddCustomerPageState();
}

class _AddCustomerPageState extends State<AddCustomerPage> {
  final name = TextEditingController(), phone = TextEditingController();
  String? photo;

  Future<void> pick(ImageSource s) async {
    try {
      final f = await ImagePicker().pickImage(source: s, maxWidth: 600, imageQuality: 70);
      if (f == null) return;
      final path = await Svc.savePhoto(f);
      if (mounted) setState(() => photo = path);
    } catch (_) {
      if (mounted) snack(context, 'Photo nahi mili');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Naya Khata • نیا کھاتا')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Center(child: avatar({'photo': photo}, 64)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)), icon: const Icon(Icons.camera_alt, size: 30), label: const Text('Camera', style: TextStyle(fontSize: 20)), onPressed: () => pick(ImageSource.camera))),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)), icon: const Icon(Icons.photo, size: 30), label: const Text('Gallery', style: TextStyle(fontSize: 20)), onPressed: () => pick(ImageSource.gallery))),
          ]),
          const SizedBox(height: 20),
          TextField(controller: name, style: const TextStyle(fontSize: 26), textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: 'Naam • نام', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
          const SizedBox(height: 16),
          TextField(controller: phone, keyboardType: TextInputType.phone, style: const TextStyle(fontSize: 26), decoration: InputDecoration(labelText: 'Phone Number • فون نمبر', prefixIcon: const Icon(Icons.phone, size: 30), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
          const SizedBox(height: 28),
          SizedBox(
              height: 72,
              child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  icon: const Icon(Icons.check, size: 36),
                  label: const Text('Save / محفوظ کرو', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    if (name.text.trim().isEmpty) return snack(context, 'Naam likhein / نام لکھیں');
                    await DB.addCustomer(name.text.trim(), phone.text.trim(), photo);
                    if (mounted) Navigator.pop(context);
                  })),
        ]),
      );
}

// ---------- backup ----------
class BackupPage extends StatefulWidget {
  const BackupPage({super.key});
  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool busy = false;
  Future<void> run(Future<String> Function() f) async {
    setState(() => busy = true);
    String m;
    try {
      m = await f();
    } catch (_) {
      m = 'Internet nahi hai ya masla aaya. Dobara koshish karein.';
    }
    if (mounted) {
      setState(() => busy = false);
      snack(context, m);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Backup • بیک اپ')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: FutureBuilder<DateTime?>(
                  future: Svc.lastBackup(),
                  builder: (c, s) => Text(u == null ? 'Aap bina login chal rahe hain. Backup ke liye Google se login karein.' : '${u.email}\nAakhri backup: ${s.data == null ? 'abhi tak nahi' : DateFormat('dd-MM-yyyy hh:mm a').format(s.data!)}', style: const TextStyle(fontSize: 20)),
                ))),
        if (busy) const LinearProgressIndicator(minHeight: 6),
        BigBtn(green, Icons.cloud_upload, 'ابھی بیک اپ لو', 'Abhi Backup Lo', () => run(Svc.backup)),
        BigBtn(blue, Icons.cloud_download, 'بیک اپ واپس لاؤ', 'Backup Wapis Lao', () async {
          if (await confirm(context, 'Backup wapis lana hai?')) run(Svc.restoreBackup);
        }),
        BigBtn(red, Icons.picture_as_pdf, 'پی ڈی ایف نکالو', 'PDF Nikalo', () => Svc.pdf()),
        if (u == null) BigBtn(Colors.grey.shade700, Icons.login, 'لاگ ان کرو', 'Login Karo', () async {
          (await SharedPreferences.getInstance()).setBool('guest', false);
          guest.value = false;
        }),
      ]),
    );
  }
}

// ---------- settings ----------
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings • سیٹنگ')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ListTile(leading: const Icon(Icons.account_circle, size: 48), title: Text(u?.displayName ?? 'Guest (bina login)', style: const TextStyle(fontSize: 22)), subtitle: Text(u?.email ?? '', style: const TextStyle(fontSize: 16))),
        const Divider(),
        BigBtn(Colors.orange.shade800, Icons.restore_from_trash, 'ری سائیکل بن', 'Recycle Bin (30 din)', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecyclePage()))),
        BigBtn(red, Icons.logout, 'لاگ آؤٹ', 'Logout', () async {
          if (!await confirm(context, 'Pakka Logout Karna Hai?')) return;
          await GoogleSignIn().signOut();
          await FirebaseAuth.instance.signOut();
          final p = await SharedPreferences.getInstance();
          await p.setBool('guest', false);
          await p.setBool('logged_in', false);
          guest.value = false;
        }),
      ]),
    );
  }
}

// ---------- recycle bin ----------
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
                  trailing: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: green), icon: const Icon(Icons.restore), label: const Text('Wapis Lao', style: TextStyle(fontSize: 18)), onPressed: () => DB.restore(x['id'] as int)),
                ));
              }).toList());
            },
          ),
        ),
      );
}
