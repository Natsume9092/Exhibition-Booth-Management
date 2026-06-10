import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/guest/home_screen.dart';
import '../screens/guest/exhibition_detail_screen.dart';
import '../screens/exhibitor/exhibitor_shell.dart';
import '../screens/exhibitor/exhibitor_exhibitions_screen.dart';
import '../screens/exhibitor/floor_plan_screen.dart';
import '../screens/exhibitor/application_form_screen.dart';
import '../screens/exhibitor/my_applications_screen.dart';
import '../screens/exhibitor/application_detail_screen.dart';
import '../screens/organizer/organizer_shell.dart';
import '../screens/organizer/organizer_exhibitions_screen.dart';
import '../screens/organizer/exhibition_form_screen.dart';
import '../screens/organizer/organizer_booths_screen.dart';
import '../screens/organizer/organizer_applications_screen.dart';
import '../screens/admin/admin_shell.dart';
import '../screens/admin/admin_exhibitions_screen.dart';
import '../screens/admin/admin_floor_plan_screen.dart';
import '../screens/admin/admin_users_screen.dart';
import '../screens/admin/admin_applications_screen.dart';
import '../screens/admin/admin_addons_screen.dart';

/// Wraps a screen in a fast, smooth FADE transition.
///
/// A fade is the most common and least distracting page animation. 220ms
/// (and a slightly shorter 180ms going back) keeps every page change quick
/// and smooth, which is what makes the app feel responsive.
CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // CurvedAnimation makes the fade ease in/out instead of being linear.
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
        child: child,
      );
    },
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isAuth = auth != null;
      final path = state.uri.path;
      if (path.startsWith('/exhibitor') && (!isAuth || auth.role != UserRole.exhibitor)) {
        return isAuth ? '/' : '/login';
      }
      if (path.startsWith('/organizer') && (!isAuth || auth.role != UserRole.organizer)) {
        return isAuth ? '/' : '/login';
      }
      if (path.startsWith('/admin') && (!isAuth || auth.role != UserRole.admin)) {
        return isAuth ? '/' : '/login';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', pageBuilder: (ctx, s) => _fadePage(s, const HomeScreen())),
      GoRoute(path: '/exhibition/:id',
        pageBuilder: (ctx, s) => _fadePage(s, ExhibitionDetailScreen(exhibitionId: s.pathParameters['id']!))),
      GoRoute(path: '/login', pageBuilder: (ctx, s) => _fadePage(s, const LoginScreen())),
      GoRoute(path: '/register', pageBuilder: (ctx, s) => _fadePage(s, const RegisterScreen())),

      // Exhibitor
      ShellRoute(
        builder: (ctx, s, child) => ExhibitorShell(child: child),
        routes: [
          GoRoute(path: '/exhibitor',
            pageBuilder: (ctx, s) => _fadePage(s, const ExhibitorExhibitionsScreen())),
          GoRoute(path: '/exhibitor/floor-plan/:exhibitionId',
            pageBuilder: (ctx, s) => _fadePage(s, FloorPlanScreen(exhibitionId: s.pathParameters['exhibitionId']!))),
          GoRoute(path: '/exhibitor/apply/:exhibitionId',
            pageBuilder: (ctx, s) => _fadePage(s, ApplicationFormScreen(exhibitionId: s.pathParameters['exhibitionId']!))),
          GoRoute(path: '/exhibitor/applications',
            pageBuilder: (ctx, s) => _fadePage(s, const MyApplicationsScreen())),
          GoRoute(path: '/exhibitor/application/:id',
            pageBuilder: (ctx, s) => _fadePage(s, ApplicationDetailScreen(applicationId: s.pathParameters['id']!))),
        ],
      ),

      // Organizer
      ShellRoute(
        builder: (ctx, s, child) => OrganizerShell(child: child),
        routes: [
          GoRoute(path: '/organizer',
            pageBuilder: (ctx, s) => _fadePage(s, const OrganizerExhibitionsScreen())),
          GoRoute(path: '/organizer/exhibition/new',
            pageBuilder: (ctx, s) => _fadePage(s, const ExhibitionFormScreen())),
          GoRoute(path: '/organizer/exhibition/edit/:id',
            pageBuilder: (ctx, s) => _fadePage(s, ExhibitionFormScreen(exhibitionId: s.pathParameters['id']))),
          GoRoute(path: '/organizer/booths/:exhibitionId',
            pageBuilder: (ctx, s) => _fadePage(s, OrganizerBoothsScreen(exhibitionId: s.pathParameters['exhibitionId']!))),
          // All applications across the organizer's exhibitions (bottom-nav tab).
          GoRoute(path: '/organizer/applications',
            pageBuilder: (ctx, s) => _fadePage(s, const OrganizerApplicationsScreen())),
          // Applications for one specific exhibition.
          GoRoute(path: '/organizer/applications/:exhibitionId',
            pageBuilder: (ctx, s) => _fadePage(s, OrganizerApplicationsScreen(exhibitionId: s.pathParameters['exhibitionId']!))),
        ],
      ),

      // Admin
      ShellRoute(
        builder: (ctx, s, child) => AdminShell(child: child),
        routes: [
          GoRoute(path: '/admin',
            pageBuilder: (ctx, s) => _fadePage(s, const AdminExhibitionsScreen())),
          GoRoute(path: '/admin/floor-plan/:exhibitionId',
            pageBuilder: (ctx, s) => _fadePage(s, AdminFloorPlanScreen(exhibitionId: s.pathParameters['exhibitionId']!))),
          GoRoute(path: '/admin/users',
            pageBuilder: (ctx, s) => _fadePage(s, const AdminUsersScreen())),
          GoRoute(path: '/admin/applications',
            pageBuilder: (ctx, s) => _fadePage(s, const AdminApplicationsScreen())),
          // Admin add-on item management (create / edit / delete).
          GoRoute(path: '/admin/addons',
            pageBuilder: (ctx, s) => _fadePage(s, const AdminAddonsScreen())),
          GoRoute(path: '/admin/exhibition/new',
            pageBuilder: (ctx, s) => _fadePage(s, const ExhibitionFormScreen(isAdmin: true))),
          GoRoute(path: '/admin/exhibition/edit/:id',
            pageBuilder: (ctx, s) => _fadePage(s, ExhibitionFormScreen(exhibitionId: s.pathParameters['id'], isAdmin: true))),
        ],
      ),
    ],
  );
});
