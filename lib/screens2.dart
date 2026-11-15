import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db.dart';
import 'main.dart';
import 'screens.dart';
import 'svc.dart';

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
            if (!s.hasData || s.data! == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
            final c = s.data! as M;
            final es = s.data! as List<M>;
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
class AddEntryPage extends StatefulWidget {
  final M cust;
  final String type;
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
    await Svc.showDailyAd();
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
    final u = Svc.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Backup • بیک اپ')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: FutureBuilder<DateTime?>(
                  future: Svc.lastBackup(),
                  builder: (c, s) => Text(
                      u == null
                          ? 'Aap abhi offline chal rahe hain. PDF nikalkar WhatsApp par bhi backup mehfooz kar sakte hain.'
                          : '${u.email}\nAakhri backup: ${s.data == null ? 'abhi tak nahi' : DateFormat('dd-MM-yyyy hh:mm a').format(s.data!)}',
                      style: const TextStyle(fontSize: 20)),
                ))),
        if (busy) const LinearProgressIndicator(minHeight: 6),
        BigBtn(green, Icons.cloud_upload, 'ابھی بیک اپ لو', 'Abhi Backup Lo', () => run(Svc.backup)),
        BigBtn(blue, Icons.cloud_download, 'بیک اپ واپس لاؤ', 'Backup Wapis Lao', () async {
          if (await confirm(context, 'Backup wapis lana hai?')) run(Svc.restoreBackup);
        }),
        BigBtn(red, Icons.picture_as_pdf, 'پی ڈی ایف نکالو', 'PDF Nikalo', () => Svc.pdf()),
        if (u == null)
          BigBtn(Colors.grey.shade700, Icons.login, 'لاگ ان کرو', 'Login Karo', () async {
            (await SharedPreferences.getInstance()).setBool('guest', false);
            guest.value = false;
          }),
      ]),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final u = Svc.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings • سیٹنگ')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ListTile(
            leading: const Icon(Icons.account_circle, size: 48),
            title: Text(u?.displayName ?? 'Offline User', style: const TextStyle(fontSize: 22)),
            subtitle: Text(u?.email ?? 'Bina login mode', style: const TextStyle(fontSize: 16))),
        const Divider(),
        ValueListenableBuilder<bool>(
          valueListenable: isPro,
          builder: (c, pro, _) => BigBtn(
            pro ? green : Colors.purple.shade700,
            pro ? Icons.verified : Icons.workspace_premium,
            pro ? 'پرو پیکج فعال ہے ✔' : 'ایڈ فری پرو (Rs 350/ماہ)',
            pro ? 'Ad-Free Pro Active' : 'No Ads • Rs 350 / Month',
            pro
                ? () => snack(context, 'Aap pehle se Pro (Ad-Free) member hain!')
                : () async {
                    final msg = await Svc.buyPro();
                    if (context.mounted) snack(context, msg);
                  },
          ),
        ),
        BigBtn(Colors.orange.shade800, Icons.restore_from_trash, 'ری سائیکل بن', 'Recycle Bin (30 din)',
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecyclePage()))),
        BigBtn(red, Icons.logout, 'لاگ آؤٹ', 'Logout', () async {
          
