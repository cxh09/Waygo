import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const String _amapKey = '0f206954e6a24d40a66b42dc3fd24d01';

class PlaceDetail {
  final String id;
  final String name;
  final String address;
  final String? phone;
  final String? type;
  final String? typeCode;
  final double lat;
  final double lng;
  final String? cityCode;
  final String? cityName;
  final String? province;
  final String? district;
  final String? businessArea;
  final List<String> photos;
  final Map<String, dynamic>? deepInfo;
  final String? intro;
  final String? rating;
  final String? cost;
  final String? openTime;
  final String? recommend;
  final List<Map<String, dynamic>>? groupBuys;
  final List<Map<String, dynamic>>? discounts;

  const PlaceDetail({
    required this.id,
    required this.name,
    required this.address,
    this.phone,
    this.type,
    this.typeCode,
    required this.lat,
    required this.lng,
    this.cityCode,
    this.cityName,
    this.province,
    this.district,
    this.businessArea,
    this.photos = const [],
    this.deepInfo,
    this.intro,
    this.rating,
    this.cost,
    this.openTime,
    this.recommend,
    this.groupBuys,
    this.discounts,
  });

  factory PlaceDetail.fromJson(Map<String, dynamic> json) {
    final location = (json['location'] as String?)?.split(',') ?? ['0', '0'];
    final lng = double.tryParse(location[0]) ?? 0.0;
    final lat = double.tryParse(location[1]) ?? 0.0;

    List<String> photos = [];
    if (json['photos'] != null) {
      final photoList = json['photos'] as List;
      photos = photoList.map((p) => p['url'] as String? ?? '').where((url) => url.isNotEmpty).toList();
    }

    List<Map<String, dynamic>>? groupBuys;
    if (json['groupbuys'] != null) {
      groupBuys = (json['groupbuys'] as List).cast<Map<String, dynamic>>();
    }

    List<Map<String, dynamic>>? discounts;
    if (json['discounts'] != null) {
      discounts = (json['discounts'] as List).cast<Map<String, dynamic>>();
    }

    return PlaceDetail(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      phone: json['tel'] as String?,
      type: json['type'] as String?,
      typeCode: json['typecode'] as String?,
      lat: lat,
      lng: lng,
      cityCode: json['citycode'] as String?,
      cityName: json['cityname'] as String?,
      province: json['pname'] as String?,
      district: json['adname'] as String?,
      businessArea: json['business_area'] as String?,
      photos: photos,
      deepInfo: json['deep_info'] as Map<String, dynamic>?,
      intro: json['intro'] as String?,
      rating: json['rating'] as String?,
      cost: json['cost'] as String?,
      openTime: json['opentime'] as String?,
      recommend: json['recommend'] as String?,
      groupBuys: groupBuys,
      discounts: discounts,
    );
  }
}

class PlaceDetailService {
  static Future<PlaceDetail> getPlaceDetail(String poiId) async {
    final uri = Uri.parse(
      'https://restapi.amap.com/v3/place/detail'
      '?key=$_amapKey'
      '&id=$poiId',
    );
    debugPrint('[PlaceDetailService] getPlaceDetail URL: $uri');
    
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    debugPrint('[PlaceDetailService] response status: ${response.statusCode}');
    
    if (response.statusCode != 200) {
      throw Exception('网络异常，请稍后重试');
    }
    
    final data = json.decode(response.body) as Map<String, dynamic>;
    debugPrint('[PlaceDetailService] response: status=${data['status']}, info=${data['info']}');
    
    if (data['status'] != '1') {
      throw Exception(data['info'] ?? '获取地点详情失败');
    }
    
    final pois = data['pois'] as List?;
    if (pois == null || pois.isEmpty) {
      throw Exception('未找到地点详情');
    }
    
    final poi = pois[0] as Map<String, dynamic>;
    return PlaceDetail.fromJson(poi);
  }
}
