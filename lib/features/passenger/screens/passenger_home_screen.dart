import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/velix_map.dart';
import '../controllers/passenger_controller.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../profile/screens/profile_screen.dart';
import 'destination_search_screen.dart';
import 'favorite_drivers_screen.dart';
import 'ride_history_screen.dart';
import 'active_ride_screen.dart';

class PassengerHomeScreen extends StatefulWidget {
  const PassengerHomeScreen({super.key});

  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends State<PassengerHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthController>(context, listen: false);
      final passenger = Provider.of<PassengerController>(context, listen: false);
      passenger.initialize(auth.currentUser?.id ?? '00000000-0000-0000-0000-000000000001');
    });
  }

  @override
  Widget build(BuildContext context) {
    final passenger = Provider.of<PassengerController>(context);
    final auth = Provider.of<AuthController>(context);

    // Marcadores Reais (Passageiro GPS + Motoristas Online no Supabase)
    final markers = <VelixMapMarker>[];

    // 1. Posição GPS Real do Passageiro
    markers.add(
      VelixMapMarker(
        point: passenger.currentLocation,
        child: const PassengerLocationMarker(),
      ),
    );

    // 2. Veículos Reais Online no Supabase (Carros e Motos)
    for (final driverData in passenger.onlineDrivers) {
      final lat = (driverData['latitude'] as num?)?.toDouble();
      final lng = (driverData['longitude'] as num?)?.toDouble();
      final heading = (driverData['heading'] as num?)?.toDouble() ?? 0.0;
      if (lat != null && lng != null) {
        markers.add(
          VelixMapMarker(
            point: LatLng(lat, lng),
            child: DriverVehicleMarker(
              vehicleType: driverData['vehicle_type'] ?? 'car',
              heading: heading,
            ),
          ),
        );
      }
    }

    return Scaffold(
      drawer: _buildDrawer(context, auth, passenger),
      body: Stack(
        children: [
          // Velix Map (OpenStreetMap em tempo real com modo 3D e noturno)
          VelixMap(
            center: passenger.currentLocation,
            initialZoom: 15.5,
            markers: markers,
            showRecenterButton: true,
            show3DToggle: true,
            showDarkModeToggle: true,
            padding: const EdgeInsets.only(bottom: 240),
          ),

          // Barra Superior com Menu e Perfil
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Builder(
                    builder: (ctx) => Material(
                      elevation: 4,
                      shape: const CircleBorder(),
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        child: IconButton(
                          icon: const Icon(Icons.menu, color: AppColors.black),
                          onPressed: () => Scaffold.of(ctx).openDrawer(),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Indicador do Perfil
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions_car, color: AppColors.blue, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Passageiro',
                          style: TextStyle(
                            color: AppColors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Badge de Frota em Tempo Real (Apenas Motoristas Reais Online)
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            left: 16,
            right: 16,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(20),
              color: Colors.white.withOpacity(0.96),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: passenger.onlineDrivers.isNotEmpty ? AppColors.green : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        passenger.onlineDrivers.isNotEmpty
                            ? '🟢 ${passenger.onlineCarsCount} carro(s) e ${passenger.onlineMotosCount} moto(s) online${passenger.closestEtaMinutes != null ? ' • Mais próximo ~${passenger.closestEtaMinutes} min' : ''}'
                            : 'Nenhum motorista online no momento',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AppColors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),


          // Se houver corrida ativa, exibe banner flutuante
          if (passenger.activeRide != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 230,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ActiveRideScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.blue,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: AppColors.blue.withOpacity(0.4), blurRadius: 12),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.navigation, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Viagem em andamento: ${passenger.activeRide?.destinationAddress ?? ''}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                    ],
                  ),
                ),
              ),
            ),

          // Painel Inferior de Busca "Para onde vamos?"
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.borderLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Para onde vamos hoje?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Barra de Busca
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DestinationSearchScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.search, color: AppColors.blue, size: 24),
                          SizedBox(width: 12),
                          Text(
                            'Buscar endereço de destino...',
                            style: TextStyle(
                              color: AppColors.grey,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Atalhos Rápidos: Casa, Trabalho, Favoritos
                  Row(
                    children: [
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.home_rounded,
                          iconColor: AppColors.blue,
                          title: 'Casa',
                          onTap: () {
                            passenger.selectHomeAsDestination();
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const DestinationSearchScreen()),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.work_rounded,
                          iconColor: AppColors.green,
                          title: 'Trabalho',
                          onTap: () {
                            passenger.selectWorkAsDestination();
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const DestinationSearchScreen()),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.favorite_rounded,
                          iconColor: const Color(0xFFF43F5E),
                          title: 'Favoritos',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const FavoriteDriversScreen()),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, AuthController auth, PassengerController passenger) {
    final avatar = auth.currentUser?.avatarUrl;
    final name = auth.currentUser?.fullName.isNotEmpty == true ? auth.currentUser!.fullName : 'Passageiro Velix';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: AppColors.black),
            currentAccountPicture: CircleAvatar(
              backgroundColor: AppColors.blue,
              backgroundImage: (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null,
              child: (avatar == null || avatar.isEmpty)
                  ? Text(
                      initial,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    )
                  : null,
            ),
            accountName: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            accountEmail: Text(
              auth.currentUser?.email ?? '',
              style: const TextStyle(color: AppColors.greyLight, fontSize: 13),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.favorite_rounded, color: Color(0xFFF43F5E)),
            title: const Text('Motoristas Favoritos', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Prioridade de 15s nas chamadas', style: TextStyle(fontSize: 12)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoriteDriversScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.history_rounded, color: AppColors.blue),
            title: const Text('Histórico de Viagens', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const RideHistoryScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_outline, color: AppColors.black),
            title: const Text('Meu Perfil', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
          ),

          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.red),
            title: const Text('Sair da Conta', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w600)),
            onTap: () async {
              await auth.logout();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.black),
            ),
          ],
        ),
      ),
    );
  }
}
