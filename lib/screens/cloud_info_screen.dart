import 'package:display_app/screens/cloud_config_provider.dart';
import 'package:display_app/utils/cloud_connector.dart';
import 'package:display_app/widgets/buttons.dart';
import 'package:flutter/material.dart';

import '../utils/routing/app_router.dart';

class CloudInfoScreen extends StatelessWidget {
  const CloudInfoScreen({super.key});

  Widget buildSelectionButton(BuildContext context, {
    required String name,
    required String desc,
    required IconData icon,
    required void Function() onPressed,
  }){
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            style: BorderStyle.solid,
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Text(name,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              Center(
                child: Text(desc,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: Icon(icon,
                  size: 128,
                ),
              ),
              ElevatedButton(
                onPressed: onPressed,
                child: Text("Connect to Cloud"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PionixAppBar('Connect to Cloud'),
      body: Row(
        children: [
          Expanded(
            child: buildSelectionButton(context,
              name: "OTP Enrollment",
              desc: "Simple non-production enrollment using an OTP",
              icon: Icons.timelapse_outlined,
              onPressed: () => goToEnrollmentScreen(context, true),
            ),
          ),
          if (rfc7030Enabled) Expanded(
            child: buildSelectionButton(context,
              name: "RFC 7030",
              desc: "Advanced Production-Grade enrollment using RFC7030",
              icon: Icons.lock_rounded,
              onPressed: () {
                if (configSupported) {
                  goToEnrollmentScreen(context, false);
                } else {
                  Navigator.pushNamed(context, AppRoutes.advancedCloudConfigScreen);
                }
              },
            ),
          ),
        ],
      )
    );
  }

  void goToEnrollmentScreen(BuildContext context, bool toOtp) {
    if (toOtp) {
      goToOtpEnrollment(context);
      return;
    }
    const route = AppRoutes.advancedCloudConfigScreen;
    if (checkFileExists("/etc/mosquitto/client.crt")) {
      showAlreadyEnrolledDialog(
        context,
        route: route,
        text: "Certificate files already exist. Do you want to (re)start the mqtt connection or request new certificates?",
        restartLabel: "(re)start mqtt connection",
      );
    } else {
      Navigator.pushNamed(context, route, arguments: EnrollMode.normal);
    }
  }

}

/// Shared entry point for Settings and the dashboard enrollment badge.
void goToCloud(
  BuildContext context, {
  bool? enableRfc7030,
  Future<CloudConnectorState> Function()? readState,
}) {
  if (enableRfc7030 ?? rfc7030Enabled) {
    Navigator.pushNamed(context, AppRoutes.configureCloudConnectionScreen);
  } else {
    goToOtpEnrollment(context, readState: readState);
  }
}

/// Opens the OTP enrollment. If cloud-connector reports the charger as
/// enrolled already, the user can choose between restart and re-enrollment.
Future<void> goToOtpEnrollment(
  BuildContext context, {
  Future<CloudConnectorState> Function()? readState,
}) async {
  final query = readState ?? CloudConnector.state;
  const route = AppRoutes.simpleCloudConfigScreen;
  var state = await query();
  while (state == CloudConnectorState.notReady) {
    if (!context.mounted) return;
    if (!await showCloudConnectorNotReadyDialog(context)) return;
    state = await query();
  }
  if (!context.mounted) return;
  if (state == CloudConnectorState.enrolled) {
    showAlreadyEnrolledDialog(
      context,
      route: route,
      text: "This charger is already enrolled. Do you want to (re)start the cloud connection or re-enroll the charger?",
      restartLabel: "(re)start cloud connection",
    );
  } else {
    Navigator.pushNamed(context, route, arguments: EnrollMode.normal);
  }
}

void showAlreadyEnrolledDialog(BuildContext context, {
  required String route,
  required String text,
  required String restartLabel,
}) {
  showGeneralDialog(
    context: context,
    barrierLabel: "otp_popup_barrier",
    barrierDismissible: true,
    pageBuilder: (context, animation, secondaryAnimation) {
      return Dialog(
        child: SizedBox(
          height: 300,
          width: 500,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 24,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.arrow_back),
                    ),
                    Expanded(
                      child: Text(
                        "Preexisting certificates found",
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      text,
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, route, arguments: EnrollMode.restart);
                  },
                  child: Text(restartLabel),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, route, arguments: EnrollMode.reEnroll);
                  },
                  child: Text("re-enroll charger"),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

enum EnrollMode {
  normal,
  restart,
  reEnroll,
}

/// Shown if the cloud-connector service is not active or its daemon doesn't
/// answer yet. Lets the user restart the service or wait for it to start up.
/// Returns true once cloud-connector is ready.
Future<bool> showCloudConnectorNotReadyDialog(BuildContext context) async {
  final ready = await showGeneralDialog<bool>(
    context: context,
    barrierLabel: "cloud_connector_not_ready_barrier",
    barrierDismissible: false,
    pageBuilder: (context, animation, secondaryAnimation) =>
        const CloudConnectorNotReadyDialog(),
  );
  return ready ?? false;
}

class CloudConnectorNotReadyDialog extends StatefulWidget {
  const CloudConnectorNotReadyDialog({super.key});

  @override
  State<CloudConnectorNotReadyDialog> createState() => _CloudConnectorNotReadyDialogState();
}

class _CloudConnectorNotReadyDialogState extends State<CloudConnectorNotReadyDialog> {
  bool waiting = false;
  String? error;

  /// Incremented on cancel, so a running wait can tell it's been cancelled.
  int attempt = 0;

  Future<void> waitForReady({required bool restart}) async {
    final currentAttempt = ++attempt;
    bool cancelled() => !mounted || attempt != currentAttempt;
    setState(() {
      waiting = true;
      error = null;
    });
    if (restart) {
      final response = await CloudConnector.restartService();
      if (cancelled()) return;
      if (!response.success) {
        setState(() {
          waiting = false;
          error = "Restarting the cloud connector failed: ${response.error}";
        });
        return;
      }
    }
    final ready = await CloudConnector.waitUntilReady(cancelled: cancelled);
    if (!mounted || cancelled()) return;
    if (ready) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        waiting = false;
        error = "The cloud connector did not become ready within ${CloudConnector.startupTimeout.inSeconds} seconds.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        height: 300,
        width: 500,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 24,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: waiting ? null : () => Navigator.of(context).pop(false),
                    icon: Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Text(
                      "Cloud connector not ready",
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: waiting
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 12,
                          children: [
                            CircularProgressIndicator(),
                            Text(
                              "Waiting for the cloud connector to start...",
                              style: Theme.of(context).textTheme.bodyLarge,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                      : Text(
                          error ?? "The cloud connector service is not running or still starting up. Do you want to restart it or wait for it to start?",
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: (error != null) ? Theme.of(context).colorScheme.error : null,
                          ),
                          textAlign: TextAlign.center,
                        ),
                ),
              ),
              if (waiting)
                ElevatedButton(
                  onPressed: () => setState(() {
                    attempt++;
                    waiting = false;
                  }),
                  child: Text("Cancel"),
                )
              else ...[
                ElevatedButton(
                  onPressed: () => waitForReady(restart: true),
                  child: Text("(re)start cloud connector"),
                ),
                ElevatedButton(
                  onPressed: () => waitForReady(restart: false),
                  child: Text("wait for startup"),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
