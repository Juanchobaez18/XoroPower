import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/core/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Prueba de Autenticación y Auto-Login (Admin)', () async {
    // 1. Setup Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});
    
    // 2. Init ApiClient
    final api = ApiClient();
    await api.init();
    
    // Al inicio no debe haber sesión
    expect(api.isAuthenticated, false);
    
    // 3. Login como Admin
    await api.login('admin@admin.com', '123456');
    
    // Validar estado de sesión
    expect(api.isAuthenticated, true);
    expect(api.isAdmin, true);
    expect(api.currentName, 'Administrador');
    
    // 4. Simular reinicio de App (Auto-Login)
    final apiReiniciado = ApiClient();
    await apiReiniciado.init();
    
    // Validar que la sesión persiste
    expect(apiReiniciado.isAuthenticated, true);
    expect(apiReiniciado.isAdmin, true);
    
    // 5. Logout
    await apiReiniciado.logout();
    expect(apiReiniciado.isAuthenticated, false);
  });
}
