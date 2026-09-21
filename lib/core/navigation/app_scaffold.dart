import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../api_client.dart';

class AppScaffold extends StatelessWidget {
  final Widget child;
  const AppScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030305), // DeepBlack
      appBar: _XoroTopBar(),
      drawer: const _XoroDrawer(),
      body: child,
      bottomNavigationBar: _BottomNavBar(),
    );
  }
}

class _XoroTopBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final canPop = GoRouter.of(context).canPop();
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(canPop ? Icons.arrow_back : Icons.menu, color: Colors.white),
        onPressed: () {
          if (canPop) {
            context.pop();
          } else {
            Scaffold.of(context).openDrawer();
          }
        },
      ),
      title: RichText(
        text: const TextSpan(
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            shadows: [Shadow(color: Colors.black87, offset: Offset(3, 3), blurRadius: 8)],
          ),
          children: [
            TextSpan(text: 'XORO', style: TextStyle(color: Color(0xFF0055FF))),
            TextSpan(text: 'PO', style: TextStyle(color: Colors.white)),
            TextSpan(text: 'WER', style: TextStyle(color: Color(0xFFFF0033))),
          ],
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF0055FF).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text('🤠', style: TextStyle(fontSize: 18)),
          ),
          onPressed: () => context.go('/profile'),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _XoroDrawer extends ConsumerWidget {
  const _XoroDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiClientProvider);
    final esAdmin = api.isAdmin;
    final nombre = api.currentName;

    return Drawer(
      backgroundColor: const Color(0xFF0D0D0D), // XoroSurface
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [const Color(0xFF0055FF).withOpacity(0.15), const Color(0xFF0055FF).withOpacity(0.3)],
                ),
              ),
              alignment: Alignment.center,
              child: const Text('🤠', style: TextStyle(fontSize: 30)),
            ),
            const SizedBox(height: 12),
            Text(nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
            Text(
              esAdmin ? 'Administrador · Acceso total' : 'Nivel 1 · Aprendiz', 
              style: TextStyle(
                color: esAdmin ? const Color(0xFFFFD700) : const Color(0xFF0055FF), 
                fontSize: 12, 
                fontWeight: FontWeight.bold
              )
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Divider(color: Colors.white10),
            ),
            if (esAdmin) ...[
              _DrawerItem(icon: Icons.dashboard, label: 'Panel de Control', onTap: () { context.pop(); context.go('/admin_dashboard'); }),
              _DrawerItem(icon: Icons.add_outlined, label: 'Grabar Lección', onTap: () { context.pop(); context.go('/admin_add_exercise'); }),
              _DrawerItem(icon: Icons.people, label: 'Gestión de Usuarios', onTap: () { context.pop(); context.go('/admin_users'); }),
            ] else ...[
              _DrawerItem(icon: Icons.home_outlined, label: 'Inicio', onTap: () { context.pop(); context.go('/dashboard'); }),
              _DrawerItem(icon: Icons.explore_outlined, label: 'Categorías', onTap: () { context.pop(); context.go('/categories'); }),
              _DrawerItem(icon: Icons.bar_chart_outlined, label: 'Progreso', onTap: () { context.pop(); context.go('/progress'); }),
            ],
            _DrawerItem(icon: Icons.person_outline, label: 'Mi Perfil', onTap: () { context.pop(); context.go('/profile'); }),
            const Spacer(),
            const Divider(color: Colors.white10),
            const SizedBox(height: 12),
            _DrawerItem(icon: Icons.logout, label: 'Cerrar Sesión', onTap: () { 
              context.pop(); 
              api.logout(); 
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _DrawerItem({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF666666), size: 22),
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }
}

class _BottomNavBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final api = ref.watch(apiClientProvider);
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D).withOpacity(0.98),
        boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(0, -2), blurRadius: 8)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, color: Colors.white10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (api.isAdmin) ...[
                  _NavItem(icon: Icons.dashboard, label: 'Panel', isActive: location == '/admin_dashboard', onTap: () => context.go('/admin_dashboard')),
                  _NavItem(icon: Icons.people, label: 'Usuarios', isActive: location == '/admin_users', onTap: () => context.go('/admin_users')),
                  _NavItem(icon: Icons.person, label: 'Perfil', isActive: location == '/profile', onTap: () => context.go('/profile')),
                ] else ...[
                  _NavItem(icon: Icons.home, label: 'Inicio', isActive: location == '/dashboard', onTap: () => context.go('/dashboard')),
                  _NavItem(icon: Icons.library_books, label: 'Categorías', isActive: location == '/categories', onTap: () => context.go('/categories')),
                  _NavItem(icon: Icons.grid_view, label: 'Progreso', isActive: location == '/progress', onTap: () => context.go('/progress')),
                  _NavItem(icon: Icons.person, label: 'Perfil', isActive: location == '/profile', onTap: () => context.go('/profile')),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  
  const _NavItem({required this.icon, required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFF0055FF) : const Color(0xFF666666);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 80,
        height: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: isActive ? FontWeight.bold : FontWeight.w500)),
            if (isActive) ...[
              const SizedBox(height: 4),
              Container(width: 16, height: 2, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            ]
          ],
        ),
      ),
    );
  }
}
