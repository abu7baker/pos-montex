import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database/db_provider.dart';
import 'payment_methods.dart';

final branchPaymentMethodsProvider = StreamProvider<List<PaymentMethodOption>>((
  ref,
) {
  final db = ref.watch(appDbProvider);
  final controller = StreamController<List<PaymentMethodOption>>.broadcast();

  String selectedBranchKey = '';
  Map<String, List<PaymentMethodOption>> methodsByBranch = const {};

  void emit() {
    if (controller.isClosed) return;
    final branchMethods = methodsByBranch[selectedBranchKey];
    controller.add(
      branchMethods != null && branchMethods.isNotEmpty
          ? branchMethods
          : PaymentMethods.options,
    );
  }

  final branchSelectionSub = db.watchSetting('branch_selection_key').listen((
    value,
  ) {
    selectedBranchKey = (value ?? '').trim();
    emit();
  });

  final methodsSub = db.watchSetting('branch_payment_methods_json').listen((
    value,
  ) {
    methodsByBranch = decodeBranchPaymentMethodsMap(value);
    emit();
  });

  ref.onDispose(() async {
    await branchSelectionSub.cancel();
    await methodsSub.cancel();
    await controller.close();
  });

  emit();
  return controller.stream;
});

final currentPaymentMethodLabelMapProvider = Provider<Map<String, String>>((
  ref,
) {
  final methods =
      ref.watch(branchPaymentMethodsProvider).valueOrNull ??
      PaymentMethods.options;
  return {
    for (final method in methods)
      PaymentMethods.normalizeCode(method.code): method.label,
  };
});
