import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('Platform desteklenmiyor');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyDO-yzz6pffCx3bH-hi77kCz9SDCtoJPbk",
    appId: "1:30495525463:android:29c213c371acd2ac9f7112",
    messagingSenderId: '30495525463',
    projectId: 'engelsiz-rota',
    storageBucket: "engelsiz-rota.firebasestorage.app",
  );
}