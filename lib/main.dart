import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:amuse_booking/screens/login_screen.dart';
import 'package:flutter_stripe/flutter_stripe.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  Stripe.publishableKey = 'pk_test_51SN9S71rWFNVgrh2g2BNuUrJ4fU6n3LRU1bbVb4k8moH6bRvns6Yka6kLxRXZGNHaBMairjmrp2PwzhVVu62Hcre00X4P4zHOU';
  await Stripe.instance.applySettings(); // ★追加
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

