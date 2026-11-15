import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:image_picker/image_picker.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'package:url_launcher/url_launcher.dart';
import 'db.dart';
import 'main.dart';

const green = Color(0xFF1B9E4B), red = Color(0xFFD32F2F), blue = Color(0xFF1565C0);
final guest = ValueNotifier<bool>(false);
final isPro = ValueNotifier<bool>(false);

class Svc {
  static final _tts = FlutterTts();
  static InterstitialAd? _ad;
  static StreamSubscription<List<PurchaseDetails>>? _sub;

  // Play Store par apni asli AdMob Interstitial ID yahan lagayein
  static const String adUnitId = 'ca-app-pub-3940256099942544/1033173712';
  // Play Console mein banayi gayi Rs 350/month Subscription ID
  static const String proProductId = 'mera_khata_pro_monthly';

  static User? get user => firebaseReady ? FirebaseAuth.instance.currentUser : null;

  static Future<void> initMonetization() async {
    final prefs = await SharedPreferences.getInstance();
    isPro.value = prefs.getBool('is_pro') ?? false;
    try {
      await MobileAds.instance.initialize();
      loadAd();
    } catch (_) {}
    try {
      _sub?.cancel();
      _sub = InAppPurchase.instance.purchaseStream.listen((list) async {
        for (final pur in list) {
          if (pur.status == PurchaseStatus.purchased || pur.status == PurchaseStatus.restored) {
            isPro.value = true;
            await prefs.setBool('is_pro', true);
            if (pur.pendingCompletePurchase) {
              await InAppPurchase.instance.completePurchase(pur);
            }
          }
        }
      });
    } catch (_) {}
  }

  static void loadAd() {
    if (isPro.value) return;
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _ad = ad,
        onAdFailedToLoad: (_) => _ad = null,
      ),
    );
  }

  /// Har user ko din mein maximum 2 ads dikhayega (Pro users ke liye 0 ads)
  static Future<void> showDailyAd() async {
    if (isPro.value) return;
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final savedDay = prefs.getString('ad_day') ?? '';
    int count = savedDay == today ? (prefs.getInt('ad_count') ?? 0) : 0;

    if (count >= 2) return; // Din ke 2 ads poore ho gaye

    if (_ad != null) {
      await prefs.setString('ad_day', today);
      await prefs.setInt('ad_count', count + 1);
      final currentAd = _ad;
      _ad = null;
      currentAd?.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          loadAd();
        },
        onAdFailedToShowFullScreenContent: (ad, _) {
          ad.dispose();
          loadAd();
        },
      );
      await currentAd?.show();
    } else {
      loadAd();
    }
  }

  static Future<String> buyPro() async {
    try {
      final ok = await InAppPurchase.instance.isAvailable();
      if (!ok) return 'Google Play Billing abhi available nahi hai';
      final res = await InAppPurchase.instance.queryProductDetails({proProductId});
      if (res.productDetails.isEmpty) {
        return 'Play Console par "$proProductId" (Rs 350/month) plan set karein';
      }
      final param = PurchaseParam(productDetails: res.productDetails.first);
      await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
      return 'Payment window khul rahi hai...';
    } catch (_) {
      return 'Payment shuru nahi ho saki. Internet check karein.';
    }
  }

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
      Uri.parse('https://wa.me{_num(phone)}?text=${Uri.encodeComponent('Salam $name bhai, aapke ${bal.abs().toStringAsFixed(0)} rupay baaki hain')}'),
      mode: LaunchMode.externalApplication);

  // ---------- Backup (Firestore, linked to user's Gmail account) ----------
  static Future<String> backup() async {
    if (!firebaseReady) return 'Cloud Backup jald active hoga (Firebase setup baqi hai)';
    final u = user;
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

  static Future<void> autoBackup() async {
    if (!firebaseReady || user == null) return;
    final last = (await SharedPreferences.getInstance()).getInt('last_backup') ?? 0;
    if (DateTime.now().millisecondsSinceEpoch - last > 20 * 3600 * 1000) {
      try {
        await backup();
      } catch (_) {}
    }
  }

  static Future<String> restoreBackup() async {
    if (!firebaseReady) return 'Cloud Backup abhi setup nahi hua';
    final u = user;
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
