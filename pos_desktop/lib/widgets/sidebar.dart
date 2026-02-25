import 'package:flutter/material.dart';
import '../screens/history_screen.dart';
import '../screens/main_pos_screen.dart';
import '../screens/promos_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/suppliers_screen.dart';
import '../screens/products_screen.dart';
import '../screens/barcodes_screen.dart';
import 'package:provider/provider.dart';
import '../providers/pos_provider.dart';

class Sidebar extends StatelessWidget {
  final String activePage;

  const Sidebar({Key? key, this.activePage = 'Home'}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PosProvider>(context);

    return Container(
      width: 100,
      color: const Color(0xFF1A1A28),
      child: Column(
        children: [
          const SizedBox(height: 32),
          // Logo
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B6B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.fastfood, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 8),
          const Text('POSFood', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 48),

          // Menu Items
          _buildMenuItem(
            context: context,
            icon: Icons.menu_book,
            label: 'Menu',
            isActive: activePage == 'Home',
            onTap: () {
              if (activePage != 'Home') {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const MainPosScreen()),
                );
              }
            },
          ),
          const SizedBox(height: 32),
          _buildMenuItem(
            context: context,
            icon: Icons.history,
            label: 'History',
            isActive: activePage == 'History',
            onTap: () {
              if (activePage != 'History') {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                );
              }
            },
          ),
          const SizedBox(height: 32),
          _buildMenuItem(
            context: context,
            icon: Icons.local_offer,
            label: 'Promos',
            isActive: activePage == 'Promos',
            onTap: () {
              if (activePage != 'Promos') {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const PromosScreen()),
                );
              }
            },
          ),
          const SizedBox(height: 32),
          _buildMenuItem(
            context: context,
            icon: Icons.local_offer,
            label: 'Supplier',
            isActive: activePage == 'Supplier',
            onTap: () {
              if (activePage != 'Supplier') {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const SuppliersScreen()),
                );
              }
            },
          ),
          if (provider.isAdmin) ...[
            const SizedBox(height: 32),
            _buildMenuItem(
              context: context,
              icon: Icons.inventory,
              label: 'Products',
              isActive: activePage == 'Products',
              onTap: () {
                if (activePage != 'Products') {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const ProductsScreen()),
                  );
                }
              },
            ),
            const SizedBox(height: 32),
            _buildMenuItem(
              context: context,
              icon: Icons.qr_code_2,
              label: 'Barcodes',
              isActive: activePage == 'Barcodes',
              onTap: () {
                if (activePage != 'Barcodes') {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const BarcodesScreen()),
                  );
                }
              },
            ),
          ],
          const SizedBox(height: 32),
          _buildMenuItem(
            context: context,
            icon: Icons.settings,
            label: 'Settings',
            isActive: activePage == 'Settings',
            onTap: () {
              if (activePage != 'Settings') {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: isActive
            ? BoxDecoration(
                color: const Color(0xFFFF6B6B).withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              )
            : null,
        child: Column(
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFFFF6B6B) : Colors.grey[600],
              size: 26,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFFFF6B6B) : Colors.grey[600],
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
