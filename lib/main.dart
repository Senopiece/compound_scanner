import 'screens/image_pick.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      onGenerateRoute: (settings) => MaterialPageRoute(
        maintainState: false,
        builder: (context) => const ImagePickScreen(),
      ),
    ),
  );
}
