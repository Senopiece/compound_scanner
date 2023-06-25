import 'package:compound_scanner/screens/camera_picture.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      home: const CameraPictureScreen(),
    ),
  );
}
