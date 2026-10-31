import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:kankal_ui/kankal_ui.dart';

import '../core/auth/auth_api.dart';
import '../core/auth/mock_auth_api.dart';
import '../core/diagnostics/diagnostics.dart';
import '../core/items/items_api.dart';
import '../core/items/mock_items_api.dart';
import '../features/auth/sign_in_view.dart';
import '../features/items/item_editor_view.dart';
import '../features/items/items_view.dart';
import 'demo_account.dart';
import 'routes.dart';

class AppServices {
  AppServices({
    AuthApi? authApi,
    ItemsApi? itemsApi,
    Diagnostics? diagnostics,
    DemoAccount? demoAccount,
  }) : authApi = authApi ?? MockAuthApi(),
       itemsApi = itemsApi ?? MockItemsApi(),
       demoAccount =
           demoAccount ?? (authApi == null ? DemoAccount.defaults : null),
       diagnostics =
           diagnostics ??
           (kDebugMode ? const LocalDiagnostics() : const NoopDiagnostics());

  final AuthApi authApi;
  final ItemsApi itemsApi;
  final DemoAccount? demoAccount;
  final Diagnostics diagnostics;
}

class KankalApp extends StatefulWidget {
  const KankalApp({super.key, this.services});

  final AppServices? services;

  @override
  State<KankalApp> createState() => _KankalAppState();
}

class _KankalAppState extends State<KankalApp> {
  late final AppServices services = widget.services ?? AppServices();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kankal',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      initialRoute:
          services.authApi.currentSession == null
              ? AppRoutes.signIn
              : AppRoutes.items,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case AppRoutes.signIn:
            return MaterialPageRoute<void>(
              settings: settings,
              builder:
                  (_) => SignInView(
                    authApi: services.authApi,
                    demoAccount: services.demoAccount,
                    diagnostics: services.diagnostics,
                  ),
            );
          case AppRoutes.items:
            if (services.authApi.currentSession == null) {
              return MaterialPageRoute<void>(
                settings: const RouteSettings(name: AppRoutes.signIn),
                builder:
                    (_) => SignInView(
                      authApi: services.authApi,
                      demoAccount: services.demoAccount,
                      diagnostics: services.diagnostics,
                    ),
              );
            }
            return MaterialPageRoute<void>(
              settings: settings,
              builder:
                  (_) => ItemsView(
                    authApi: services.authApi,
                    itemsApi: services.itemsApi,
                    diagnostics: services.diagnostics,
                  ),
            );
          case AppRoutes.editItem:
            if (services.authApi.currentSession == null) {
              return MaterialPageRoute<void>(
                settings: const RouteSettings(name: AppRoutes.signIn),
                builder:
                    (_) => SignInView(
                      authApi: services.authApi,
                      demoAccount: services.demoAccount,
                      diagnostics: services.diagnostics,
                    ),
              );
            }
            return MaterialPageRoute<void>(
              settings: settings,
              builder:
                  (_) => ItemEditorView(
                    itemsApi: services.itemsApi,
                    itemId: settings.arguments as String?,
                    diagnostics: services.diagnostics,
                  ),
            );
          default:
            return MaterialPageRoute<void>(
              builder:
                  (_) => SignInView(
                    authApi: services.authApi,
                    demoAccount: services.demoAccount,
                    diagnostics: services.diagnostics,
                  ),
            );
        }
      },
    );
  }
}
