import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers/cloud_enrollment_provider.dart';
import '../utils/cloud_connector.dart';
import '../utils/datetime_formats.dart';
import '../screens/cloud_info_screen.dart';

class Footer extends ConsumerStatefulWidget {
  final bool isOnline;
  final VoidCallback? onCloudTap;
  final String selectedProtocolString;

  const Footer({
    super.key,
    this.isOnline = true,
    this.onCloudTap,
    this.selectedProtocolString = "",
  });

  @override
  ConsumerState<Footer> createState() => _FooterState();
}

class _FooterState extends ConsumerState<Footer> {
  // ignore: unused_field
  late Timer _timer;

  void startTimer() {
    const oneSec = Duration(seconds: 1);
    _timer = Timer.periodic(
      oneSec,
      (Timer timer) {
        setState(() {});
      },
    );
  }

  @override
  void initState() {
    startTimer();
    super.initState();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cloudAvailable = ref.watch(cloudConnectorAvailableProvider);
    final cloudState =
        cloudAvailable ? ref.watch(cloudEnrollmentProvider).valueOrNull : null;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              runAlignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _badge(
                      context,
                      label: widget.isOnline ? 'online'.tr() : 'offline'.tr(),
                      background: widget.isOnline
                          ? Theme.of(context).colorScheme.tertiaryContainer
                          : Theme.of(context).colorScheme.errorContainer,
                      foreground: widget.isOnline
                          ? Theme.of(context).colorScheme.onTertiaryContainer
                          : Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    if (cloudAvailable)
                      _badge(
                        context,
                        label: switch (cloudState) {
                          CloudConnectorState.enrolled => 'cloud_enrolled'.tr(),
                          CloudConnectorState.notEnrolled =>
                            'cloud_not_enrolled'.tr(),
                          _ => 'cloud_unknown'.tr(),
                        },
                        background: switch (cloudState) {
                          CloudConnectorState.enrolled =>
                            Theme.of(context).colorScheme.tertiaryContainer,
                          CloudConnectorState.notEnrolled =>
                            Theme.of(context).colorScheme.errorContainer,
                          _ => Theme.of(context).colorScheme.surfaceContainer,
                        },
                        foreground: switch (cloudState) {
                          CloudConnectorState.enrolled =>
                            Theme.of(context).colorScheme.onTertiaryContainer,
                          CloudConnectorState.notEnrolled =>
                            Theme.of(context).colorScheme.onErrorContainer,
                          _ => Theme.of(context).colorScheme.onSurfaceVariant,
                        },
                        onTap: widget.onCloudTap,
                        interactive: true,
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text(
                    widget.selectedProtocolString,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text(
                    dateTimeFormat.format(DateTime.now()),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontFeatures: [const FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(
    BuildContext context, {
    required String label,
    required Color background,
    required Color foreground,
    VoidCallback? onTap,
    bool interactive = false,
  }) {
    final text = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Text(
        label,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: foreground,
            ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: interactive
            ? Semantics(
                button: true,
                child: InkWell(
                  onTap: onTap ?? () => goToCloud(context),
                  child: text,
                ),
              )
            : text,
      ),
    );
  }
}
