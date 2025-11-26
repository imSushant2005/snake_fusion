// lib/screens/shop_screen.dart
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/sound_manager.dart';
import '../services/settings_service.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({Key? key}) : super(key: key);

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  // Mock data for now
  int _coins = 0; 
  final List<Map<String, dynamic>> _skins = [
    {'id': 'neon_cyan', 'name': 'Neon Cyan', 'color': AppColors.snakeHead, 'price': 0, 'owned': true},
    {'id': 'plasma_pink', 'name': 'Plasma Pink', 'color': Colors.pinkAccent, 'price': 100, 'owned': false},
    {'id': 'cyber_lime', 'name': 'Cyber Lime', 'color': Colors.limeAccent, 'price': 250, 'owned': false},
    {'id': 'golden_glitch', 'name': 'Golden Glitch', 'color': Colors.amber, 'price': 500, 'owned': false},
  ];

  String _equippedSkinId = 'neon_cyan';

  @override
  void initState() {
    super.initState();
    _loadShopData();
  }

  void _loadShopData() {
    setState(() {
      _coins = SettingsService.coins;
      _equippedSkinId = SettingsService.equippedSkinId;
      
      for (var skin in _skins) {
        if (SettingsService.ownedSkins.contains(skin['id'])) {
          skin['owned'] = true;
        }
      }
    });
  }

  void _buySkin(int index) {
    final skin = _skins[index];
    if (_coins >= skin['price']) {
      setState(() {
        _coins -= skin['price'] as int;
        _skins[index]['owned'] = true;
      });
      SettingsService.setCoins(_coins);
      SettingsService.addOwnedSkin(skin['id']);
      SoundManager.playPowerUp(); // Success sound
    } else {
      // Not enough money
      SoundManager.playGameOver(); // Error sound
    }
  }

  void _equipSkin(int index) {
    setState(() {
      _equippedSkinId = _skins[index]['id'];
    });
    SettingsService.setEquippedSkin(_equippedSkinId);
    SoundManager.playClick();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('FUSION SHOP', style: TextStyle(fontFamily: 'Orbitron', fontWeight: FontWeight.bold)),
        actions: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.accent),
              ),
              child: Row(
                children: [
                  const Icon(Icons.monetization_on, color: AppColors.doubleScore, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '$_coins',
                    style: const TextStyle(
                      color: AppColors.doubleScore,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.8,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _skins.length,
        itemBuilder: (context, index) {
          final skin = _skins[index];
          final isOwned = skin['owned'] as bool;
          final isEquipped = _equippedSkinId == skin['id'];

          return Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isEquipped ? AppColors.success : (isOwned ? AppColors.accent.withOpacity(0.3) : Colors.transparent),
                width: isEquipped ? 3 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: skin['color'],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (skin['color'] as Color).withOpacity(0.6),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  skin['name'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 16),
                if (isOwned)
                  ElevatedButton(
                    onPressed: isEquipped ? null : () => _equipSkin(index),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isEquipped ? AppColors.success : AppColors.accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text(isEquipped ? 'EQUIPPED' : 'EQUIP'),
                  )
                else
                  ElevatedButton(
                    onPressed: () => _buySkin(index),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.background,
                      side: const BorderSide(color: AppColors.doubleScore),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.monetization_on, size: 16, color: AppColors.doubleScore),
                        const SizedBox(width: 4),
                        Text('${skin['price']}', style: const TextStyle(color: AppColors.doubleScore)),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
