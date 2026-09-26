import 'package:latlong2/latlong.dart';

/// Renters look for cars; owners list their cars. One account can switch.
enum UserRole { renter, owner }

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
    this.role = UserRole.renter,
    this.rating = 5.0,
  });

  String get firstName => name.trim().split(' ').first;

  UserProfile copyWith({String? name, UserRole? role, String? phone}) =>
      UserProfile(
        id: id,
        phone: phone ?? this.phone,
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

/// Economy, SUV, Luxury, Van. Prices are suggestions in Lekë per day.
class CarCategory {
  final String id;
  final String nameKey;
  final int suggestedPerDay;
  final int suggestedDeposit;
  final int seats;

  const CarCategory({
    required this.id,
    required this.nameKey,
    required this.suggestedPerDay,
    required this.suggestedDeposit,
    required this.seats,
  });
}

enum Transmission { manual, automatic }

enum Fuel { petrol, diesel, hybrid, electric }

class Car {
  final String id;
  final String ownerId;
  final String ownerName;
  final double ownerRating;
  final String ownerPhone;
  final String make;
  final String model;
  final int year;
  final String plate;

  /// Paint colour as 0xAARRGGBB, used for the car drawing.
  final int colorValue;
  final String categoryId;
  final Transmission transmission;
  final Fuel fuel;
  final int seats;
  final int pricePerDay;
  final int deposit;
  final Place location;
  final bool delivery;
  final int deliveryFee;
  final int minDays;
  final int kmPerDay;
  final String description;
  final double rating;
  final int trips;
  final bool listed;

  /// Photo URLs (or data: URIs in demo mode), first one is the cover.
  final List<String> photos;

  const Car({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.make,
    required this.model,
    required this.year,
    required this.plate,
    required this.categoryId,
    required this.pricePerDay,
    required this.deposit,
    required this.location,
    this.ownerRating = 5.0,
    this.ownerPhone = '',
    this.colorValue = 0xFFE9EBEF,
    this.transmission = Transmission.manual,
    this.fuel = Fuel.diesel,
    this.seats = 5,
    this.delivery = false,
    this.deliveryFee = 0,
    this.minDays = 1,
    this.kmPerDay = 250,
    this.description = '',
    this.rating = 5.0,
    this.trips = 0,
    this.listed = true,
    this.photos = const [],
  });

  String get title => '$make $model';

  Car copyWith({
    String? id,
    String? ownerId,
    String? ownerName,
    Place? location,
    bool? listed,
    int? pricePerDay,
    List<String>? photos,
  }) => Car(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    ownerName: ownerName ?? this.ownerName,
    ownerRating: ownerRating,
    ownerPhone: ownerPhone,
    make: make,
    model: model,
    year: year,
    plate: plate,
    colorValue: colorValue,
    categoryId: categoryId,
    transmission: transmission,
    fuel: fuel,
    seats: seats,
    pricePerDay: pricePerDay ?? this.pricePerDay,
    deposit: deposit,
    location: location ?? this.location,
    delivery: delivery,
    deliveryFee: deliveryFee,
    minDays: minDays,
    kmPerDay: kmPerDay,
    description: description,
    rating: rating,
    trips: trips,
    listed: listed ?? this.listed,
    photos: photos ?? this.photos,
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

/// requested -> (countered ->) confirmed -> active -> completed.
/// Can end early as declined / cancelled / expired.
enum BookingStatus {
  requested,
  countered,
  confirmed,
  active,
  completed,
  declined,
  cancelled,
  expired,
}

enum Pickup { atOwner, delivery }

/// Started 24-hour periods between [start] and [end], at least one. Same
/// rule as `rental_days()` on the server.
int rentalDays(DateTime start, DateTime end) {
  final hours = end.difference(start).inHours;
  return hours <= 0 ? 1 : (hours / 24).ceil();
}

class Booking {
  final String id;
  final Car car;
  final String renterId;
  final String renterName;
  final double renterRating;
  final String renterPhone;
  final DateTime start;
  final DateTime end;

  /// What the renter asked to pay per day.
  final int offeredPerDay;

  /// Owner's counter-offer per day, if any.
  final int? counterPerDay;

  /// The agreed price per day once confirmed.
  final int? agreedPerDay;
  final BookingStatus status;
  final Pickup pickup;
  final String deliveryAddress;
  final PaymentType payment;
  final String note;

  /// First-rental promo discount applied to this booking (validated by the
  /// server when the request is made).
  final int promoPercent;
  final DateTime createdAt;
  final int? rating;
  final String? cancelReason;

  const Booking({
    required this.id,
    required this.car,
    required this.renterId,
    required this.renterName,
    required this.start,
    required this.end,
    required this.offeredPerDay,
    required this.status,
    required this.payment,
    required this.createdAt,
    this.renterRating = 5.0,
    this.renterPhone = '',
    this.counterPerDay,
    this.agreedPerDay,
    this.pickup = Pickup.atOwner,
    this.deliveryAddress = '',
    this.note = '',
    this.promoPercent = 0,
    this.rating,
    this.cancelReason,
  });

  /// Rental days, counted in started 24-hour periods (at least one).
  int get days => rentalDays(start, end);

  /// The price per day that currently applies.
  int get perDay => agreedPerDay ?? counterPerDay ?? offeredPerDay;

  bool get isOpen =>
      status == BookingStatus.requested || status == BookingStatus.countered;

  bool get isUpcomingOrActive =>
      status == BookingStatus.confirmed || status == BookingStatus.active;

  bool get isFinished =>
      status == BookingStatus.completed ||
      status == BookingStatus.declined ||
      status == BookingStatus.cancelled ||
      status == BookingStatus.expired;

  Booking copyWith({
    BookingStatus? status,
    int? counterPerDay,
    int? agreedPerDay,
    int? rating,
    String? cancelReason,
    Car? car,
  }) => Booking(
    id: id,
    car: car ?? this.car,
    renterId: renterId,
    renterName: renterName,
    renterRating: renterRating,
    renterPhone: renterPhone,
    start: start,
    end: end,
    offeredPerDay: offeredPerDay,
    counterPerDay: counterPerDay ?? this.counterPerDay,
    agreedPerDay: agreedPerDay ?? this.agreedPerDay,
    status: status ?? this.status,
    pickup: pickup,
    deliveryAddress: deliveryAddress,
    payment: payment,
    note: note,
    promoPercent: promoPercent,
    createdAt: createdAt,
    rating: rating ?? this.rating,
    cancelReason: cancelReason ?? this.cancelReason,
  );
}

class ChatMessage {
  final String id;
  final String threadId;
  final String senderId;
  final String text;
  final DateTime sentAt;

  const ChatMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.text,
    required this.sentAt,
  });
}

class OwnerEarnings {
  final int thisMonth;
  final int allTime;
  final int rentalsThisMonth;
  final int bookedDaysThisMonth;
  final List<Booking> recent;

  const OwnerEarnings({
    required this.thisMonth,
    required this.allTime,
    required this.rentalsThisMonth,
    required this.bookedDaysThisMonth,
    required this.recent,
  });
}
