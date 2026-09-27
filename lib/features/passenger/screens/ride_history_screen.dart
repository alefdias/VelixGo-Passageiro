import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../controllers/passenger_controller.dart';

class RideHistoryScreen extends StatelessWidget {
  const RideHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final passenger = Provider.of<PassengerController>(context);

    // Mock para visualização inicial rica caso o histórico remoto esteja vazio
    final mockRides = [
      {
        'date': DateTime.now().subtract(const Duration(hours: 3)),
        'driver': 'Marcos Silva',
        'vehicle': 'Toyota Corolla • Prata',
        'origin': 'Av. Paulista, 1578',
        'dest': 'Shopping Ibirapuera, 3103',
        'fare': 26.50,
        'method': 'Pix',
      },
      {
        'date': DateTime.now().subtract(const Duration(days: 2)),
        'driver': 'Roberto Alves',
        'vehicle': 'Honda Civic • Preto',
        'origin': 'Rua das Flores, 120',
        'dest': 'Av. Faria Lima, 3477',
        'fare': 19.80,
        'method': 'Dinheiro',
      },
      {
        'date': DateTime.now().subtract(const Duration(days: 5)),
        'driver': 'Lucas Ferreira',
        'vehicle': 'Hyundai HB20 • Branco',
        'origin': 'Aeroporto de Congonhas',
        'dest': 'Av. Paulista, 1578',
        'fare': 34.20,
        'method': 'Cartão',
      },
    ];

    final displayRides = passenger.rideHistory.isNotEmpty
        ? passenger.rideHistory.map((r) => {
            'date': r.createdAt,
            'driver': r.driverName ?? 'Marcos Silva',
            'vehicle': r.driverVehicle ?? 'Toyota Corolla • Prata',
            'origin': r.originAddress,
            'dest': r.destinationAddress,
            'fare': r.actualFare ?? r.estimatedFare,
            'method': r.paymentMethod.toUpperCase(),
          }).toList()
        : mockRides;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Histórico de Viagens'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: displayRides.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = displayRides[index];

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        Formatters.formatDate(item['date'] as DateTime),
                        style: const TextStyle(
                          color: AppColors.grey,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          Formatters.formatCurrency(item['fare'] as double),
                          style: const TextStyle(
                            color: AppColors.green,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: AppColors.grey),
                      const SizedBox(width: 6),
                      Text(
                        '${item['driver']} • ${item['vehicle']}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(color: AppColors.borderLight, height: 1),
                  const SizedBox(height: 10),
                  // Origem
                  Row(
                    children: [
                      const Icon(Icons.circle, size: 8, color: AppColors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item['origin'] as String,
                          style: const TextStyle(fontSize: 13, color: AppColors.black),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Destino
                  Row(
                    children: [
                      const Icon(Icons.circle, size: 8, color: AppColors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item['dest'] as String,
                          style: const TextStyle(fontSize: 13, color: AppColors.black),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Pago diretamente ao motorista via ${item['method']}',
                    style: const TextStyle(fontSize: 11, color: AppColors.grey),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
