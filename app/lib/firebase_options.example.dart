// Template. Run `flutterfire configure` in app/ to generate the real
// lib/firebase_options.dart for YOUR Firebase project. The real file is
// git-ignored because it points at a live database.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => const FirebaseOptions(
        apiKey: 'YOUR_API_KEY',
        appId: 'YOUR_APP_ID',
        messagingSenderId: 'YOUR_SENDER_ID',
        projectId: 'YOUR_PROJECT_ID',
        databaseURL: 'https://YOUR-PROJECT-default-rtdb.firebaseio.com',
        storageBucket: 'YOUR_PROJECT_ID.appspot.com',
      );
}
