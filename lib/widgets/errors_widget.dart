import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:display_app/mqtt.dart';
import 'package:display_app/screens/errors_screen.dart';
import 'package:flutter/material.dart';
import 'package:async/async.dart';

/// EVerest builds external API topics as
/// `everest_api/<version>/<api type>/<module id>/<direction>/<var>`, where m2e
/// carries commands towards EVerest and e2m carries replies and events out of
/// it. `error_history_api` is the module id of the error_history_consumer_API
/// module in the EVerest config.
const String errorApiBase =
    "everest_api/1/error_history_consumer/error_history_api";
const String receiveErrorsTopic = "$errorApiBase/e2m/customReceiveErrorTopic";
const String pollErrorsTopic = "$errorApiBase/m2e/active_errors";

/// a list of all reported errors
List<BasecampError> activeErrors = [];

/// the hash of all active Errors -> if this changes errors changed
int activeErrorsHash = 0;

class ErrorsWidget extends StatefulWidget {
  final List<BasecampError> errors;
  const ErrorsWidget(this.errors, {super.key});

  @override
  State<ErrorsWidget> createState() => _ErrorsWidgetState();
}

class _ErrorsWidgetState extends State<ErrorsWidget> {
  final mqtt = MQTT();
  late final CancelableOperation pollErrorLoop;
  @override
  void initState() {
    super.initState();
    startPolling();
  }

  @override
  void dispose() {
    pollErrorLoop.cancel();
    super.dispose();
  }

  void startPolling() async {
    await mqtt.connect();
    mqtt.subscribe(receiveErrorsTopic, parseErrors);
    pollErrorLoop = CancelableOperation.fromFuture(
      pollErrors(),
      onCancel: () {
        debugPrint("stopped polling for errors");
      },
    );
  }

  Future<void> pollErrors() async {
    // debugPrint("started error polling");
    while (true) {
      mqtt.publish(pollErrorsTopic,
          "{\"headers\":{\"replyTo\":\"$receiveErrorsTopic\"}}");
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  void parseErrors(String message) {
    try {
      activeErrors = [];
      List activeErrorsJson = json.decode(message)["errors"]! as List;
      for (var error in activeErrorsJson) {
        activeErrors.add(BasecampError.fromJson(error));
      }
      activeErrorsHash = ListEquality().hash(activeErrors);
    } catch (e, strace) {
      debugPrint("$e, $strace");
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.errors.isEmpty
        ? const SizedBox.shrink()
        : IconButton(
            color: Theme.of(context).colorScheme.error,
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => ErrorsScreen(widget.errors),
              ));
            },
            icon: Icon(
              Icons.report_problem,
              size: 28,
            ));
  }
}

enum BasecampErrorSeverity { high, medium, low }

enum BasecampErrorState { active, clearedByModule, clearedByReboot }

/// an implementation of the errors specified here: https://docs.pionix.de/BaseCamp-API/error_history_consumer_API/index.html#operations
class BasecampError {
  String type = "";
  String subType = "";
  String description = "";
  String message = "";
  BasecampErrorSeverity severity = BasecampErrorSeverity.low;
  Map<String, dynamic> origin = {};
  DateTime timestamp = DateTime.now();
  String uuid = "";
  BasecampErrorState state = BasecampErrorState.active;

  BasecampError.fromJson(Map<String, dynamic> json) {
    type = json["type"] as String;
    subType = json["sub_type"] as String? ?? "";
    description = json["description"] as String;
    message = json["message"] as String;
    severity = {
      "High": BasecampErrorSeverity.high,
      "Medium": BasecampErrorSeverity.medium,
      "Low": BasecampErrorSeverity.low,
    }[json["severity"] as String]!;
    origin = json["origin"].cast<String, String>();
    timestamp = DateTime.parse(json["timestamp"]);
    uuid = json["uuid"];
    state = {
      "Active": BasecampErrorState.active,
      "ClearedByModule": BasecampErrorState.clearedByModule,
      "ClearedByReboot": BasecampErrorState.clearedByReboot,
    }[json["state"]]!;
  }

  /// two errors are equal if all their properties are equal
  @override
  int get hashCode => (type.hashCode +
      subType.hashCode +
      description.hashCode +
      message.hashCode +
      severity.hashCode +
      timestamp.hashCode +
      uuid.hashCode +
      state.hashCode +
      origin["module_id"].hashCode +
      origin["implementation_id"].hashCode);

  /// implementing hashCode requires to also implement ==
  @override
  bool operator ==(Object other) {
    return (other is BasecampError) && hashCode == other.hashCode;
  }
}
