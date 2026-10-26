import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/cloud_connector.dart';

final cloudConnectorAvailableProvider = Provider.autoDispose<bool>(
  (ref) => CloudConnector.available,
);

final cloudConnectorStateQueryProvider =
    Provider.autoDispose<Future<CloudConnectorState> Function()>(
  (ref) => CloudConnector.state,
);

/// Checks immediately, then waits ten seconds after each completed check.
final cloudEnrollmentProvider =
    StreamProvider.autoDispose<CloudConnectorState>((ref) {
  if (!ref.watch(cloudConnectorAvailableProvider)) return const Stream.empty();
  final query = ref.watch(cloudConnectorStateQueryProvider);
  final controller = StreamController<CloudConnectorState>();
  Timer? timer;
  var disposed = false;

  Future<void> check() async {
    CloudConnectorState state;
    try {
      state = await query();
    } catch (_) {
      state = CloudConnectorState.notReady;
    }
    if (disposed) return;
    controller.add(state);
    timer = Timer(const Duration(seconds: 10), check);
  }

  ref.onDispose(() {
    disposed = true;
    timer?.cancel();
    unawaited(controller.close());
  });
  unawaited(check());
  return controller.stream;
});
