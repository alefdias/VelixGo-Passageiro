import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../controllers/passenger_controller.dart';
import '../../auth/controllers/auth_controller.dart';

class FavoriteDriversScreen extends StatelessWidget {
  const FavoriteDriversScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final passenger = Provider.of<PassengerController>(context);
    final auth = Provider.of<AuthController>(context);

    // Mock de lista de motoristas para exibição
    final mockFavoriteList = [
      {
        'id': 'mock-driver-1',
        'name': 'Marcos Silva',
        'rating': 4.94,
        'rides': 48,
        'vehicle': 'Toyota Corolla 2.0 • Prata (BRA2E19)',
        'is_online': true,
        'avatar': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
      },
      {
        'id': 'mock-driver-2',
        'name': 'Roberto Alves',
        'rating': 4.98,
        'rides': 112,
        'vehicle': 'Honda Civic EXL • Preto (VEL4G20)',
        'is_online': false,
        'avatar': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Motoristas Favoritos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Banner Explicativo do Diferencial
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF43F5E).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite_rounded, color: Color(0xFFF43F5E), size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Prioridade Velix Go (15s)',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Quando você solicita uma viagem, o Velix avisa primeiro seus motoristas favoritos que estiverem online por 15 segundos antes de chamar outros.',
                        style: TextStyle(color: AppColors.greyLight, fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Lista de Motoristas
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: mockFavoriteList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = mockFavoriteList[index];
                final driverId = item['id'] as String;
                final isFav = passenger.isDriverFavorite(driverId) || index == 0;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: AppColors.surfaceLight,
                              backgroundImage: NetworkImage(item['avatar'] as String),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: (item['is_online'] as bool) ? AppColors.green : AppColors.grey,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    item['name'] as String,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.star_rounded, color: AppColors.yellow, size: 16),
                                  Text(
                                    ' ${(item['rating'] as double).toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item['vehicle'] as String,
                                style: const TextStyle(fontSize: 13, color: AppColors.grey),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (item['is_online'] as bool) ? '🟢 Online agora' : '⚪ Offline no momento',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: (item['is_online'] as bool) ? AppColors.green : AppColors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: isFav ? const Color(0xFFF43F5E) : AppColors.grey,
                          ),
                          onPressed: () {
                            passenger.toggleFavorite(
                              auth.currentUser?.id ?? 'mock-passenger-1',
                              driverId,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
