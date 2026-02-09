import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:amuse_booking/screens/login_screen.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'firebase_options.dart';
import 'package:flutter/foundation.dart' show kIsWeb;


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // WebではStripe初期化をスキップ
  if (!kIsWeb) {
    Stripe.publishableKey = 'pk_test_...';
    await Stripe.instance.applySettings();
  }

  runApp(const MyApp());
}




class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Amuse Booking',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

