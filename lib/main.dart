import 'package:flutter/material.dart';

import 'app.dart';
import 'app_providers.dart';
import 'data/local_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await LocalStorage.open();
  runApp(ListaMercadoApp(providers: AppProviders.create(storage)));
}
