import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'search.dart';

class FavoritePlace {
  final String id;
  final String name;
  final String address;
  final String province;
  final String city;
  final String district;
  final double lat;
  final double lng;
  final int addedTime;

  const FavoritePlace({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    this.province = '',
    this.city = '',
    this.district = '',
    required this.addedTime,
  });

  SearchResult toSearchResult() {
    return SearchResult(
      name: name,
      address: address,
      province: province,
      city: city,
      district: district,
      lat: lat,
      lng: lng,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'province': province,
      'city': city,
      'district': district,
      'lat': lat,
      'lng': lng,
      'addedTime': addedTime,
    };
  }

  factory FavoritePlace.fromJson(Map<String, dynamic> json) {
    return FavoritePlace(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      province: json['province'] as String? ?? '',
      city: json['city'] as String? ?? '',
      district: json['district'] as String? ?? '',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      addedTime: json['addedTime'] as int,
    );
  }
}

class FavoritesService {
  static const String _favoritesKey = 'favorite_places';

  static Future<List<FavoritePlace>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_favoritesKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      return jsonList
          .map((e) => FavoritePlace.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.addedTime.compareTo(a.addedTime));
    } catch (_) {
      return [];
    }
  }

  static Future<bool> isFavorite(String id) async {
    final favorites = await getFavorites();
    return favorites.any((f) => f.id == id);
  }

  static Future<void> addFavorite(FavoritePlace place) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavorites();
    favorites.removeWhere((f) => f.id == place.id);
    favorites.add(place);
    final jsonString = json.encode(favorites.map((f) => f.toJson()).toList());
    await prefs.setString(_favoritesKey, jsonString);
  }

  static Future<void> removeFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavorites();
    favorites.removeWhere((f) => f.id == id);
    final jsonString = json.encode(favorites.map((f) => f.toJson()).toList());
    await prefs.setString(_favoritesKey, jsonString);
  }

  static String generateId(SearchResult place) {
    return '${place.lat}_${place.lng}_${place.name}';
  }
}
