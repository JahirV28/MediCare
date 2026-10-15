import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://mbfvsnwnteabnyataqpv.supabase.co',
    publishableKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1iZnZzbndudGVhYm55YXRhcXB2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkxMjc2ODUsImV4cCI6MjEwNDcwMzY4NX0.5Mbgeg1Hje8zhCb_bNaAIXB1-QEhsONfOkpBVLDaxfA',
  );

  runApp(const MediCoreApp());
}
