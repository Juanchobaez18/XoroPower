import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/gamification/home_screen.dart';
import 'core/navigation/app_scaffold.dart';
import 'features/exercises/admin_add_exercise_screen.dart';
import 'features/exercises/pantalla_ritmo.dart';
import 'features/exercises/module_detail_screen.dart';
import 'features/exercises/instruction_screen.dart';
import 'core/theme/app_theme.dart';
import 'features/profile/profile_screen.dart';
import 'features/progress/progreso_screen.dart';
import 'features/exercises/category_screen.dart';
import 'features/admin/admin_dashboard_screen.dart';
import 'features/admin/users_list_screen.dart';
import 'core/api_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Supabase.initialize(
      url: 'https://yvmxgddtnokpaibcsnkv.supabase.co',
      anonKey: 'sb_publishable_OW6s1SF_Hbj1P2Fk0BXQVA_GfR5WkSC',
    );
    runApp(
      const ProviderScope(
        child: XoroPowerApp(),
      ),
    );
  } catch (e, stackTrace) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Error fatal al iniciar:\n$e\n\n$stackTrace',
                style: const TextStyle(color: Colors.red, fontSize: 14),
                textAlign: TextAlign.left,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final apiClient = ref.watch(apiClientProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: apiClient,
    redirect: (context, state) {
      final isLoggedIn = apiClient.isAuthenticated;
      final location = state.matchedLocation;
      
      final isGoingToAuth = location == '/login' || location == '/register' || location == '/';

      // If not logged in and not heading to auth screens, redirect to login
      if (!isLoggedIn && !isGoingToAuth) {
        return '/login';
      }

      // If logged in and heading to auth screens, redirect to dashboard based on role
      if (isLoggedIn && isGoingToAuth) {
        return apiClient.isAdmin ? '/admin_dashboard' : '/dashboard';
      }

      // RBAC: Student trying to access admin routes
      final isAdminRoute = location.startsWith('/admin_');
      if (isLoggedIn && !apiClient.isAdmin && isAdminRoute) {
        return '/dashboard';
      }
      
      // RBAC: Admin trying to access student dashboard
      if (isLoggedIn && apiClient.isAdmin && location == '/dashboard') {
        return '/admin_dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/admin_add_exercise',
        builder: (context, state) => const AdminAddExerciseScreen(),
      ),
      GoRoute(
        path: '/pantalla_ritmo',
        builder: (context, state) => const PantallaRitmo(titulo: 'Prueba de Cámara'),
      ),
      GoRoute(
        path: '/module/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ModuleDetailScreen(moduleId: id);
        },
      ),
      GoRoute(
        path: '/instructions/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return InstructionScreen(exerciseId: id);
        },
      ),
      GoRoute(
        path: '/admin_dashboard',
        builder: (context, state) => const AppScaffold(child: AdminDashboardScreen()),
      ),
      GoRoute(
        path: '/admin_users',
        builder: (context, state) => const AppScaffold(child: UsersListScreen()),
      ),
      ShellRoute(
        builder: (context, state, child) => AppScaffold(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/categories',
            builder: (context, state) => const CategoryScreen(),
          ),
          GoRoute(
            path: '/progress',
            builder: (context, state) => const ProgresoScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
});

class XoroPowerApp extends ConsumerWidget {
  const XoroPowerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'XoroPower',
      theme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
