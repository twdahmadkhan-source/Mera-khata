import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'package:url_launcher/url_launcher.dart';
import 'db.dart';

const green = Color(0xFF1B9E4B), red = Color(0xFFD32F2F), blue = Color(0xFF1565C0);
final guest = ValueNotifier<bool>(false);

class Svc {
  static final _tts = FlutterTts();

  static Future<void> speak(String t) async {
    try {
      await _tts.setLanguage('ur-PK');
      await _tts.speak(t);
    } catch (_) {}
  }

  static Future<String?> savePhoto(XFile f) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final path = p.join(dir.path, 'ph_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await f.saveTo(path);
      return path;
    } catch (_) {
      return null;
    }
  }

  static String _num(String phone) {
    var d = phone.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('0')) d = '92${d.substring(1)}';
    return d;
  }

  static Future<void> call(String phone) => launchUrl(Uri.parse('tel:$phone'));

  static Future<void> whatsapp(String phone, String name, double bal) => launchUrl(
      Uri.parse('https://wa.me/${_num(phone)}?text=${Uri.encodeComponent('Salam $name bhai, aapke ${bal.abs().toStringAsFixed(0)} rupay baaki hain')}'),
      mode: LaunchMode.externalApplication);

  // ---------- Backup (Firestore, linked to user's Gmail account) ----------
  static Future<String> backup() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return 'Backup ke liye Google se login karein';
    final d = await DB.db;
    final root = FirebaseFirestore.instance.collection('users').doc(u.uid);
    var batch = FirebaseFirestore.instance.batch();
    var n = 0;
    for (final c in await d.query('customers')) {
      final es = await d.query('entries', where: 'customer_id=?', whereArgs: [c['id']]);
      batch.set(root.collection('customers').doc('${c['id']}'), {...c, 'photo': null, 'entries': es});
      if (++n % 100 == 0) {
        await batch.commit();
        batch = FirebaseFirestore.instance.batch();
      }
    }
    await batch.commit();
    await root.set({'last_backup': FieldValue.serverTimestamp(), 'email': u.email}, SetOptions(merge: true));
    (await SharedPreferences.getInstance()).setInt('last_backup', DateTime.now().millisecondsSinceEpoch);
    return 'Backup ho gaya ✔';
  }

  /// Runs on app open / when app goes to background: at most once per ~20 hours.
  static Future<void> autoBackup() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    final last = (await SharedPreferences.getInstance()).getInt('last_backup') ?? 0;
    if (DateTime.now().millisecondsSinceEpoch - last > 20 * 3600 * 1000) {
      try {
        await backup();
      } catch (_) {}
    }
  }

  static Future<String> restoreBackup() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return 'Pehle Google se login karein';
    final snap = await FirebaseFirestore.instance.collection('users').doc(u.uid).collection('customers').get();
    if (snap.docs.isEmpty) return 'Koi backup nahi mila';
    final d = await DB.db;
    await d.transaction((t) async {
      for (final doc in snap.docs) {
        final m = doc.data();
        final es = List<Map<String, dynamic>>.from((m['entries'] ?? []).map((e) => Map<String, dynamic>.from(e)));
        m.remove('entries');
        await t.insert('customers', m, conflictAlgorithm: ConflictAlgorithm.replace);
        await t.delete('entries', where: 'customer_id=?', whereArgs: [m['id']]);
        for (final e in es) {
          await t.insert('entries', e, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
    DB.bump();
    return 'Khata wapis aa gaya ✔';
  }

  static Future<DateTime?> lastBackup() async {
    final v = (await SharedPreferences.getInstance()).getInt('last_backup');
    return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v);
  }

  // ---------- PDF ----------
  // NOTE: default PDF font has no Urdu letters. Names written in Urdu script need
  // a bundled Urdu font (e.g. Noto Nastaliq Urdu) via pw.Font.ttf(...).
  static Future<void> pdf({int? id}) async {
    final all = await DB.customers();
    final list = id == null ? all : all.where((c) => c['id'] == id).toList();
    final df = DateFormat('dd-MM-yyyy');
    final bold = pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold);
    final w = <pw.Widget>[
      pw.Text('Mera Khata - ${df.format(DateTime.now())}', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 12),
    ];
    for (final c in list) {
      final b = (c['balance'] as num).toDouble();
      w.add(pw.Text('${c['name']} (${c['phone']}) - ${b >= 0 ? 'Usne dena hai' : 'Humne dena hai'}: Rs ${b.abs().toStringAsFixed(0)}', style: bold));
      final es = await DB.entries(c['id'] as int);
      w.add(pw.TableHelper.fromTextArray(
          headers: ['Tareekh', 'Qism', 'Rupay', 'Note'],
          data: es
              .map((e) => [
                    df.format(DateTime.fromMillisecondsSinceEpoch(e['date'] as int)),
                    e['type'] == 'given' ? 'Udhar Diya' : 'Paisa Mila',
                    '${(e['amount'] as num).toStringAsFixed(0)}',
                    '${e['note'] ?? ''}'
                  ])
              .toList()));
      w.add(pw.SizedBox(height: 14));
    }
    final doc = pw.Document()..addPage(pw.MultiPage(build: (_) => w));
    await Printing.sharePdf(bytes: await doc.save(), filename: 'mera_khata.pdf');
  }
}
