import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:x_amap_base/x_amap_base.dart';

const String _amapKey = '0f206954e6a24d40a66b42dc3fd24d01';

enum TravelMode { transit, walking, driving }

class RouteSegment {
  final String instruction;
  final double distance;
  final int duration;
  final String? vehicle;
  final List<LatLng> polylinePoints;

  const RouteSegment({
    required this.instruction,
    required this.distance,
    required this.duration,
    this.vehicle,
    required this.polylinePoints,
  });
}

class RoutePlan {
  final TravelMode mode;
  final double distance;
  final int duration;
  final List<RouteSegment> segments;
  final List<LatLng> polylinePoints;
  final double? walkingDistance;

  const RoutePlan({
    required this.mode,
    required this.distance,
    required this.duration,
    required this.segments,
    required this.polylinePoints,
    this.walkingDistance,
  });

  String get durationText {
    if (duration >= 3600) {
      final hours = duration ~/ 3600;
      final minutes = (duration % 3600) ~/ 60;
      return '$hours小时$minutes分钟';
    }
    final minutes = (duration / 60).round();
    return '$minutes分钟';
  }

  String get distanceText {
    if (distance >= 1000) {
      return '${(distance / 1000).toStringAsFixed(1)}公里';
    }
    return '${distance.toStringAsFixed(0)}米';
  }
}

List<LatLng> _parsePolyline(String polylineStr) {
  final points = <LatLng>[];
  final parts = polylineStr.split(';');
  for (final part in parts) {
    final coords = part.split(',');
    if (coords.length == 2) {
      final lng = double.tryParse(coords[0]);
      final lat = double.tryParse(coords[1]);
      if (lng != null && lat != null) {
        points.add(LatLng(lat, lng));
      }
    }
  }
  return points;
}

String _stringValue(dynamic value) {
  if (value == null) return '';
  if (value is String) return value;
  if (value is List) {
    return value.map((e) => e.toString()).join(' / ');
  }
  return value.toString();
}

int _intValue(dynamic value, {int defaultValue = 0}) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) {
    final parsed = int.tryParse(value);
    return parsed ?? defaultValue;
  }
  return defaultValue;
}

double _doubleValue(dynamic value, {double defaultValue = 0.0}) {
  if (value == null) return defaultValue;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    return parsed ?? defaultValue;
  }
  return defaultValue;
}

class RouteService {
  static Future<RoutePlan> planWalking({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    final uri = Uri.parse(
      'https://restapi.amap.com/v3/direction/walking'
      '?key=$_amapKey'
      '&origin=$originLng,$originLat'
      '&destination=$destLng,$destLat',
    );
    debugPrint('[RouteService] planWalking URL: $uri');
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    debugPrint('[RouteService] planWalking response status: ${response.statusCode}');
    if (response.statusCode != 200) {
      throw Exception('网络异常，请稍后重试');
    }
    final data = json.decode(response.body) as Map<String, dynamic>;
    debugPrint('[RouteService] planWalking response: status=${data['status']}, info=${data['info']}, count=${data['count']}');
    if (data['status'] != '1') {
      throw Exception(data['info'] ?? '步行路线规划失败');
    }
    final route = data['route'] as Map<String, dynamic>;
    final paths = route['paths'] as List;
    debugPrint('[RouteService] planWalking paths count: ${paths.length}');
    if (paths.isEmpty) {
      throw Exception('未找到步行路线');
    }
    final path = paths[0] as Map<String, dynamic>;
    final distance = _doubleValue(path['distance']);
    final duration = _intValue(path['duration']);
    final steps = path['steps'] as List;
    debugPrint('[RouteService] planWalking: distance=$distance, duration=$duration, steps=${steps.length}');

    final segments = <RouteSegment>[];
    final allPolylinePoints = <LatLng>[];

    for (final step in steps) {
      final stepMap = step as Map<String, dynamic>;
      final stepDistance = _doubleValue(stepMap['distance']);
      final stepDuration = _intValue(stepMap['duration']);
      final instruction = _stringValue(stepMap['instruction']);
      final polylineStr = stepMap['polyline'] as String? ?? '';
      final stepPoints = _parsePolyline(polylineStr);

      segments.add(RouteSegment(
        instruction: instruction,
        distance: stepDistance,
        duration: stepDuration,
        polylinePoints: stepPoints,
      ));
      allPolylinePoints.addAll(stepPoints);
    }

    debugPrint('[RouteService] planWalking done: total polyline points=${allPolylinePoints.length}');
    return RoutePlan(
      mode: TravelMode.walking,
      distance: distance,
      duration: duration,
      segments: segments,
      polylinePoints: allPolylinePoints,
    );
  }

  static Future<RoutePlan> planDriving({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    final uri = Uri.parse(
      'https://restapi.amap.com/v3/direction/driving'
      '?key=$_amapKey'
      '&origin=$originLng,$originLat'
      '&destination=$destLng,$destLat'
      '&extensions=all'
      '&strategy=0',
    );
    debugPrint('[RouteService] planDriving URL: $uri');
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    debugPrint('[RouteService] planDriving response status: ${response.statusCode}');
    if (response.statusCode != 200) {
      throw Exception('网络异常，请稍后重试');
    }
    final data = json.decode(response.body) as Map<String, dynamic>;
    debugPrint('[RouteService] planDriving response: status=${data['status']}, info=${data['info']}, count=${data['count']}');
    if (data['status'] != '1') {
      throw Exception(data['info'] ?? '驾车路线规划失败');
    }
    final route = data['route'] as Map<String, dynamic>;
    final paths = route['paths'] as List;
    debugPrint('[RouteService] planDriving paths count: ${paths.length}');
    if (paths.isEmpty) {
      throw Exception('未找到驾车路线');
    }
    final path = paths[0] as Map<String, dynamic>;
    final distance = _doubleValue(path['distance']);
    final duration = _intValue(path['duration']);
    final steps = path['steps'] as List;
    debugPrint('[RouteService] planDriving: distance=$distance, duration=$duration, steps=${steps.length}');

    final segments = <RouteSegment>[];
    final allPolylinePoints = <LatLng>[];

    for (final step in steps) {
      final stepMap = step as Map<String, dynamic>;
      final stepDistance = _doubleValue(stepMap['distance']);
      final stepDuration = _intValue(stepMap['duration']);
      final instruction = _stringValue(stepMap['instruction']);
      final polylineStr = stepMap['polyline'] as String? ?? '';
      final stepPoints = _parsePolyline(polylineStr);

      segments.add(RouteSegment(
        instruction: instruction,
        distance: stepDistance,
        duration: stepDuration,
        polylinePoints: stepPoints,
      ));
      allPolylinePoints.addAll(stepPoints);
    }

    debugPrint('[RouteService] planDriving done: total polyline points=${allPolylinePoints.length}');
    return RoutePlan(
      mode: TravelMode.driving,
      distance: distance,
      duration: duration,
      segments: segments,
      polylinePoints: allPolylinePoints,
    );
  }

  static Future<List<RoutePlan>> planTransit({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required String city,
    String? cityD,
  }) async {
    final uri = Uri.parse(
      'https://restapi.amap.com/v3/direction/transit/integrated'
      '?key=$_amapKey'
      '&origin=$originLng,$originLat'
      '&destination=$destLng,$destLat'
      '&city=${Uri.encodeComponent(city)}'
      '&cityd=${Uri.encodeComponent(cityD ?? city)}',
    );
    debugPrint('[RouteService] planTransit URL: $uri');
    debugPrint('[RouteService] planTransit params: city=$city, cityD=${cityD ?? city}');
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    debugPrint('[RouteService] planTransit response status: ${response.statusCode}');
    if (response.statusCode != 200) {
      throw Exception('网络异常，请稍后重试');
    }
    final data = json.decode(response.body) as Map<String, dynamic>;
    debugPrint('[RouteService] planTransit response: status=${data['status']}, info=${data['info']}');
    if (data['status'] != '1') {
      throw Exception(data['info'] ?? '公交路线规划失败');
    }
    final route = data['route'] as Map<String, dynamic>;
    final transits = route['transits'] as List?;
    debugPrint('[RouteService] planTransit transits count: ${transits?.length ?? 0}');
    if (transits == null || transits.isEmpty) {
      final distance = _doubleValue(route['distance']);
      debugPrint('[RouteService] planTransit no transit found, distance: $distance');
      if (distance > 0 && distance < 500) {
        throw Exception('距离仅${distance.toStringAsFixed(0)}米，建议直接步行前往');
      }
      throw Exception('未找到公交路线');
    }

    final plans = <RoutePlan>[];
    for (int i = 0; i < transits.length; i++) {
      final transit = transits[i] as Map<String, dynamic>;
      final distance = _doubleValue(transit['distance']);
      final duration = _intValue(transit['duration']);
      final walkingDistance = _doubleValue(transit['walking_distance'], defaultValue: 0);
      final segments = transit['segments'] as List;
      debugPrint('[RouteService] planTransit route $i: distance=$distance, duration=$duration, segments=${segments.length}, walkingDistance=$walkingDistance');

      final routeSegments = <RouteSegment>[];
      final allPolylinePoints = <LatLng>[];

      for (final segment in segments) {
        final segMap = segment as Map<String, dynamic>;

        if (segMap['walking'] != null) {
          final walking = segMap['walking'] as Map<String, dynamic>;
          final walkSteps = walking['steps'] as List? ?? [];

          for (final step in walkSteps) {
            final stepMap = step as Map<String, dynamic>;
            final instruction = _stringValue(stepMap['instruction']);
            final stepDist = _doubleValue(stepMap['distance']);
            final stepDur = _intValue(stepMap['duration']);
            final polylineStr = stepMap['polyline'] as String? ?? '';
            final stepPoints = _parsePolyline(polylineStr);

            routeSegments.add(RouteSegment(
              instruction: instruction,
              distance: stepDist,
              duration: stepDur,
              vehicle: '步行',
              polylinePoints: stepPoints,
            ));
            allPolylinePoints.addAll(stepPoints);
          }
        }

        if (segMap['bus'] != null) {
          final bus = segMap['bus'] as Map<String, dynamic>;
          final buslines = bus['buslines'] as List? ?? [];
          for (final busline in buslines) {
            final busMap = busline as Map<String, dynamic>;
            final busName = _stringValue(busMap['name']);
            final busDistance = _doubleValue(busMap['distance']);
            final busDuration = _intValue(busMap['duration']);
            final polylineStr = busMap['polyline'] as String? ?? '';
            final busPoints = _parsePolyline(polylineStr);

            final instruction = busName.isNotEmpty ? '乘坐 $busName' : '乘坐公交';
            routeSegments.add(RouteSegment(
              instruction: instruction,
              distance: busDistance,
              duration: busDuration,
              vehicle: busName,
              polylinePoints: busPoints,
            ));
            allPolylinePoints.addAll(busPoints);
          }
        }

        if (segMap['railway'] != null) {
          final railway = segMap['railway'] as Map<String, dynamic>;
          final trainName = _stringValue(railway['name']);
          final trip = _stringValue(railway['trip']);
          final departStop = railway['departure_stop']?['name'] ?? '';
          final arrivalStop = railway['arrival_stop']?['name'] ?? '';
          final railDuration = _intValue(railway['time']);
          final polylineStr = railway['polyline'] as String? ?? '';
          final railPoints = _parsePolyline(polylineStr);

          final instruction = trainName.isNotEmpty
              ? '乘坐 $trainName 从 $departStop 到 $arrivalStop'
              : '乘坐火车';
          routeSegments.add(RouteSegment(
            instruction: instruction,
            distance: _doubleValue(railway['distance']),
            duration: railDuration,
            vehicle: trip.isNotEmpty ? trip : trainName,
            polylinePoints: railPoints,
          ));
          allPolylinePoints.addAll(railPoints);
        }
      }

      plans.add(RoutePlan(
        mode: TravelMode.transit,
        distance: distance,
        duration: duration,
        segments: routeSegments,
        polylinePoints: allPolylinePoints,
        walkingDistance: walkingDistance,
      ));
    }

    debugPrint('[RouteService] planTransit done: total plans=${plans.length}');
    return plans;
  }
}
