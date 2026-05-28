import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:amap_map/amap_map.dart';
import 'package:x_amap_base/x_amap_base.dart';
import 'package:location/location.dart' as location_pkg;
import 'setting.dart';
import 'search.dart';
import 'detail.dart';
import 'favorites_service.dart';
import 'favorites_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    AMapInitializer.init(
      context,
      apiKey: const AMapApiKey(
        androidKey: '4ce7c19261afa9d092e8d906867407e3',
        iosKey: '',
      ),
    );
    AMapInitializer.updatePrivacyAgree(
      const AMapPrivacyStatement(
        hasContains: true,
        hasShow: true,
        hasAgree: true,
      ),
    );

    return MaterialApp(
      title: '高德地图 Flutter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MapPage(),
    );
  }
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with WidgetsBindingObserver {
  AMapController? _mapController;
  final MapType _mapType = MapType.normal;
  final Set<Marker> _markers = {};
  bool _isMapReady = false;
  bool _isSearchFocused = false;
  BitmapDescriptor? _blueDotIcon;
  final location_pkg.Location _location = location_pkg.Location();
  final Completer<LatLng> _firstLocationCompleter = Completer<LatLng>();
  LatLng? _currentPosition;
  final GlobalKey _searchBoxKey = GlobalKey();
  double _gradientHeight = 0;
  List<FavoritePlace> _favorites = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateGradientHeight();
    });
    _initBlueDotIcon();
    _requestLocationPermission();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favorites = await FavoritesService.getFavorites();
    if (mounted) {
      setState(() {
        _favorites = favorites;
      });
    }
  }

  void _updateGradientHeight() {
    final RenderBox? renderBox = _searchBoxKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final searchBoxPosition = renderBox.localToGlobal(Offset.zero);
      final screenHeight = MediaQuery.of(context).size.height;
      setState(() {
        _gradientHeight = screenHeight - searchBoxPosition.dy;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateGradientHeight();
    });
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
        child: Container(
          decoration: _buildBoxDecoration(),
          child: child,
        ),
      ),
    );
  }

  Future<void> _initBlueDotIcon() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 48.0;
    const radius = size / 4;

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size / 2, size / 2), radius + 1.5, borderPaint);

    final fillPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size / 2, size / 2), radius, fillPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData != null) {
      _blueDotIcon = BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
      if (mounted) setState(() {});
    }
  }

  void _requestLocationPermission() async {
    await _location.requestPermission();
  }

  @override
  void reassemble() {
    super.reassemble();
    _requestLocationPermission();
  }

  @override
  void dispose() {
    _mapController = null;
    super.dispose();
  }

  void _onMapCreated(AMapController controller) {
    _mapController = controller;
    debugPrint('地图创建成功');
    setState(() {
      _isMapReady = true;
    });
  }

  void _onCameraMove(CameraPosition position) {
    debugPrint('相机位置: ${position.target.latitude}, ${position.target.longitude}');
  }

  void _onCameraMoveEnd(CameraPosition position) {
    debugPrint('相机移动结束: ${position.target.latitude}, ${position.target.longitude}');
  }

  void _onTap(LatLng latLng) {
    debugPrint('点击位置: ${latLng.latitude}, ${latLng.longitude}');
    setState(() {
      _markers.add(
        Marker(
          position: latLng,
          infoWindow: InfoWindow(
            title: '标记位置',
            snippet: '纬度: ${latLng.latitude.toStringAsFixed(4)}, 经度: ${latLng.longitude.toStringAsFixed(4)}',
          ),
        ),
      );
    });
  }

  void _onSearchResultTap(SearchResult poi) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DetailPage(
          place: poi,
          currentLat: _currentPosition?.latitude,
          currentLng: _currentPosition?.longitude,
        ),
      ),
    ).then((_) => _loadFavorites());
  }

  void _showSettingsDialog() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          AMapWidget(
            mapType: _mapType,
            myLocationStyleOptions: MyLocationStyleOptions(
              true,
              icon: _blueDotIcon,
            ),
            scaleEnabled: false,
            onMapCreated: _onMapCreated,
            onCameraMove: _onCameraMove,
            onCameraMoveEnd: _onCameraMoveEnd,
            onTap: _onTap,
            onLocationChanged: (AMapLocation loc) {
              if (loc.latLng.latitude >= -90 &&
                  loc.latLng.latitude <= 90 &&
                  loc.latLng.longitude >= -180 &&
                  loc.latLng.longitude <= 180 &&
                  (loc.latLng.latitude != 0 || loc.latLng.longitude != 0)) {
                setState(() {
                  _currentPosition = loc.latLng;
                });
                if (!_firstLocationCompleter.isCompleted) {
                  _firstLocationCompleter.complete(loc.latLng);
                  _mapController?.moveCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(target: loc.latLng, zoom: 15),
                    ),
                  );
                }
              }
            },
            markers: _markers,
            initialCameraPosition: const CameraPosition(
              target: LatLng(39.909187, 116.397451),
              zoom: 15,
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: _buildBlurredContainer(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(Icons.settings, color: Colors.grey[700]),
                  onPressed: _showSettingsDialog,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: _gradientHeight > 0 ? _gradientHeight : MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - 80 - 16,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.8),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!_isMapReady)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    '正在加载地图...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          IgnorePointer(
            ignoring: !_isSearchFocused,
            child: AnimatedOpacity(
              opacity: _isSearchFocused ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: GestureDetector(
                onTap: () {
                  FocusScope.of(context).unfocus();
                },
                child: Container(color: Colors.black.withValues(alpha: 0.3)),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            left: 16,
            right: 16,
            top: _isSearchFocused ? MediaQuery.of(context).padding.top + 8 : null,
            bottom: _isSearchFocused ? null : 32,
            child: Column(
              key: _searchBoxKey,
              mainAxisSize: MainAxisSize.min,
              children: [
                SearchWidget(
                  onResultTap: _onSearchResultTap,
                  onFocusChange: (isFocused) {
                    setState(() {
                      _isSearchFocused = isFocused;
                    });
                    _updateGradientHeight();
                  },
                  currentLat: _currentPosition?.latitude,
                  currentLng: _currentPosition?.longitude,
                ),
                const SizedBox(height: 8),
                if (!_isSearchFocused)
                  _buildBlurredContainer(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: _buildBoxDecoration(),
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '我的收藏',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_favorites.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => const FavoritesPage(),
                                    ),
                                  ).then((_) => _loadFavorites());
                                },
                                child: Row(
                                  children: [
                                    Text(
                                      '查看全部',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.blue[600],
                                      ),
                                    ),
                                    Icon(Icons.arrow_forward_ios, size: 12, color: Colors.blue[600]),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_favorites.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.favorite_border, size: 18, color: Colors.grey[500]),
                                const SizedBox(width: 8),
                                Text(
                                  '在地点详情页中可以收藏位置',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ...List.generate(
                            _favorites.length > 4 ? 4 : _favorites.length,
                            (index) {
                              final fav = _favorites[index];
                              return Padding(
                                padding: EdgeInsets.only(bottom: index < _favorites.length - 1 ? 6 : 0),
                                child: InkWell(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => DetailPage(place: fav.toSearchResult()),
                                      ),
                                    ).then((_) => _loadFavorites());
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.location_on, size: 18, color: Colors.red[400]),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                fav.name,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (fav.address.isNotEmpty)
                                                Text(
                                                  fav.address,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[500],
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                            ],
                                          ),
                                        ),
                                        Icon(Icons.chevron_right, size: 18, color: Colors.grey[400]),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        if (_favorites.length > 4)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const FavoritesPage(),
                                  ),
                                ).then((_) => _loadFavorites());
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '查看全部 ${_favorites.length} 个收藏',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey[500]),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
