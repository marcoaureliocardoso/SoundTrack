import 'package:flutter/material.dart';
import 'package:soundtrack/app/app_dependencies.dart';
import 'package:soundtrack/app/soundtrack_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = await AppDependencies.create();
  runApp(SoundTrackApp(dependencies: dependencies));
}
