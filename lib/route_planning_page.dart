import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:amap_map/amap_map.dart';
import 'package:x_amap_base/x_amap_base.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart' as location_pkg;
import 'search.dart';
import 'route_service.dart';

const String _amapKey = '0f206954e6a24d40a66b42dc3fd24d01';

class RoutePlanningPage extends StatefulWidget {
  final SearchResult? startPoint;
  final SearchResult endPoint;
  final double? currentLat;
  final double? currentLng;

  const RoutePlanningPage({
    super.key,
    this.startPoint,
    required this.endPoint,
    this.currentLat,
    this.currentLng,
  });

  @override
  State<RoutePlanningPage> createState() => _RoutePlanningPageState();
}

class _RoutePlanningPageState extends State<RoutePlanningPage> {
  AMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  TravelMode _selectedMode = TravelMode.transit;
  bool _isLoading = false;
  RoutePlan? _routePlan;
  String? _errorMessage;
  SearchResult? _startPoint;
  SearchResult? _endPoint;
  bool _showSearch = false;
  bool _isSearchingStart = false;
  String _searchKeyword = '';
  List<SearchResult> _searchResults = [];
  bool _isSearchLoading = false;
  Timer? _searchDebounce;
  final location_pkg.Location _location = location_pkg.Location();

  @override
  void initState() {
    super.initState();
    debugPrint('[RoutePlanning] === initState ===');
    debugPrint('[RoutePlanning] startPoint: ${widget.startPoint?.name} (${widget.startPoint?.lat}, ${widget.startPoint?.lng})');
    debugPrint('[RoutePlanning] endPoint: ${widget.endPoint.name} (${widget.endPoint.lat}, ${widget.endPoint.lng})');
    debugPrint('[RoutePlanning] currentLat: ${widget.currentLat}, currentLng: ${widget.currentLng}');
    _startPoint = widget.startPoint;
    _endPoint = widget.endPoint;
    _addMarkers();
    _autoPlanRoute();
  }

  @override
  void dispose() {
    debugPrint('[RoutePlanning] === dispose ===');
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _addMarkers() {
    debugPrint('[RoutePlanning] _addMarkers: start=${_startPoint?.name}, end=${_endPoint?.name}');
    final newMarkers = <Marker>{};
    if (_startPoint != null) {
      newMarkers.add(
        Marker(
          position: LatLng(_startPoint!.lat, _startPoint!.lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          anchor: const Offset(0.5, 1.0),
        ),
      );
    }
    if (_endPoint != null) {
      newMarkers.add(
        Marker(
          position: LatLng(_endPoint!.lat, _endPoint!.lng),
          icon: BitmapDescriptor.defaultMarker,
          anchor: const Offset(0.5, 1.0),
        ),
      );
    }
    _markers = newMarkers;
    debugPrint('[RoutePlanning] _addMarkers done, total markers: ${_markers.length}');
  }

  void _onMapCreated(AMapController controller) {
    debugPrint('[RoutePlanning] _onMapCreated');
    _mapController = controller;
    _fitMapToBounds();
  }

  void _fitMapToBounds() {
    if (_startPoint != null && _endPoint != null) {
      final latMin = _startPoint!.lat < _endPoint!.lat ? _startPoint!.lat : _endPoint!.lat;
      final latMax = _startPoint!.lat > _endPoint!.lat ? _startPoint!.lat : _endPoint!.lat;
      final lngMin = _startPoint!.lng < _endPoint!.lng ? _startPoint!.lng : _endPoint!.lng;
      final lngMax = _startPoint!.lng > _endPoint!.lng ? _startPoint!.lng : _endPoint!.lng;
      final centerLat = (latMin + latMax) / 2;
      final centerLng = (lngMin + lngMax) / 2;
      debugPrint('[RoutePlanning] _fitMapToBounds: center=($centerLat, $centerLng), zoom=14');
      _mapController?.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(centerLat, centerLng),
            zoom: 14,
          ),
        ),
      );
    } else if (_endPoint != null) {
      debugPrint('[RoutePlanning] _fitMapToBounds: only endPoint, zoom=15');
      _mapController?.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_endPoint!.lat, _endPoint!.lng),
            zoom: 15,
          ),
        ),
      );
    } else {
      debugPrint('[RoutePlanning] _fitMapToBounds: no points available');
    }
  }

  Future<void> _autoPlanRoute() async {
    debugPrint('[RoutePlanning] _autoPlanRoute: start=${_startPoint != null}, end=${_endPoint != null}');
    await _planRoute();
  }

  Future<void> _planRoute() async {
    debugPrint('[RoutePlanning] === _planRoute ===');
    debugPrint('[RoutePlanning] mode: $_selectedMode');
    debugPrint('[RoutePlanning] start: ${_startPoint?.name} (${_startPoint?.lat}, ${_startPoint?.lng})');
    debugPrint('[RoutePlanning] end: ${_endPoint?.name} (${_endPoint?.lat}, ${_endPoint?.lng})');

    if (_endPoint == null) {
      debugPrint('[RoutePlanning] _planRoute aborted: endPoint is null');
      return;
    }

    if (_startPoint == null) {
      debugPrint('[RoutePlanning] _startPoint is null, attempting to use current position');
      if (widget.currentLat != null && widget.currentLng != null) {
        debugPrint('[RoutePlanning] Using passed current position as start: (${widget.currentLat}, ${widget.currentLng})');
        final currentPos = SearchResult(
          name: '我的位置',
          address: '',
          lat: widget.currentLat!,
          lng: widget.currentLng!,
        );
        _startPoint = currentPos;
        _addMarkers();
      } else {
        debugPrint('[RoutePlanning] No passed position, trying to acquire location directly...');
        try {
          await _location.requestPermission();
          final loc = await _location.getLocation();
          if (loc.latitude != null && loc.longitude != null &&
              loc.latitude != 0 && loc.longitude != 0 &&
              mounted) {
            debugPrint('[RoutePlanning] Acquired location: (${loc.latitude}, ${loc.longitude})');
            final currentPos = SearchResult(
              name: '我的位置',
              address: '',
              lat: loc.latitude!,
              lng: loc.longitude!,
            );
            _startPoint = currentPos;
            _addMarkers();
          } else {
            debugPrint('[RoutePlanning] Acquired location is invalid: (${loc.latitude}, ${loc.longitude})');
            if (mounted) setState(() => _errorMessage = '无法获取当前位置，请点击起点手动选择');
            return;
          }
        } catch (e) {
          debugPrint('[RoutePlanning] Failed to acquire location: $e');
          if (mounted) setState(() => _errorMessage = '无法获取当前位置，请点击起点手动选择');
          return;
        }
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _routePlan = null;
      _polylines = {};
    });

    try {
      RoutePlan plan;
      switch (_selectedMode) {
        case TravelMode.walking:
          debugPrint('[RoutePlanning] Calling RouteService.planWalking...');
          plan = await RouteService.planWalking(
            originLat: _startPoint!.lat,
            originLng: _startPoint!.lng,
            destLat: _endPoint!.lat,
            destLng: _endPoint!.lng,
          );
          debugPrint('[RoutePlanning] planWalking succeeded: dist=${plan.distance}, dur=${plan.duration}, segments=${plan.segments.length}');
          break;
        case TravelMode.driving:
          debugPrint('[RoutePlanning] Calling RouteService.planDriving...');
          plan = await RouteService.planDriving(
            originLat: _startPoint!.lat,
            originLng: _startPoint!.lng,
            destLat: _endPoint!.lat,
            destLng: _endPoint!.lng,
          );
          debugPrint('[RoutePlanning] planDriving succeeded: dist=${plan.distance}, dur=${plan.duration}, segments=${plan.segments.length}');
          break;
        case TravelMode.transit:
          final city = _startPoint!.city.isNotEmpty ? _startPoint!.city : await _getCityName(_startPoint!.lat, _startPoint!.lng);
          debugPrint('[RoutePlanning] Calling RouteService.planTransit with city=$city...');
          plan = await RouteService.planTransit(
            originLat: _startPoint!.lat,
            originLng: _startPoint!.lng,
            destLat: _endPoint!.lat,
            destLng: _endPoint!.lng,
            city: city,
            cityD: _endPoint!.city.isNotEmpty ? _endPoint!.city : null,
          );
          debugPrint('[RoutePlanning] planTransit succeeded: dist=${plan.distance}, dur=${plan.duration}, segments=${plan.segments.length}');
          break;
      }

      if (!mounted) {
        debugPrint('[RoutePlanning] Widget not mounted after API call, aborting');
        return;
      }

      debugPrint('[RoutePlanning] Polyline points count: ${plan.polylinePoints.length}');
      final routeColor = _getRouteColor(_selectedMode);
      final polyline = Polyline(
        points: plan.polylinePoints,
        width: 8,
        color: routeColor,
        alpha: 0.9,
      );

      setState(() {
        _routePlan = plan;
        _polylines = {polyline};
        _isLoading = false;
      });

      _fitMapToBounds();
      debugPrint('[RoutePlanning] === _planRoute completed successfully ===');
    } on TimeoutException {
      debugPrint('[RoutePlanning] ERROR: TimeoutException - request timed out');
      if (mounted) setState(() => _errorMessage = '请求超时，请检查网络连接');
    } catch (e) {
      debugPrint('[RoutePlanning] ERROR: $e');
      debugPrint('[RoutePlanning] Stack trace: ${StackTrace.current}');
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      if (errorMsg.contains('OVER_DIRECTION_RANGE')) {
        if (mounted) setState(() => _errorMessage = '距离过远，建议选择驾车或公交地铁前往');
      } else {
        if (mounted) setState(() => _errorMessage = errorMsg);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getRouteColor(TravelMode mode) {
    switch (mode) {
      case TravelMode.transit:
        return const Color(0xFF10B981);
      case TravelMode.walking:
        return const Color(0xFF3B82F6);
      case TravelMode.driving:
        return const Color(0xFFF59E0B);
    }
  }

  Future<String> _getCityName(double lat, double lng) async {
    debugPrint('[RoutePlanning] _getCityName: ($lat, $lng)');
    try {
      final uri = Uri.parse(
        'https://restapi.amap.com/v3/geocode/regeo'
        '?key=$_amapKey'
        '&location=$lng,$lat',
      );
      debugPrint('[RoutePlanning] Regeo request URL: $uri');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      debugPrint('[RoutePlanning] Regeo response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        debugPrint('[RoutePlanning] Regeo response: status=${data['status']}, info=${data['info']}');
        if (data['status'] == '1') {
          final regeo = data['regeocode'] as Map<String, dynamic>?;
          if (regeo != null) {
            final addressComponent = regeo['addressComponent'] as Map<String, dynamic>?;
            if (addressComponent != null) {
              final city = addressComponent['city'] as String?;
              debugPrint('[RoutePlanning] Regeo city: $city');
              if (city != null && city.isNotEmpty && city != '[]') {
                return city;
              }
              final province = addressComponent['province'] as String?;
              debugPrint('[RoutePlanning] Regeo province: $province');
              if (province != null && province.isNotEmpty) {
                return province;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[RoutePlanning] Regeo error: $e');
    }
    debugPrint('[RoutePlanning] Regeo failed, falling back to 北京');
    return '北京';
  }

  void _swapStartEnd() {
    debugPrint('[RoutePlanning] _swapStartEnd: swapping ${_startPoint?.name} <-> ${_endPoint?.name}');
    if (_startPoint == null || _endPoint == null) return;
    setState(() {
      final temp = _startPoint;
      _startPoint = _endPoint;
      _endPoint = temp;
      _markers = {};
      _polylines = {};
      _routePlan = null;
      _errorMessage = null;
    });
    _addMarkers();
    _fitMapToBounds();
    _planRoute();
  }

  BoxDecoration _buildBoxDecoration() {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey[300]!, width: 1),
    );
  }

  Widget _buildBlurredContainer({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: child,
      ),
    );
  }

  void _showSearchForStart() {
    setState(() {
      _showSearch = true;
      _isSearchingStart = true;
      _searchKeyword = '';
      _searchResults = [];
    });
  }

  void _showSearchForEnd() {
    setState(() {
      _showSearch = true;
      _isSearchingStart = false;
      _searchKeyword = '';
      _searchResults = [];
    });
  }

  Future<void> _performSearch() async {
    if (_searchKeyword.trim().isEmpty) return;
    debugPrint('[RoutePlanning] _performSearch: keyword=$_searchKeyword, isStart=$_isSearchingStart');
    setState(() => _isSearchLoading = true);
    try {
      final results = await SearchService.searchPlaces(
        _searchKeyword,
        currentLat: widget.currentLat,
        currentLng: widget.currentLng,
      );
      debugPrint('[RoutePlanning] Search results count: ${results.length}');
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearchLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[RoutePlanning] Search error: $e');
      if (mounted) setState(() => _isSearchLoading = false);
    }
  }

  void _onSearchResultSelected(SearchResult result) {
    debugPrint('[RoutePlanning] _onSearchResultSelected: ${result.name} (${result.lat}, ${result.lng}), isStart=$_isSearchingStart');
    setState(() {
      if (_isSearchingStart) {
        _startPoint = result;
      } else {
        _endPoint = result;
      }
      _showSearch = false;
      _markers = {};
      _polylines = {};
      _routePlan = null;
      _errorMessage = null;
    });
    _addMarkers();
    _fitMapToBounds();
    _planRoute();
  }

  @override
  Widget build(BuildContext context) {
    if (_showSearch) {
      return _buildSearchPage(context);
    }
    return _buildRoutePage(context);
  }

  Widget _buildSearchPage(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  _buildBlurredContainer(
                    child: Container(
                      decoration: _buildBoxDecoration(),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () => setState(() => _showSearch = false),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildBlurredContainer(
                      child: Container(
                        decoration: _buildBoxDecoration(),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: TextField(
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: _isSearchingStart ? '搜索起点' : '搜索终点',
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: Colors.grey[400]),
                          ),
                          onChanged: (value) {
                            _searchKeyword = value;
                            _searchDebounce?.cancel();
                            if (value.trim().isEmpty) {
                              setState(() => _searchResults = []);
                              return;
                            }
                            _searchDebounce = Timer(const Duration(milliseconds: 500), _performSearch);
                          },
                          onSubmitted: (_) {
                            _searchDebounce?.cancel();
                            _performSearch();
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isSearchLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _searchResults.isEmpty
                      ? Center(
                          child: Text(
                            _searchKeyword.trim().isEmpty ? '输入关键词搜索地点' : '未找到相关地点',
                            style: TextStyle(color: Colors.grey[500], fontSize: 14),
                          ),
                        )
                      : _buildBlurredContainer(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: _buildBoxDecoration(),
                            constraints: const BoxConstraints(maxHeight: 400),
                            child: ListView.builder(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final poi = _searchResults[index];
                                return ListTile(
                                  dense: true,
                                  title: Text(poi.name, style: const TextStyle(fontSize: 14)),
                                  subtitle: Text(poi.address, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                  onTap: () => _onSearchResultSelected(poi),
                                );
                              },
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutePage(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AMapWidget(
              mapType: MapType.normal,
              scaleEnabled: false,
              onMapCreated: _onMapCreated,
              markers: _markers,
              polylines: _polylines,
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            right: 8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildBlurredContainer(
                  child: Container(
                    decoration: _buildBoxDecoration(),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Container(
                                  width: 2,
                                  height: 20,
                                  color: Colors.grey[400],
                                ),
                                const Icon(Icons.location_on, size: 14, color: Colors.red),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: _showSearchForStart,
                                    child: Text(
                                      _startPoint?.name ?? '我的位置',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _startPoint != null ? Colors.black : Colors.grey[500],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: _showSearchForEnd,
                                    child: Text(
                                      _endPoint?.name ?? '选择终点',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _endPoint != null ? Colors.black : Colors.grey[500],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_startPoint != null && _endPoint != null)
                              GestureDetector(
                                onTap: _swapStartEnd,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.swap_vert, size: 18, color: Colors.grey),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildModeSelector(),
              ],
            ),
          ),

          if (_isLoading)
            const Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              right: 0,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('正在规划路线...', style: TextStyle(color: Colors.blue, fontSize: 14)),
                  ],
                ),
              ),
            ),

          if (_routePlan != null) _buildResultPanel(context),
          if (_errorMessage != null && _routePlan == null) _buildErrorPanel(),

          if (_routePlan == null && !_isLoading && _startPoint != null && _endPoint != null && _errorMessage == null)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 100,
              left: 0,
              right: 0,
              child: Center(
                child: _buildBlurredContainer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: _buildBoxDecoration(),
                    child: const Text('正在获取路线...', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    final modes = [
      (TravelMode.transit, '公交地铁', Icons.directions_bus),
      (TravelMode.walking, '步行', Icons.directions_walk),
      (TravelMode.driving, '驾车', Icons.directions_car),
    ];

    return _buildBlurredContainer(
      child: Container(
        decoration: _buildBoxDecoration(),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: modes.map((mode) {
            final isSelected = _selectedMode == mode.$1;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_selectedMode != mode.$1) {
                    debugPrint('[RoutePlanning] Mode switched to: ${mode.$2}');
                    setState(() {
                      _selectedMode = mode.$1;
                      _polylines = {};
                      _routePlan = null;
                      _errorMessage = null;
                    });
                    _planRoute();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue[50] : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(mode.$3, size: 16, color: isSelected ? Colors.blue : Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        mode.$2,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? Colors.blue : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildResultPanel(BuildContext context) {
    final plan = _routePlan!;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildInfoChip(Icons.timer_outlined, plan.durationText, Colors.blue),
                      const SizedBox(width: 12),
                      _buildInfoChip(Icons.straighten, plan.distanceText, Colors.green),
                      if (plan.walkingDistance != null && plan.walkingDistance! > 0) ...[
                        const SizedBox(width: 12),
                        _buildInfoChip(
                          Icons.directions_walk,
                          '步行${_formatDistance(plan.walkingDistance!)}',
                          Colors.orange,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                Flexible(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: plan.segments.length,
                    itemBuilder: (context, index) {
                      final segment = plan.segments[index];
                      final isLast = index == plan.segments.length - 1;
                      return Padding(
                        padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                Icon(
                                  segment.vehicle != null && segment.vehicle != '步行'
                                      ? Icons.directions_bus
                                      : Icons.directions_walk,
                                  size: 16,
                                  color: segment.vehicle != null && segment.vehicle != '步行'
                                      ? Colors.green
                                      : Colors.blue,
                                ),
                                if (!isLast)
                                  Container(
                                    width: 1,
                                    height: 20,
                                    color: Colors.grey[300],
                                  ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    segment.instruction,
                                    style: const TextStyle(fontSize: 13),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${_formatDistance(segment.distance)} · ${_formatDuration(segment.duration)}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorPanel() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 100,
      left: 16,
      right: 16,
      child: _buildBlurredContainer(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: _buildBoxDecoration(),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.red[400]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: TextStyle(fontSize: 13, color: Colors.red[700]),
                ),
              ),
              TextButton(
                onPressed: _planRoute,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('重试', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)}公里';
    }
    return '${meters.toStringAsFixed(0)}米';
  }

  String _formatDuration(int seconds) {
    if (seconds >= 60) {
      final minutes = seconds ~/ 60;
      return '$minutes分钟';
    }
    return '$seconds秒';
  }
}
