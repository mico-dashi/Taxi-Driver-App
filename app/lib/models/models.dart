import 'package:latlong2/latlong.dart';

enum UserRole { passenger, driver }

class UserProfile {
  final String id;
  final String phone;
  final String name;
  final UserRole role;
  final double rating;

  const UserProfile({
    required this.id,
    required this.phone,
    required this.name,
    this.role = UserRole.passenger,
    this.rating = 5.0,
  });

  String get firstName => name.trim().split(' ').first;

  UserProfile copyWith({String? name, UserRole? role}) => UserProfile(
    id: id,
    phone: phone,
    name: name ?? this.name,
    role: role ?? this.role,
    rating: rating,
  );
}

class Place {
  final String name;
  final String subtitle;
  final LatLng point;

  const Place(this.name, this.subtitle, this.point);

  Map<String, dynamic> toJson() => {
    'name': name,
    'subtitle': subtitle,
    'lat': point.latitude,
    'lng': point.longitude,
  };

  factory Place.fromJson(Map<String, dynamic> j) => Place(
    j['name'] as String,
    (j['subtitle'] ?? '') as String,
    LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
  );

  @override
  bool operator ==(Object other) =>
      other is Place && other.name == name && other.point == point;

  @override
  int get hashCode => Object.hash(name, point);
}

/// A class of service (Standard, Comfort, Luxury, Van). Prices are in Lekë.
class VehicleCategory {
  final String id;
  final String nameKey;
  final int baseFare;
  final int perKm;
  final int perMinute;
  final int minFare;
  final int seats;

  const VehicleCategory({
    required this.id,
    required this.nameKey,
    required this.baseFare,
    required this.perKm,
    required this.perMinute,
    required this.minFare,
    required this.seats,
  });
}

class Vehicle {
  final String make;
  final String model;
  final String plate;
  final String color;
  final String categoryId;
  final int seats;

  const Vehicle({
    required this.make,
    required this.model,
    required this.plate,
    required this.color,
    required this.categoryId,
    this.seats = 4,
  });

  String get title => '$make $model';
}

class Driver {
  final String id;
  final String name;
  final String phone;
  final double rating;
  final int trips;
  final bool verified;
  final Vehicle vehicle;
  final LatLng location;
  final double heading;

  const Driver({
    required this.id,
    required this.name,
    required this.phone,
    required this.rating,
    required this.trips,
    required this.vehicle,
    required this.location,
    this.verified = true,
    this.heading = 0,
  });

  String get firstName => name.split(' ').first;

  Driver copyWith({LatLng? location, double? heading}) => Driver(
    id: id,
    name: name,
    phone: phone,
    rating: rating,
    trips: trips,
    vehicle: vehicle,
    verified: verified,
    location: location ?? this.location,
    heading: heading ?? this.heading,
  );
}

enum PaymentType { cash, card, applePay, googlePay }

class PaymentMethod {
  final String id;
  final PaymentType type;
  final String label;
  final String detail;

  const PaymentMethod({
    required this.id,
    required this.type,
    required this.label,
    this.detail = '',
  });

  static const cash = PaymentMethod(
    id: 'cash',
    type: PaymentType.cash,
    label: 'Cash',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'label': label,
    'detail': detail,
  };

  factory PaymentMethod.fromJson(Map<String, dynamic> j) => PaymentMethod(
    id: j['id'] as String,
    type: PaymentType.values.byName(j['type'] as String),
    label: j['label'] as String,
    detail: (j['detail'] ?? '') as String,
  );
}

class RouteInfo {
  final List<LatLng> points;
  final double distanceKm;
  final double durationMin;

  const RouteInfo({
    required this.points,
    required this.distanceKm,
    required this.durationMin,
  });
}

enum RequestStatus { searching, accepted, cancelled, expired }

/// What a passenger broadcasts to nearby drivers. The passenger proposes a
/// fare; drivers answer with offers (at that fare or higher).
class RideRequest {
  final String id;
  final String passengerId;
  final String passengerName;
  final double passengerRating;
  final Place pickup;
  final Place destination;
  final RouteInfo route;
  final String categoryId;
  final int offeredFare;
  final PaymentType payment;
  final RequestStatus status;
  final DateTime createdAt;

  const RideRequest({
    required this.id,
    required this.passengerId,
    required this.passengerName,
    required this.pickup,
    required this.destination,
    required this.route,
    required this.categoryId,
    required this.offeredFare,
    required this.payment,
    required this.createdAt,
    this.passengerRating = 5.0,
    this.status = RequestStatus.searching,
  });
}

enum OfferStatus { pending, accepted, declined, expired }

class RideOffer {
  final String id;
  final String requestId;
  final Driver driver;
  final int price;
  final int etaMinutes;
  final DateTime createdAt;
  final OfferStatus status;

  const RideOffer({
    required this.id,
    required this.requestId,
    required this.driver,
    required this.price,
    required this.etaMinutes,
    required this.createdAt,
    this.status = OfferStatus.pending,
  });
}

enum RideStatus {
  driverOnTheWay,
  driverArrived,
  inProgress,
  completed,
  cancelled,
}

class Ride {
  final String id;
  final RideRequest request;
  final Driver driver;
  final int price;
  final RideStatus status;
  final int etaMinutes;

  /// 0..1 progress of the current leg (driver → pickup, or pickup → destination).
  final double progress;
  final DateTime createdAt;
  final int? rating;
  final int tip;
  final String? cancelReason;

  const Ride({
    required this.id,
    required this.request,
    required this.driver,
    required this.price,
    required this.status,
    required this.etaMinutes,
    required this.createdAt,
    this.progress = 0,
    this.rating,
    this.tip = 0,
    this.cancelReason,
  });

  bool get isActive =>
      status != RideStatus.completed && status != RideStatus.cancelled;

  Ride copyWith({
    Driver? driver,
    RideStatus? status,
    int? etaMinutes,
    double? progress,
    int? rating,
    int? tip,
    String? cancelReason,
  }) => Ride(
    id: id,
    request: request,
    driver: driver ?? this.driver,
    price: price,
    status: status ?? this.status,
    etaMinutes: etaMinutes ?? this.etaMinutes,
    createdAt: createdAt,
    progress: progress ?? this.progress,
    rating: rating ?? this.rating,
    tip: tip ?? this.tip,
    cancelReason: cancelReason ?? this.cancelReason,
  );
}

class ChatMessage {
  final String id;
  final String rideId;
  final String senderId;
  final String text;
  final DateTime sentAt;

  const ChatMessage({
    required this.id,
    required this.rideId,
    required this.senderId,
    required this.text,
    required this.sentAt,
  });
}

class DriverEarnings {
  final int today;
  final int week;
  final int tripsToday;
  final int tripsWeek;
  final double onlineHoursToday;
  final List<Ride> recent;

  const DriverEarnings({
    required this.today,
    required this.week,
    required this.tripsToday,
    required this.tripsWeek,
    required this.onlineHoursToday,
    required this.recent,
  });
}
