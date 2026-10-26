import 'package:display_app/screens/ask_root_password_screen.dart';
import 'package:display_app/screens/cloud_config_provider.dart';
import 'package:display_app/screens/cloud_info_screen.dart';
import 'package:display_app/utils/cloud_connector.dart';
import 'package:flutter/material.dart';
import 'package:display_app/screens/charging_dashboard_screen.dart';
import 'package:display_app/screens/lan_info_screen.dart';
import 'package:display_app/screens/landing_screen.dart';
import 'package:display_app/screens/language_picker_screen.dart';
import 'package:display_app/screens/session_detail.dart';
import 'package:display_app/widgets/simulation_panel.dart';
import 'package:display_app/screens/system_info.dart';
import 'package:display_app/screens/wifi_setup_screen.dart';

class AppRoutes {
  static const languagePickerScreen = '/language_picker_screen';
  static const landingScreen = '/landing_screen';
  static const lanInfoScreen = '/lan_info_screen';
  static const simulationScreen = '/simulation_screen';
  static const wifiSetupScreen = '/wifi_setup_screen';
  static const systemInfo = '/system_info';
  static const sessionDetailScreen = '/session_detail_screen';
  static const configSelectionScreen = '/config_selection_screen';
  static const chargingDashboardScreen = '/charging_dashboard_screen';
  static const askRootPasswordScreen = "/ask_root_password_screen";
  static const configureCloudConnectionScreen =
      "/configureCloudConnectionScreen";
  static const simpleCloudConfigScreen = "/simple_cloud_config_screen";
  static const simpleFurtherSettingsScreen = "/simple_further_settings_screen";
  static const advancedCloudConfigScreen = "/advanced_cloud_config_screen";
}

class AppRouter {
  static Route<dynamic>? onGenerateRoute(
    RouteSettings settings,
  ) {
    switch (settings.name) {
      case AppRoutes.landingScreen:
        return MaterialPageRoute<dynamic>(
          builder: (_) => const LandingScreen(),
          settings: settings,
          fullscreenDialog: true,
        );
      case AppRoutes.lanInfoScreen:
        return MaterialPageRoute<dynamic>(
          builder: (_) => const LanInfoScreen(),
          settings: settings,
          fullscreenDialog: true,
        );
      case AppRoutes.chargingDashboardScreen:
        return MaterialPageRoute<dynamic>(
          builder: (_) => const ChargingDashboardScreen(),
          settings: settings,
          fullscreenDialog: true,
        );
      case AppRoutes.simulationScreen:
        return MaterialPageRoute<dynamic>(
          builder: (_) => const SimulationPanel(),
          settings: settings,
          fullscreenDialog: true,
        );
      case AppRoutes.languagePickerScreen:
        return MaterialPageRoute<dynamic>(
          builder: (_) => const LanguagePickerScreen(),
          settings: settings,
          fullscreenDialog: true,
        );
      case AppRoutes.sessionDetailScreen:
        return MaterialPageRoute<dynamic>(
          builder: (_) => const SessionDetail(),
          settings: settings,
          fullscreenDialog: true,
        );
      case AppRoutes.configSelectionScreen:
        return MaterialPageRoute<dynamic>(
          builder: (_) => SystemInfo(initialTab: 2),
          settings: settings,
          fullscreenDialog: true,
        );
      case AppRoutes.wifiSetupScreen:
        return MaterialPageRoute<dynamic>(
          builder: (_) => const WifiSetupScreen(),
          settings: settings,
          fullscreenDialog: true,
        );
      case AppRoutes.systemInfo:
        return MaterialPageRoute<dynamic>(
          builder: (_) => SystemInfo(),
          settings: settings,
          fullscreenDialog: true,
        );
      case AppRoutes.askRootPasswordScreen:
        return MaterialPageRoute(
            builder: (_) => AskRootPasswordScreen(),
            settings: settings,
            fullscreenDialog: true);
      case AppRoutes.configureCloudConnectionScreen:
        return MaterialPageRoute(
            builder: (_) => CloudInfoScreen(),
            settings: settings,
            fullscreenDialog: true);
      case AppRoutes.simpleCloudConfigScreen:
        final EnrollMode? mode = settings.arguments as EnrollMode?;
        return MaterialPageRoute(
            builder: (_) => SimpleConfigProvider(mode: mode ?? EnrollMode.normal),
            settings: settings,
            fullscreenDialog: true);
      case AppRoutes.simpleFurtherSettingsScreen when rfc7030Enabled:
        final config = settings.arguments as ConfigArgWrapper;
        return MaterialPageRoute(
            builder: (_) => SimpleFurtherSettings(config),
            settings: settings,
            fullscreenDialog: true);
      case AppRoutes.advancedCloudConfigScreen when rfc7030Enabled:
        final EnrollMode? mode = settings.arguments as EnrollMode?;
        return MaterialPageRoute(
            builder: (_) => AdvancedConfigProvider(mode: mode ?? EnrollMode.normal),
            settings: settings,
            fullscreenDialog: true);

      default:
        // TODO: Throw
        return null;
    }
  }
}
