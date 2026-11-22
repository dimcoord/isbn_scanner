import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'history_screen.dart';
import 'scanner_screen.dart';
import '../services/history_service.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final HistoryService _historyService = HistoryService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ScannerScreen(isActive: _currentIndex == 0),
          const HistoryScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
          border: const Border(
            top: BorderSide(
              color: AppColors.border,
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Scan Tab (Left Action)
                Expanded(
                  child: _buildNavItem(
                    index: 0,
                    icon: Icons.qr_code_scanner_outlined,
                    activeIcon: Icons.qr_code_scanner,
                    label: 'Pindai ISBN',
                    showBadge: false,
                  ),
                ),

                Container(
                  height: 32,
                  width: 1,
                  color: AppColors.border,
                ),

                // 2. History Tab (Right Action)
                Expanded(
                  child: _buildNavItem(
                    index: 1,
                    icon: Icons.auto_stories_outlined,
                    activeIcon: Icons.auto_stories,
                    label: 'Riwayat Buku',
                    showBadge: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool showBadge,
  }) {
    final isSelected = _currentIndex == index;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _currentIndex = index);
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  size: 24,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
                if (showBadge)
                  AnimatedBuilder(
                    animation: _historyService,
                    builder: (context, _) {
                      final unsynced = _historyService.books
                          .where((b) => b.syncStatus != 'sent')
                          .length;
                      if (unsynced == 0) return const SizedBox.shrink();
                      return Positioned(
                        right: -8,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.statusPending,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Text(
                            '$unsynced',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
