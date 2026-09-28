import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../core/widgets/velix_map.dart';
import '../controllers/passenger_controller.dart';
import '../../auth/controllers/auth_controller.dart';
import 'rating_dialog.dart';

class ActiveRideScreen extends StatefulWidget {
  const ActiveRideScreen({super.key});

  @override
  State<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends State<ActiveRideScreen> {
  void _callDriver(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _messageDriver(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('sms:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showRatingModal() {
    final passenger = Provider.of<PassengerController>(context, listen: false);
    final auth = Provider.of<AuthController>(context, listen: false);
    final ride = passenger.activeRide;
    if (ride == null) return;

    final isFav = passenger.isDriverFavorite(ride.driverId);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => RatingDialog(
        driverName: ride.driverName ?? 'Motorista',
        vehicleInfo: ride.driverVehicle,
        isAlreadyFavorite: isFav,
        onSubmit: (score, comment, addToFavorites) async {
          await passenger.submitRatingAndFinish(
            passengerId: auth.currentUser?.id ?? '00000000-0000-0000-0000-000000000001',
            score: score,
            comment: comment,
            addToFavorites: addToFavorites,
          );
          if (mounted) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final passenger = Provider.of<PassengerController>(context);
    final ride = passenger.activeRide;

    // Se a corrida for finalizada, abre a avaliação
    if (ride != null && ride.isCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showRatingModal());
    }

    final markers = <VelixMapMarker>[];

    final origin = LatLng(
      ride?.originLat ?? passenger.currentLocation.latitude,
      ride?.originLng ?? passenger.currentLocation.longitude,
    );
    final destination = LatLng(
      ride?.destinationLat ?? (passenger.destinationLocation?.latitude ?? origin.latitude + 0.02),
      ride?.destinationLng ?? (passenger.destinationLocation?.longitude ?? origin.longitude + 0.02),
    );

    // Marcador de Origem (Onde o passageiro está)
    markers.add(
      VelixMapMarker(
        point: origin,
        child: const PassengerLocationMarker(),
      ),
    );

    // Marcador de Destino
    markers.add(
      VelixMapMarker(
        point: destination,
        child: const DestinationMarker(title: 'Destino'),
      ),
    );

    // Posição REAL do Motorista (Streaming do Supabase)
    LatLng? driverPos;
    if (ride != null && !ride.isRequested) {
      driverPos = passenger.assignedDriverLocation ?? LatLng(origin.latitude + 0.003, origin.longitude + 0.002);
      markers.add(
        VelixMapMarker(
          point: driverPos,
          child: DriverVehicleMarker(
            vehicleType: ride.vehicleType,
            label: ride.driverName ?? 'Motorista Parceiro',
          ),
        ),
      );
    }

    // Traça rota: Se motorista a caminho, traça motorista -> passageiro. Se em viagem, traça passageiro -> destino
    List<LatLng>? routePoints;
    if (driverPos != null && (ride?.status == 'accepted' || ride?.status == 'arrived')) {
      routePoints = GeoUtils.createRoutePolyline(driverPos, origin);
    } else {
      routePoints = GeoUtils.createRoutePolyline(origin, destination);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Velix Map
          VelixMap(
            center: driverPos ?? origin,
            initialZoom: 15.0,
            markers: markers,
            routePoints: routePoints,
            showRecenterButton: true,
            padding: const EdgeInsets.only(bottom: 300),
          ),

          // Botão Superior Voltar / Cancelar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.black),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.security_rounded, color: AppColors.green, size: 16),
                        const SizedBox(width: 6),
                        const Text(
                          'Viagem Monitorada',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),


          // Painel Inferior Deslizante com Informações da Corrida
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
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
                children: [
                  // Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ESTADO 1: Buscando Motorista com Prioridade de 15s para Favoritos
                  if (ride == null || ride.isRequested) ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: passenger.prioritySecondsRemaining > 0 
                                ? const Color(0xFFFFECEF) 
                                : AppColors.blue.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            passenger.prioritySecondsRemaining > 0 
                                ? Icons.favorite_rounded 
                                : Icons.radar_rounded,
                            color: passenger.prioritySecondsRemaining > 0 
                                ? const Color(0xFFF43F5E) 
                                : AppColors.blue,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                passenger.prioritySecondsRemaining > 0
                                    ? '❤️ Notificando Motoristas Favoritos'
                                    : 'Buscando motoristas próximos...',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                passenger.prioritySecondsRemaining > 0
                                    ? 'Seus motoristas favoritos têm prioridade de ${passenger.prioritySecondsRemaining}s'
                                    : 'Aguardando confirmação do motorista parceiro',
                                style: const TextStyle(fontSize: 13, color: AppColors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      color: passenger.prioritySecondsRemaining > 0 
                          ? const Color(0xFFF43F5E) 
                          : AppColors.blue,
                      backgroundColor: AppColors.surfaceLight,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () async {
                        await passenger.cancelRide();
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.red,
                        side: const BorderSide(color: AppColors.red),
                      ),
                      child: const Text('Cancelar Solicitação'),
                    ),
                  ]

                  // ESTADO 2: Motorista Aceitou / A caminho / Em andamento
                  else ...[
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(ride.status).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getStatusLabel(ride.status),
                        style: TextStyle(
                          color: _getStatusColor(ride.status),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Card do Motorista
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.surfaceLight,
                          backgroundImage: const NetworkImage(
                            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    ride.driverName ?? 'Marcos Silva',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.star_rounded, color: AppColors.yellow, size: 18),
                                  Text(
                                    ' ${ride.driverRating?.toStringAsFixed(1) ?? '4.9'}',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  if (passenger.isDriverFavorite(ride.driverId)) ...[
                                    const SizedBox(width: 6),
                                    const Icon(Icons.favorite_rounded, color: Color(0xFFF43F5E), size: 16),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                ride.driverVehicle ?? 'Toyota Corolla Prata',
                                style: const TextStyle(fontSize: 14, color: AppColors.grey),
                              ),
                              Text(
                                ride.driverPlate ?? 'BRA2E19',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: AppColors.borderLight),
                    const SizedBox(height: 10),

                    // Resumo de Pagamento Direto e Ações de Contato
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pagar via ${ride.paymentMethod.toUpperCase()} (direto)',
                              style: const TextStyle(color: AppColors.grey, fontSize: 12),
                            ),
                            Text(
                              Formatters.formatCurrency(ride.estimatedFare),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.black,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton.filled(
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.green,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.call),
                              onPressed: () => _callDriver(ride.driverPhone ?? '(11) 99887-1122'),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.blue,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.chat_bubble_outline),
                              onPressed: () => _messageDriver(ride.driverPhone ?? '(11) 99887-1122'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return AppColors.blue;
      case 'arrived':
        return AppColors.yellow;
      case 'in_progress':
        return AppColors.green;
      case 'completed':
        return AppColors.green;
      default:
        return AppColors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'accepted':
        return '🚗 Motorista a caminho do seu local';
      case 'arrived':
        return '📍 Motorista chegou! Encontre o veículo';
      case 'in_progress':
        return '🟢 Viagem em andamento até o destino';
      case 'completed':
        return '🏁 Viagem Finalizada';
      default:
        return 'Aguardando';
    }
  }
}
