import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase başlatma hatası: $e");
  }
  runApp(const EngelsizRotaApp());
}

class EngelsizRotaApp extends StatelessWidget {
  const EngelsizRotaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Engelsiz Rota',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const AnaSayfa(),
    );
  }
}

class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  int _secilenIndeks = 0;
  GoogleMapController? _haritaKontroloru;
  String? _secilenEngelTuru;
  final TextEditingController _aciklamaController = TextEditingController();
  
  // 1. DEĞİŞİKLİK: İşaretçiler artık sabit değil, Firestore'dan beslenecek
  Set<Marker> _isaretciler = {};

  // 2. DEĞİŞİKLİK: Uygulama açılır açılmaz verileri çekmek için initState
  @override
  void initState() {
    super.initState();
    _engelleriGetir(); // Kayıtlı engelleri Firebase'den yükle
  }

  // --- FONKSİYONLAR ---

  // 3. DEĞİŞİKLİK: Firebase'den verileri çeken asıl fonksiyon
  Future<void> _engelleriGetir() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('engeller').get();
      
      setState(() {
        _isaretciler = snapshot.docs.map((doc) {
          final data = doc.data();
          // GeoPoint verisini LatLng formatına çeviriyoruz
          GeoPoint gp = data['konum']; 
          
          return Marker(
            markerId: MarkerId(doc.id),
            position: LatLng(gp.latitude, gp.longitude),
            infoWindow: InfoWindow(
              title: data['tur'],
              snippet: data['aciklama'],
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          );
        }).toSet();
      });
    } catch (e) {
      debugPrint("Veri çekme hatası: $e");
    }
  }

  Future<Position> _mevcutKonumuAl() async {
    bool servis = await Geolocator.isLocationServiceEnabled();
    if (!servis) return Future.error('Konum servisi kapalı.');

    LocationPermission izin = await Geolocator.checkPermission();
    if (izin == LocationPermission.denied) {
      izin = await Geolocator.requestPermission();
      if (izin == LocationPermission.denied) return Future.error('İzin verilmedi.');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
      timeLimit: const Duration(seconds: 15), // Süreyi biraz uzattık
    );
  }

  void _konumumaGit() async {
    try {
      Position pos = await _mevcutKonumuAl();
      _haritaKontroloru?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(pos.latitude, pos.longitude),
            zoom: 16.5,
          ),
        ),
      );
    } catch (e) {
      debugPrint("Konum Hatası: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    }
  }

  void _haritadanEngelBildir(LatLng konum) {
    _secilenEngelTuru = null;
    _aciklamaController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 20, left: 20, right: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Yeni Engel Bildir', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              decoration: _inputDekorasyonu(Icons.category, "Engel Türü"),
              items: ['Bozuk Rampa', 'Yüksek Kaldırım', 'Hatalı Park']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => _secilenEngelTuru = v,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _aciklamaController,
              decoration: _inputDekorasyonu(Icons.edit, "Açıklama"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (_secilenEngelTuru == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen bir engel türü seçin!')));
                  return;
                }

                try {
                  await FirebaseFirestore.instance.collection('engeller').add({
                    'konum': GeoPoint(konum.latitude, konum.longitude),
                    'tur': _secilenEngelTuru,
                    'aciklama': _aciklamaController.text,
                    'tarih': FieldValue.serverTimestamp(),
                  }).timeout(const Duration(seconds: 10));

                  // 4. DEĞİŞİKLİK: Kayıt sonrası listeyi hemen güncelle
                  _engelleriGetir(); 

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Engel başarıyla kaydedildi! ✅')));
                  }
                } catch (e) {
                  debugPrint("FIREBASE HATASI: $e");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bağlantı Hatası: $e')));
                  }
                }
              },
              child: const Text('KAYDET'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- TASARIM YARDIMCILARI ---
  InputDecoration _inputDekorasyonu(IconData ikon, String label) => InputDecoration(
    labelText: label, prefixIcon: Icon(ikon, color: Colors.blueAccent),
    filled: true, fillColor: Colors.grey[50],
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
  );

  Widget _bilgiKarti(String baslik, String deger, Color renk) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: renk.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: renk.withOpacity(0.3)),
      ),
      child: Column(children: [
        Text(deger, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: renk)),
        Text(baslik, style: const TextStyle(fontSize: 12)),
      ]),
    ),
  );

  Widget _menuElemani(IconData ikon, String baslik, String alt, VoidCallback basildiginda) => Card(
    elevation: 0, margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
    child: ListTile(
      leading: Icon(ikon, color: Colors.blueAccent),
      title: Text(baslik, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(alt, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: basildiginda,
    ),
  );

  // --- SAYFA GÖSTERİCİ ---
  Widget _sayfaGoster(int indeks) {
    switch (indeks) {
      case 0:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Merhaba 👋', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const Text('Şehrini herkes için erişilebilir kıl.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 25),
            Row(children: [
              _bilgiKarti('Aktif Engel', '24', Colors.red),
              const SizedBox(width: 15),
              _bilgiKarti('Çözülenler', '156', Colors.green),
            ]),
            const SizedBox(height: 25),
            const Text('Hızlı İşlemler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            _menuElemani(Icons.map, 'Haritayı İncele', 'Güvenli rotaları gör', () => setState(() => _secilenIndeks = 1)),
            _menuElemani(Icons.report_problem, 'Hızlı Bildir', 'Haritaya uzun basarak ekle', () => setState(() => _secilenIndeks = 1)),
          ]),
        );
      case 1:
        return GoogleMap(
          onMapCreated: (c) => _haritaKontroloru = c,
          initialCameraPosition: const CameraPosition(target: LatLng(41.0082, 28.9784), zoom: 13),
          markers: _isaretciler, // Firestore'dan gelen listeyi kullanıyor
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
          },
          onLongPress: (LatLng pos) {
            _haritadanEngelBildir(pos);
          },
        );
      case 2:
        return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text("Engel bildirmek için Harita sekmesine gidip konuma uzun basınız.", textAlign: TextAlign.center)));
      case 3:
        return Column(children: [
          Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30))),
            child: const Column(children: [
              CircleAvatar(radius: 50, backgroundColor: Colors.white, child: Icon(Icons.person, size: 60, color: Colors.blueAccent)),
              SizedBox(height: 15),
              Text('Engelsiz Gönüllü', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ]),
          ),
          const SizedBox(height: 30),
          ListTile(leading: const Icon(Icons.history, color: Colors.blueAccent), title: const Text('Bildirim Geçmişi'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
          ListTile(leading: const Icon(Icons.workspace_premium, color: Colors.blueAccent), title: const Text('Rozetlerim'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
          const Spacer(),
          TextButton(onPressed: () {}, child: const Text('Çıkış Yap', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
          const SizedBox(height: 20),
        ]);
      default:
        return const Center(child: Text('Sayfa Bulunamadı'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Engelsiz Rota'), backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, centerTitle: true),
      body: _sayfaGoster(_secilenIndeks),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _secilenIndeks,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blueAccent,
        onTap: (i) => setState(() => _secilenIndeks = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Giriş'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Harita'),
          BottomNavigationBarItem(icon: Icon(Icons.report), label: 'Bildir'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
      floatingActionButton: _secilenIndeks == 1
          ? FloatingActionButton(onPressed: _konumumaGit, backgroundColor: Colors.blueAccent, child: const Icon(Icons.my_location, color: Colors.white))
          : null,
    );
  }
}