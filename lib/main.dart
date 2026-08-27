/// Entry point do aplicativo EROS.
///
/// Executa o bootstrap e, em seguida, `runApp` com o widget raiz.
/// Falhas não tratadas são capturadas em `runZonedGuarded` e logadas
/// via [Logger] antes que o processo continue (o que geralmente
/// resulta em crash, mas o log fica gravado).
import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app.dart';
import 'bootstrap/app_bootstrap.dart';
import 'core/utils/logger.dart';

Future<void> main() async {
  runZonedGuarded<void>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      final bootstrap = await AppBootstrap.run();
      runApp(ErosApp(bootstrapState: bootstrap));
    },
    (error, stackTrace) {
      Logger.wtf('Erro não tratado no main', stackTrace: stackTrace);
    },
  );
}
