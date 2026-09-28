import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/ride_model.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/routing_service.dart';
import '../../../core/utils/geo_utils.dart';

class PassengerController extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();

  LatLng _currentLocation = const LatLng(AppConstants.defaultLat, AppConstants.defaultLng);
  String _originAddress = 'Minha Localização Atual';
  
  String? _destinationAddress;
  LatLng? _destinationLocation;
  
  String _selectedVehicleType = 'motorcycle'; // 'motorcycle' (Mototáxi) ou 'car' (Carro)
  double _distanceKm = 0.0;
  int _estimatedDurationMin = 0;
  double _estimatedFare = 0.0;
  double _estimatedFareMoto = 0.0;
  double _estimatedFareCar = 0.0;
  int _estimatedDurationMoto = 0;
  int _estimatedDurationCar = 0;
  String _paymentMethod = 'pix'; // 'pix', 'cash', 'card_machine'

  String _homeAddress = 'Rua das Flores, 120 - Jardins';
  LatLng _homeLocation = const LatLng(-23.5680, -46.6620);
  
  String _workAddress = 'Av. Faria Lima, 3477 - Itaim Bibi';
  LatLng _workLocation = const LatLng(-23.5870, -46.6830);

  RideModel? _activeRide;
  StreamSubscription<RideModel>? _rideSubscription;
  StreamSubscription<LatLng?>? _driverLocationSub;
  StreamSubscription<Position>? _gpsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _onlineDriversSub;

  LatLng? _assignedDriverLocation;
  List<Map<String, dynamic>> _onlineDrivers = [];
  List<String> _favoriteDriverIds = [];
  List<RideModel> _rideHistory = [];
  
  bool _isLoading = false;
  bool _isRequestingRide = false;
  int _prioritySecondsRemaining = 15;
  Timer? _priorityTimer;

  List<LatLng> _routePoints = [];
  List<RouteInstruction> _routeInstructions = [];
  bool _isCalculatingRoute = false;

  List<Map<String, dynamic>> _ambientVehicles = [];
  Timer? _ambientMovementTimer;

  // Getters
  List<LatLng> get routePoints => _routePoints;
  List<RouteInstruction> get routeInstructions => _routeInstructions;
  bool get isCalculatingRoute => _isCalculatingRoute;
  LatLng get currentLocation => _currentLocation;
  String get originAddress => _originAddress;
  String? get destinationAddress => _destinationAddress;
  LatLng? get destinationLocation => _destinationLocation;
  String get selectedVehicleType => _selectedVehicleType;
  double get distanceKm => _distanceKm;
  int get estimatedDurationMin => _estimatedDurationMin;
  double get estimatedFare => _estimatedFare;
  double get estimatedFareMoto => _estimatedFareMoto;
  double get estimatedFareCar => _estimatedFareCar;
  int get estimatedDurationMoto => _estimatedDurationMoto;
  int get estimatedDurationCar => _estimatedDurationCar;
  String get paymentMethod => _paymentMethod;
  String get homeAddress => _homeAddress;
  String get workAddress => _workAddress;
  RideModel? get activeRide => _activeRide;
  LatLng? get assignedDriverLocation => _assignedDriverLocation;
  List<Map<String, dynamic>> get onlineDrivers => _onlineDrivers;

  // Frota ativa total (Motoristas reais do Supabase + Veículos urbanos ativos ao redor)
  List<Map<String, dynamic>> get allNearbyVehicles {
    if (_onlineDrivers.isNotEmpty) {
      final realDriverIds = _onlineDrivers.map((d) => d['driver_id']).toSet();
      final filteredAmbient = _ambientVehicles.where((a) => !realDriverIds.contains(a['driver_id'])).toList();
      return [..._onlineDrivers, ...filteredAmbient];
    }
    return _ambientVehicles;
  }

  int get onlineCarsCount => allNearbyVehicles.where((v) => (v['vehicle_type'] ?? 'car') == 'car').length;
  int get onlineMotosCount => allNearbyVehicles.where((v) => (v['vehicle_type'] ?? 'car') == 'motorcycle').length;

  int get closestEtaMinutes {
    final list = allNearbyVehicles;
    if (list.isEmpty) return 3;
    double minDistance = double.infinity;
    for (final v in list) {
      final lat = (v['latitude'] as num?)?.toDouble();
      final lng = (v['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        final d = GeoUtils.calculateDistance(_currentLocation, LatLng(lat, lng));
        if (d < minDistance) minDistance = d;
      }
    }
    if (minDistance == double.infinity) return 3;
    final eta = (minDistance * 2.5).round();
    return eta < 1 ? 1 : (eta > 15 ? 15 : eta);
  }

  Map<String, dynamic>? getClosestDriver(String vehicleType) {
    final list = allNearbyVehicles.where((v) => (v['vehicle_type'] ?? 'car') == vehicleType).toList();
    if (list.isEmpty) return null;
    Map<String, dynamic>? closest;
    double minDistance = double.infinity;
    for (final v in list) {
      final lat = (v['latitude'] as num?)?.toDouble();
      final lng = (v['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        final d = GeoUtils.calculateDistance(_currentLocation, LatLng(lat, lng));
        if (d < minDistance) {
          minDistance = d;
          closest = v;
        }
      }
    }
    return closest;
  }

  List<String> get favoriteDriverIds => _favoriteDriverIds;
  List<RideModel> get rideHistory => _rideHistory;
  bool get isLoading => _isLoading;
  bool get isRequestingRide => _isRequestingRide;
  int get prioritySecondsRemaining => _prioritySecondsRemaining;

  bool isDriverFavorite(String? driverId) {
    if (driverId == null) return false;
    return _favoriteDriverIds.contains(driverId);
  }

  Future<void> initialize(String passengerId) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Obtém GPS real do dispositivo
      _currentLocation = await LocationService.getCurrentLocation();
      _originAddress = 'Sua Localização GPS';

      // 2. Inicia rastreamento contínuo do GPS real
      _gpsSubscription?.cancel();
      _gpsSubscription = LocationService.getPositionStream().listen((pos) {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
        notifyListeners();
      });

      // 3. Escuta em Realtime todos os motoristas reais online no Supabase
      _onlineDriversSub?.cancel();
      _onlineDriversSub = _supabaseService.streamOnlineDriverLocations().listen((driversList) {
        _onlineDrivers = driversList;
        notifyListeners();
      });

      _favoriteDriverIds = await _supabaseService.getFavoriteDriverIds(passengerId);
      _rideHistory = await _supabaseService.getRideHistory(passengerId, isDriver: false);

      // 4. Inicializa e movimenta frota urbana ativa ao redor do passageiro
      _initAmbientVehicles(_currentLocation);
      _startAmbientMovement();
    } catch (_) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setOriginAddress(String address) {
    _originAddress = address;
    notifyListeners();
  }

  Future<void> setDestination(String address, LatLng location) async {
    _destinationAddress = address;
    _destinationLocation = location;
    _isCalculatingRoute = true;

    // Estimativa inicial rápida em linha reta enquanto a API de ruas responde
    _distanceKm = GeoUtils.calculateDistance(_currentLocation, location);
    _estimatedDurationMoto = GeoUtils.estimateDurationMinutes(_distanceKm, vehicleType: 'motorcycle');
    _estimatedDurationCar = GeoUtils.estimateDurationMinutes(_distanceKm, vehicleType: 'car');
    _estimatedFareMoto = GeoUtils.calculateEstimatedFare(_distanceKm, _estimatedDurationMoto, vehicleType: 'motorcycle');
    _estimatedFareCar = GeoUtils.calculateEstimatedFare(_distanceKm, _estimatedDurationCar, vehicleType: 'car');
    _estimatedDurationMin = _selectedVehicleType == 'motorcycle' ? _estimatedDurationMoto : _estimatedDurationCar;
    _estimatedFare = _selectedVehicleType == 'motorcycle' ? _estimatedFareMoto : _estimatedFareCar;
    notifyListeners();

    // Rota real pelas ruas e avenidas via OSRM
    try {
      final result = await RoutingService.getDrivingRoute(_currentLocation, location);
      _routePoints = result.points;
      _routeInstructions = result.instructions;
      _distanceKm = result.distanceKm;

      _estimatedDurationCar = result.durationMinutes;
      _estimatedDurationMoto = (result.durationMinutes * 0.75).ceil();
      if (_estimatedDurationMoto < 1) _estimatedDurationMoto = 1;

      _estimatedFareMoto = GeoUtils.calculateEstimatedFare(_distanceKm, _estimatedDurationMoto, vehicleType: 'motorcycle');
      _estimatedFareCar = GeoUtils.calculateEstimatedFare(_distanceKm, _estimatedDurationCar, vehicleType: 'car');
      _estimatedDurationMin = _selectedVehicleType == 'motorcycle' ? _estimatedDurationMoto : _estimatedDurationCar;
      _estimatedFare = _selectedVehicleType == 'motorcycle' ? _estimatedFareMoto : _estimatedFareCar;
    } catch (_) {
      _routePoints = GeoUtils.createRoutePolyline(_currentLocation, location);
    } finally {
      _isCalculatingRoute = false;
      notifyListeners();
    }
  }

  void setVehicleType(String type) {
    _selectedVehicleType = type;
    _estimatedDurationMin = type == 'motorcycle' ? _estimatedDurationMoto : _estimatedDurationCar;
    _estimatedFare = type == 'motorcycle' ? _estimatedFareMoto : _estimatedFareCar;
    notifyListeners();
  }

  void setPaymentMethod(String method) {
    _paymentMethod = method;
    notifyListeners();
  }

  void selectHomeAsDestination() {
    setDestination(_homeAddress, _homeLocation);
  }

  void selectWorkAsDestination() {
    setDestination(_workAddress, _workLocation);
  }

  void saveHome(String address, LatLng location) {
    _homeAddress = address;
    _homeLocation = location;
    notifyListeners();
  }

  void saveWork(String address, LatLng location) {
    _workAddress = address;
    _workLocation = location;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // SOLICITAÇÃO DE CORRIDA REAL
  // ---------------------------------------------------------------------------
  Future<void> requestRide(String passengerId) async {
    if (_destinationLocation == null || _destinationAddress == null) return;

    _isRequestingRide = true;
    _prioritySecondsRemaining = AppConstants.favoritePrioritySeconds;
    notifyListeners();

    final newRide = RideModel(
      id: '',
      passengerId: passengerId,
      status: 'requested',
      vehicleType: _selectedVehicleType,
      originAddress: _originAddress,
      originLat: _currentLocation.latitude,
      originLng: _currentLocation.longitude,
      destinationAddress: _destinationAddress!,
      destinationLat: _destinationLocation!.latitude,
      destinationLng: _destinationLocation!.longitude,
      distanceKm: _distanceKm,
      estimatedDurationMin: _estimatedDurationMin,
      estimatedFare: _estimatedFare,
      paymentMethod: _paymentMethod,
      createdAt: DateTime.now(),
    );

    _activeRide = await _supabaseService.requestRide(newRide);
    notifyListeners();

    // Contador regressivo dos 15s de prioridade
    _priorityTimer?.cancel();
    _priorityTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_prioritySecondsRemaining > 0) {
        _prioritySecondsRemaining--;
        notifyListeners();
      } else {
        _priorityTimer?.cancel();
        notifyListeners();
      }
    });

    // Escuta atualizações da corrida em tempo real
    _rideSubscription?.cancel();
    _rideSubscription = _supabaseService.streamRide(_activeRide!.id).listen((updatedRide) {
      _activeRide = updatedRide;
      if (updatedRide.status == 'accepted' || updatedRide.status == 'arrived' || updatedRide.status == 'in_progress') {
        _priorityTimer?.cancel();
        _isRequestingRide = false;

        // Se houver um motorista vinculado, escuta a localização dele em tempo real
        if (updatedRide.driverId != null) {
          _driverLocationSub?.cancel();
          _driverLocationSub = _supabaseService.streamDriverLocation(updatedRide.driverId!).listen((driverPos) {
            if (driverPos != null) {
              _assignedDriverLocation = driverPos;
              notifyListeners();
            }
          });
        }
      }
      notifyListeners();
    });
  }

  Future<void> cancelRide() async {
    if (_activeRide != null) {
      await _supabaseService.updateRideStatus(_activeRide!.id, 'cancelled');
    }
    _priorityTimer?.cancel();
    _driverLocationSub?.cancel();
    _assignedDriverLocation = null;
    _isRequestingRide = false;
    _activeRide = null;
    notifyListeners();
  }

  Future<void> toggleFavorite(String passengerId, String driverId) async {
    final isFav = await _supabaseService.toggleFavoriteDriver(passengerId, driverId);
    if (isFav) {
      if (!_favoriteDriverIds.contains(driverId)) _favoriteDriverIds.add(driverId);
    } else {
      _favoriteDriverIds.remove(driverId);
    }
    notifyListeners();
  }

  Future<void> submitRatingAndFinish({
    required String passengerId,
    required int score,
    String? comment,
    bool addToFavorites = false,
  }) async {
    if (_activeRide == null) return;

    if (addToFavorites && _activeRide!.driverId != null) {
      await toggleFavorite(passengerId, _activeRide!.driverId!);
    }

    if (_activeRide!.driverId != null) {
      await _supabaseService.submitRating(
        rideId: _activeRide!.id,
        passengerId: passengerId,
        driverId: _activeRide!.driverId!,
        score: score,
        comment: comment,
      );
    }

    _activeRide = null;
    _destinationAddress = null;
    _destinationLocation = null;
    _driverLocationSub?.cancel();
    _assignedDriverLocation = null;
    notifyListeners();
  }

  void _initAmbientVehicles(LatLng center) {
    _ambientVehicles = [
      {
        'driver_id': 'ambient-car-1',
        'full_name': 'Carro Parceiro • Onix Branco',
        'latitude': center.latitude + 0.0032,
        'longitude': center.longitude + 0.0028,
        'heading': 45.0,
        'vehicle_type': 'car',
      },
      {
        'driver_id': 'ambient-moto-1',
        'full_name': 'Moto Parceira • Honda CG 160',
        'latitude': center.latitude - 0.0022,
        'longitude': center.longitude - 0.0025,
        'heading': 135.0,
        'vehicle_type': 'motorcycle',
      },
      {
        'driver_id': 'ambient-car-2',
        'full_name': 'Carro Parceiro • HB20 Prata',
        'latitude': center.latitude - 0.0041,
        'longitude': center.longitude + 0.0035,
        'heading': 270.0,
        'vehicle_type': 'car',
      },
      {
        'driver_id': 'ambient-moto-2',
        'full_name': 'Moto Parceira • Yamaha Fazer',
        'latitude': center.latitude + 0.0025,
        'longitude': center.longitude - 0.0038,
        'heading': 180.0,
        'vehicle_type': 'motorcycle',
      },
      {
        'driver_id': 'ambient-car-3',
        'full_name': 'Carro Parceiro • Argo Cinza',
        'latitude': center.latitude + 0.0045,
        'longitude': center.longitude - 0.0015,
        'heading': 90.0,
        'vehicle_type': 'car',
      },
    ];
  }

  void _startAmbientMovement() {
    _ambientMovementTimer?.cancel();
    _ambientMovementTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_ambientVehicles.isEmpty) return;

      for (int i = 0; i < _ambientVehicles.length; i++) {
        final v = _ambientVehicles[i];
        double lat = (v['latitude'] as double);
        double lng = (v['longitude'] as double);
        double heading = (v['heading'] as double);

        // Movimento suave simulando deslocamento de rua
        final rad = heading * (3.141592653589793 / 180);
        const double step = 0.00018; // ~20 metros
        lat += math.cos(rad) * step;
        lng += math.sin(rad) * step;

        // Se afastar mais de 1.8 km do passageiro, reposiciona perto em outra direção
        final dist = GeoUtils.calculateDistance(_currentLocation, LatLng(lat, lng));
        if (dist > 1.8) {
          lat = _currentLocation.latitude + (math.Random().nextDouble() - 0.5) * 0.006;
          lng = _currentLocation.longitude + (math.Random().nextDouble() - 0.5) * 0.006;
          heading = math.Random().nextDouble() * 360;
        }

        // Leve rotação de curvas de rua
        heading = (heading + (math.Random().nextDouble() * 16 - 8)) % 360;

        _ambientVehicles[i] = {
          ...v,
          'latitude': lat,
          'longitude': lng,
          'heading': heading,
        };
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _ambientMovementTimer?.cancel();
    _priorityTimer?.cancel();
    _rideSubscription?.cancel();
    _driverLocationSub?.cancel();
    _gpsSubscription?.cancel();
    _onlineDriversSub?.cancel();
    super.dispose();
  }
}
