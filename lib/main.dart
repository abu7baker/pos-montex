import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/router/app_router.dart';
import 'app/router/app_routes.dart';
import 'features/pos/printing/print_job_runner.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MontexApp()));
}

class MontexApp extends StatefulWidget {
  const MontexApp({super.key});

  @override
  State<MontexApp> createState() => _MontexAppState();
}

class _MontexAppState extends State<MontexApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        ref.watch(printJobRunnerProvider);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Montex POS',
          theme: ThemeData(fontFamily: 'Tajawal'),
          onGenerateRoute: onGenerateRoute,
          initialRoute: AppRoutes.splash,
          builder: (context, child) {
            final media = MediaQuery.of(context);
            final width = media.size.width;
            final scale = (width / 1366).clamp(0.9, 1.15);
            return MediaQuery(
              data: media.copyWith(textScaler: TextScaler.linear(scale)),
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}
