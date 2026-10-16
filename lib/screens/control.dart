import 'dart:convert';

import 'package:display_app/utils/routing/app_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:display_app/data/models/config_paths.dart';
import 'package:display_app/data/providers/connector_provider.dart';
import 'package:display_app/mqtt.dart';
import 'package:display_app/utils/constants/helper.dart';
import 'package:display_app/widgets/buttons.dart';

class AnimatedLinearProgressIndicator extends StatefulWidget {
  const AnimatedLinearProgressIndicator({super.key});

  @override
  State<StatefulWidget> createState() =>
      _AnimatedLinearProgressIndicatorState();
}

class _AnimatedLinearProgressIndicatorState
    extends State<AnimatedLinearProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: controller,
        builder: (_, __) => LinearProgressIndicator(value: controller.value));
  }
}

class Control extends ConsumerStatefulWidget {
  const Control({
    super.key,
  });

  @override
  ConsumerState<Control> createState() => _ControlState();
}

class _ControlState extends ConsumerState<Control> {
  final mqtt = MQTT();
  Map<String, List<String>> configInfo = {};
  Map<String, List<String>> configDirInfo = {};
  String loadedConfig = "";
  DateTime lastConfigLoad = DateTime.now();

  @override
  void didChangeDependencies() {
    _connect();
    super.didChangeDependencies();
  }

  @override
  void initState() {
    super.initState();
  }

  void _connect() async {
    try {
      await mqtt.connect();
      mqtt.subscribe("everest_api/control/var/config_paths", parseConfigPaths);
      mqtt.subscribe(
          "everest_api/control/var/selected_config", parseSelectedConfig);

      mqtt.publish("everest_api/control/cmd/get_config_paths", "0");
      mqtt.publish("everest_api/control/cmd/get_selected_config", "0");

      final connector = ref.watch(connectorProvider);
      mqtt.subscribe("everest_api/$connector/var/datetime", handleDateTime);

      // mqtt.subscribe(
      //     "everest_api/setup/var/network_device_info", networkDeviceInfo);

      // enableWifiScanning();
      // scanWifi();
      // listConfiguredNetworks();
    } catch (e) {
      debugPrint('Loading failed, Error: $e');
    }
  }

  void parseConfigPaths(String message) {
    final configPaths = ConfigPaths.fromJson(jsonDecode(message));
    configInfo["configs"] = configPaths.configs;
    configDirInfo = configPaths.config_dirs;
    setState(() {});
  }

  void parseSelectedConfig(String message) {
    loadedConfig = message;
    setState(() {});
  }

  void handleDateTime(String _) {
    if (lastConfigLoad
        .add(const Duration(seconds: 3))
        .isBefore(DateTime.now())) {
      try {
        ScaffoldMessenger.of(context)
            .clearSnackBars(); // this is sometimes called on an unmounted widget state but we just ignore this edgecase
      } catch (e) {
        // this happens if one closes the config screen before the snackbar disappears
      }
    }
  }

  void loadConfig(String config) {
    lastConfigLoad = DateTime.now();
    Map<String, String> changeConfig = {};
    changeConfig["config_path"] = config;
    mqtt.publish("everest_api/control/cmd/change_config",
        json.encode(changeConfig).toString());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 20,
        duration: const Duration(seconds: 5),
        content: Column(
          children: [
            Text('${'loading_config'.tr()}: $config'),
            const AnimatedLinearProgressIndicator(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(
          top: 20,
          right: 10,
          left: 10,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    wrapString('Loaded config: $loadedConfig'),
                    softWrap: true,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(
                top: 5,
                bottom: 20,
              ),
              child: Row(
                children: [
                  PrimaryButton(
                    onPressed: () {
                      mqtt.publish("everest_api/control/cmd/restart", "1");
                    },
                    child: const Text("Restart everest-control.service"),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                    ),
                    child: PrimaryButton(
                      onPressed: () {
                        mqtt.publish(
                            "everest_api/control/cmd/restart_display_app", "1");
                      },
                      child: const Text("Restart display-app.service"),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              "EVerest configurations",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: configInfo.length,
              itemBuilder: (builder, index) {
                String header = configInfo.keys.elementAt(index);
                return ConfigInfoWidget(
                  header: header,
                  configPaths: configInfo.values.elementAt(index),
                  loadConfig: loadConfig,
                );
              },
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: configDirInfo.length,
              itemBuilder: (builder, index) {
                String header = configDirInfo.keys.elementAt(index);
                return ConfigInfoWidget(
                  header: header,
                  configPaths: configDirInfo.values.elementAt(index),
                  loadConfig: loadConfig,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ConfigInfoWidget extends StatelessWidget {
  final String header;
  final List<String> configPaths;
  final Function(String) loadConfig;

  const ConfigInfoWidget({
    super.key,
    required this.header,
    required this.configPaths,
    required this.loadConfig,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Divider(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                header,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
            ),
            Expanded(
              flex: 5,
              child: Divider(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: configPaths.length,
          itemBuilder: (builder, index) {
            String value = configPaths.elementAt(index);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5.0),
              child: Row(
                children: [
                  PrimaryButton(
                    onPressed: () {
                      if (header == "configs") {
                        loadConfig(value);
                      } else {
                        loadConfig("$header/$value");
                      }
                    },
                    child: Text('load'.tr()),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 5,
                    ),
                    child: Text(
                      wrapString(value),
                      softWrap: true,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
