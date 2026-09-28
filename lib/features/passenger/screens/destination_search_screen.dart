import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/place_search_service.dart';
import '../../../core/utils/formatters.dart';
import '../controllers/passenger_controller.dart';
import '../../auth/controllers/auth_controller.dart';
import 'active_ride_screen.dart';

class DestinationSearchScreen extends StatefulWidget {
  const DestinationSearchScreen({super.key});

  @override
  State<DestinationSearchScreen> createState() => _DestinationSearchScreenState();
}

class _DestinationSearchScreenState extends State<DestinationSearchScreen> {
  final _searchController = TextEditingController();
  Timer? _debounceTimer;
  List<PlaceSuggestion> _suggestions = [];
  bool _isSearching = false;

  final List<Map<String, dynamic>> _quickDestinations = [
    {
      'title': 'Shopping Ibirapuera',
      'address': 'Av. Ibirapuera, 3103 - Indianópolis, São Paulo',
      'lat': -23.6105,
      'lng': -46.6669,
      'icon': Icons.shopping_bag_outlined,
    },
    {
      'title': 'Aeroporto de Congonhas',
      'address': 'Av. Washington Luís, s/n - Vila Congonhas, São Paulo',
      'lat': -23.6273,
      'lng': -46.6565,
      'icon': Icons.flight_takeoff_rounded,
    },
    {
      'title': 'Parque Ibirapuera',
      'address': 'Av. Pedro Álvares Cabral - Vila Mariana, São Paulo',
      'lat': -23.5874,
      'lng': -46.6576,
      'icon': Icons.park_outlined,
    },
    {
      'title': 'Hospital Sírio-Libanês',
      'address': 'Rua Dona Adma Jafet, 115 - Bela Vista, São Paulo',
      'lat': -23.5574,
      'lng': -46.6534,
      'icon': Icons.local_hospital_outlined,
    },
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    if (query.length < 2) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _isSearching = false;
        });
      }
      return;
    }

    setState(() => _isSearching = true);

    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      final passenger = Provider.of<PassengerController>(context, listen: false);
      final results = await PlaceSearchService.searchPlaces(
        query,
        userLocation: passenger.currentLocation,
      );

      if (mounted) {
        setState(() {
          _suggestions = results;
          _isSearching = false;
        });
      }
    });
  }

  void _selectPlace(String address, double lat, double lng) {
    FocusScope.of(context).unfocus();
    setState(() {
      _suggestions = [];
      _searchController.text = address;
    });
    final controller = Provider.of<PassengerController>(context, listen: false);
    controller.setDestination(address, LatLng(lat, lng));
  }

  @override
  Widget build(BuildContext context) {
    final passenger = Provider.of<PassengerController>(context);
    final auth = Provider.of<AuthController>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Para onde você vai?'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Box de endereços (Origem & Destino)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Origem
                Row(
                  children: [
                    const Icon(Icons.my_location, color: AppColors.green, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        passenger.originAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 10, top: 4, bottom: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      height: 16,
                      child: VerticalDivider(color: AppColors.borderLight, thickness: 1.5),
                    ),
                  ),
                ),
                // Destino
                Row(
                  children: [
                    const Icon(Icons.location_on, color: AppColors.blue, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Digite nome da rua, número ou local',
                          isDense: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _suggestions = []);
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_isSearching)
            const LinearProgressIndicator(
              minHeight: 2.5,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.blue),
            ),

          // Se destino já foi selecionado, mostra resumo de valor, categoria e botão chamar
          if (passenger.destinationAddress != null) ...[
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: [
                  if (passenger.isCalculatingRoute)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: const [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.blue),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Calculando melhor trajeto pelas ruas...',
                            style: TextStyle(fontSize: 12, color: AppColors.grey),
                          ),
                        ],
                      ),
                    ),

                  // Seleção de Categoria: Moto / Mototáxi vs Carro
                  Row(
                    children: [
                      // Card Moto / Mototáxi
                      Expanded(
                        child: InkWell(
                          onTap: () => passenger.setVehicleType('motorcycle'),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: passenger.selectedVehicleType == 'motorcycle'
                                  ? AppColors.green.withOpacity(0.12)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: passenger.selectedVehicleType == 'motorcycle'
                                    ? AppColors.green
                                    : AppColors.borderLight,
                                width: passenger.selectedVehicleType == 'motorcycle' ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Icon(Icons.two_wheeler_rounded, color: AppColors.green, size: 28),
                                    if (passenger.selectedVehicleType == 'motorcycle')
                                      const Icon(Icons.check_circle, color: AppColors.green, size: 18),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Velix Moto',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                ),
                                Text(
                                  '~${Formatters.formatDuration(passenger.estimatedDurationMoto)} • Ágil',
                                  style: const TextStyle(color: AppColors.grey, fontSize: 11),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  Formatters.formatCurrency(passenger.estimatedFareMoto),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Card Carro
                      Expanded(
                        child: InkWell(
                          onTap: () => passenger.setVehicleType('car'),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: passenger.selectedVehicleType == 'car'
                                  ? AppColors.blue.withOpacity(0.12)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: passenger.selectedVehicleType == 'car'
                                    ? AppColors.blue
                                    : AppColors.borderLight,
                                width: passenger.selectedVehicleType == 'car' ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Icon(Icons.directions_car_rounded, color: AppColors.blue, size: 28),
                                    if (passenger.selectedVehicleType == 'car')
                                      const Icon(Icons.check_circle, color: AppColors.blue, size: 18),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Velix Carro',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                ),
                                Text(
                                  '~${Formatters.formatDuration(passenger.estimatedDurationCar)} • Conforto',
                                  style: const TextStyle(color: AppColors.grey, fontSize: 11),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  Formatters.formatCurrency(passenger.estimatedFareCar),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: AppColors.borderLight),
                  const SizedBox(height: 8),

                  // Escolha da forma de pagamento direto ao motorista
                  Row(
                    children: [
                      const Text(
                        'Pagar ao motorista via:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      _PaymentMethodChip(
                        title: 'Pix',
                        icon: Icons.qr_code_2,
                        isSelected: passenger.paymentMethod == 'pix',
                        onTap: () => passenger.setPaymentMethod('pix'),
                      ),
                      const SizedBox(width: 6),
                      _PaymentMethodChip(
                        title: 'Dinheiro',
                        icon: Icons.payments_outlined,
                        isSelected: passenger.paymentMethod == 'cash',
                        onTap: () => passenger.setPaymentMethod('cash'),
                      ),
                      const SizedBox(width: 6),
                      _PaymentMethodChip(
                        title: 'Cartão',
                        icon: Icons.credit_card,
                        isSelected: passenger.paymentMethod == 'card_machine',
                        onTap: () => passenger.setPaymentMethod('card_machine'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: () async {
                  final userId = auth.currentUser?.id ?? 'mock-passenger-1';
                  await passenger.requestRide(userId);
                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const ActiveRideScreen()),
                    );
                  }
                },
                icon: const Icon(Icons.near_me_rounded),
                label: const Text('Confirmar & Chamar Velix'),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // LISTA DE RESULTADOS / ATALHOS
          Expanded(
            child: _suggestions.isNotEmpty
                ? ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
                    itemBuilder: (context, index) {
                      final item = _suggestions[index];
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.blue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.location_on, color: AppColors.blue, size: 22),
                        ),
                        title: Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        subtitle: Text(
                          item.subtitle,
                          style: const TextStyle(color: AppColors.grey, fontSize: 13),
                        ),
                        onTap: () => _selectPlace(
                          item.title,
                          item.location.latitude,
                          item.location.longitude,
                        ),
                      );
                    },
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      const Text(
                        'Atalhos Salvos',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.surfaceLight,
                          child: Icon(Icons.home_rounded, color: AppColors.black),
                        ),
                        title: const Text('Casa', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(passenger.homeAddress, style: const TextStyle(color: AppColors.grey)),
                        onTap: () => passenger.selectHomeAsDestination(),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.surfaceLight,
                          child: Icon(Icons.work_rounded, color: AppColors.black),
                        ),
                        title: const Text('Trabalho', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(passenger.workAddress, style: const TextStyle(color: AppColors.grey)),
                        onTap: () => passenger.selectWorkAsDestination(),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Destinos Populares',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._quickDestinations.map((dest) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: AppColors.surfaceLight,
                            child: Icon(dest['icon'] as IconData, color: AppColors.blue),
                          ),
                          title: Text(dest['title'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(dest['address'] as String, style: const TextStyle(color: AppColors.grey)),
                          onTap: () => _selectPlace(
                            dest['address'] as String,
                            dest['lat'] as double,
                            dest['lng'] as double,
                          ),
                        );
                      }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodChip extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentMethodChip({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.black : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.black : AppColors.borderLight,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : AppColors.black,
            ),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
