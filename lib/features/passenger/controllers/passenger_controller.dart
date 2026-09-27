import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/ride_model.dart';
import '../../../core/models/driver_model.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/geo_utils.dart';

class PassengerController extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();

  LatLng _currentLocation = const LatLng(AppConstants.defaultLat, AppConstants.defaultLng);
  String _originAddress = 'Av. Paulista, 1578 - Bela Vista';
  
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
  List<String> _favoriteDriverIds = [];
  List<RideModel> _rideHistory = [];
  
  bool _isLoading = false;
  bool _isRequestingRide = false;
  int _prioritySecondsRemaining = 15;
  Timer? _priorityTimer;

  // Getters
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
      _currentLocation = await LocationService.getCurrentLocation();
      _favoriteDriverIds = await _supabaseService.getFavoriteDriverIds(passengerId);
      _rideHistory = await _supabaseService.getRideHistory(passengerId, isDriver: false);
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

  void setDestination(String address, LatLng location) {
    _destinationAddress = address;
    _destinationLocation = location;

    _distanceKm = GeoUtils.calculateDistance(_currentLocation, location);
    _estimatedDurationMoto = GeoUtils.estimateDurationMinutes(_distanceKm, vehicleType: 'motorcycle');
    _estimatedDurationCar = GeoUtils.estimateDurationMinutes(_distanceKm, vehicleType: 'car');
    
    _estimatedFareMoto = GeoUtils.calculateEstimatedFare(_distanceKm, _estimatedDurationMoto, vehicleType: 'motorcycle');
    _estimatedFareCar = GeoUtils.calculateEstimatedFare(_distanceKm, _estimatedDurationCar, vehicleType: 'car');

    _estimatedDurationMin = _selectedVehicleType == 'motorcycle' ? _estimatedDurationMoto : _estimatedDurationCar;
    _estimatedFare = _selectedVehicleType == 'motorcycle' ? _estimatedFareMoto : _estimatedFareCar;

    notifyListeners();
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
  // SOLICITAÇÃO DE CORRIDA COM REGRA DE PRIORIDADE PARA FAVORITOS (15s)
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

    // Inicia contador regressivo dos 15 segundos de prioridade para motoristas favoritos
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
      if (updatedRide.status == 'accepted') {
        _priorityTimer?.cancel();
        _isRequestingRide = false;
      }
      notifyListeners();
    });

    // Simulação caso nenhum motorista aceite imediatamente em ambiente offline de teste
    if (!_supabaseService.isLive) {
      Future.delayed(const Duration(seconds: 4), () {
        if (_activeRide != null && _activeRide!.isRequested) {
          final mockDriver = DriverModel(
            id: 'mock-driver-1',
            fullName: 'Marcos Silva',
            phone: '(11) 99887-1122',
            avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
            cnhNumber: '12345678900',
            vehicleModel: 'Toyota Corolla 2.0',
            vehiclePlate: 'BRA2E19',
            vehicleColor: 'Prata',
            vehicleYear: '2023',
            ratingAvg: 4.94,
            lastBilledAt: DateTime.now(),
          );
          _supabaseService.acceptRide(_activeRide!.id, mockDriver);
        }
      });
    }
  }

  Future<void> cancelRide() async {
    if (_activeRide != null) {
      await _supabaseService.updateRideStatus(_activeRide!.id, 'cancelled');
    }
    _priorityTimer?.cancel();
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
    if (_activeRide != null && _activeRide!.driverId != null) {
      await _supabaseService.submitRating(
        rideId: _activeRide!.id,
        passengerId: passengerId,
        driverId: _activeRide!.driverId!,
        score: score,
        comment: comment,
      );

      if (addToFavorites) {
        await toggleFavorite(passengerId, _activeRide!.driverId!);
      }
    }

    _activeRide = null;
    _destinationAddress = null;
    _destinationLocation = null;
    _priorityTimer?.cancel();
    _rideSubscription?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _priorityTimer?.cancel();
    _rideSubscription?.cancel();
    super.dispose();
  }
}
