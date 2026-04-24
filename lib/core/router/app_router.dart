import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/profile_screen.dart';
import '../../features/cases/screens/case_detail_screen.dart';
import '../../features/cases/screens/cases_screen.dart';
import '../../features/evidence/screens/evidence_detail_screen.dart';
import '../../features/evidence/screens/evidence_upload_screen.dart';
import '../../features/highlights/screens/highlight_editor_screen.dart';
import '../../features/present/screens/local_present_screen.dart';
import '../../features/present/screens/remote_present_screen.dart';
import '../../features/present/screens/remote_viewer_screen.dart';
import '../../features/presentations/screens/presentation_builder_screen.dart';
import '../../features/presentations/screens/presentations_screen.dart';
import '../../features/teams/screens/team_detail_screen.dart';
import '../../features/teams/screens/teams_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const CasesScreen(),
        routes: [
          GoRoute(
            path: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: 'teams',
            builder: (context, state) => const TeamsScreen(),
            routes: [
              GoRoute(
                path: ':teamId',
                builder: (context, state) => TeamDetailScreen(
                  teamId: state.pathParameters['teamId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'cases/:caseId',
            builder: (context, state) => CaseDetailScreen(
              caseId: state.pathParameters['caseId']!,
            ),
            routes: [
              GoRoute(
                path: 'evidence/upload',
                builder: (context, state) => EvidenceUploadScreen(
                  caseId: state.pathParameters['caseId']!,
                ),
              ),
              GoRoute(
                path: 'evidence/:evidenceId',
                builder: (context, state) => EvidenceDetailScreen(
                  evidenceId: state.pathParameters['evidenceId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'highlight',
                    builder: (context, state) => HighlightEditorScreen(
                      evidenceId: state.pathParameters['evidenceId']!,
                      highlightId: state.uri.queryParameters['highlightId'],
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'presentations',
                builder: (context, state) => PresentationsScreen(
                  caseId: state.pathParameters['caseId']!,
                ),
                routes: [
                  GoRoute(
                    path: ':presentationId/build',
                    builder: (context, state) => PresentationBuilderScreen(
                      presentationId: state.pathParameters['presentationId']!,
                      caseId: state.pathParameters['caseId']!,
                    ),
                  ),
                  GoRoute(
                    path: ':presentationId/present/local',
                    builder: (context, state) => LocalPresentScreen(
                      presentationId: state.pathParameters['presentationId']!,
                    ),
                  ),
                  GoRoute(
                    path: ':presentationId/present/remote',
                    builder: (context, state) => RemotePresentScreen(
                      presentationId: state.pathParameters['presentationId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/watch/:sessionId',
        builder: (context, state) => RemoteViewerScreen(
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),
    ],
  );
});
