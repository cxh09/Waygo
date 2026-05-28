import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:amap_map/amap_map.dart';
import 'package:x_amap_base/x_amap_base.dart';
import 'search.dart';
import 'favorites_service.dart';
import 'route_planning_page.dart';
import 'place_detail_service.dart';

class DetailPage extends StatefulWidget {
  final SearchResult place;
  final double? currentLat;
  final double? currentLng;

  const DetailPage({super.key, required this.place, this.currentLat, this.currentLng});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  AMapController? _mapController;
  final Set<Marker> _markers = {};
  bool _isFavorite = false;
  PlaceDetail? _placeDetail;
  bool _isLoadingDetail = false;

  @override
  void initState() {
    super.initState();
    _addMarker();
    _checkFavoriteStatus();
    _loadPlaceDetail();
  }

  Future<void> _loadPlaceDetail() async {
    final poiId = widget.place.id;
    if (poiId == null || poiId.isEmpty) {
      debugPrint('[DetailPage] poiId is null or empty, skip loading detail');
      return;
    }
    
    setState(() {
      _isLoadingDetail = true;
    });
    
    try {
      final detail = await PlaceDetailService.getPlaceDetail(poiId);
      if (mounted) {
        setState(() {
          _placeDetail = detail;
          _isLoadingDetail = false;
        });
      }
    } catch (e) {
      debugPrint('[DetailPage] loadPlaceDetail error: $e');
      if (mounted) {
        setState(() {
          _isLoadingDetail = false;
        });
      }
    }
  }

  Future<void> _checkFavoriteStatus() async {
    final id = FavoritesService.generateId(widget.place);
    final isFav = await FavoritesService.isFavorite(id);
    if (mounted) {
      setState(() {
        _isFavorite = isFav;
      });
    }
  }

  void _addMarker() {
    final marker = Marker(
      position: LatLng(widget.place.lat, widget.place.lng),
      icon: BitmapDescriptor.defaultMarker,
      anchor: const Offset(0.5, 1.0),
    );
    setState(() {
      _markers.add(marker);
    });
  }

  void _onMapCreated(AMapController controller) {
    _mapController = controller;
    debugPrint('详情页地图创建成功');
    // 移动相机到目标位置
    _mapController?.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(widget.place.lat, widget.place.lng),
          zoom: 15,
        ),
      ),
    );
  }

  void _showTopToast(String message) {
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: _ToastWidget(
              message: message,
              onDismiss: () {
                overlayEntry.remove();
              },
            ),
          ),
        );
      },
    );
    overlayState.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 2), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  Widget _buildInfoRow(IconData icon, String text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[500]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onTap != null)
              Icon(Icons.copy, size: 14, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _showMoreInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '位置详情',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '地址',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final addressText = widget.place.province.isNotEmpty || widget.place.city.isNotEmpty || widget.place.district.isNotEmpty
                          ? '${[widget.place.province, widget.place.city, widget.place.district].where((s) => s.isNotEmpty).join('')}${widget.place.address}'
                          : widget.place.address;
                      
                      return GestureDetector(
                        onLongPress: () async {
                          await Clipboard.setData(ClipboardData(text: addressText));
                          _showTopToast('地址已复制到剪贴板');
                        },
                        child: Text(
                          addressText,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '经纬度',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '经度: ${widget.place.lng.toStringAsFixed(6)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '纬度: ${widget.place.lat.toStringAsFixed(6)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 地图
          Positioned.fill(
            child: AMapWidget(
              mapType: MapType.normal,
              scaleEnabled: false,
              onMapCreated: _onMapCreated,
              markers: _markers,
              initialCameraPosition: CameraPosition(
                target: LatLng(widget.place.lat, widget.place.lng),
                zoom: 15,
              ),
            ),
          ),

          // 顶部搜索栏
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            right: 8,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!, width: 1),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!, width: 1),
                        ),
                        child: Text(
                          widget.place.name,
                          style: const TextStyle(fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!, width: 1),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.more_vert, color: Colors.black),
                        onPressed: _showMoreInfo,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 底部信息卡片
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 地名和地址
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.place.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (_placeDetail?.rating != null && _placeDetail!.rating!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star, size: 14, color: Colors.orange[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    _placeDetail!.rating!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.place.address,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (_placeDetail?.type != null && _placeDetail!.type!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _placeDetail!.type!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      
                      // 电话和营业时间
                      if (_placeDetail != null) ...[
                        if (_placeDetail!.phone != null && _placeDetail!.phone!.isNotEmpty)
                          _buildInfoRow(Icons.phone, _placeDetail!.phone!, onTap: () async {
                            await Clipboard.setData(ClipboardData(text: _placeDetail!.phone!));
                            _showTopToast('电话已复制');
                          }),
                        if (_placeDetail!.openTime != null && _placeDetail!.openTime!.isNotEmpty)
                          _buildInfoRow(Icons.access_time, _placeDetail!.openTime!),
                        if (_placeDetail!.cost != null && _placeDetail!.cost!.isNotEmpty)
                          _buildInfoRow(Icons.attach_money, '人均 ${_placeDetail!.cost!}'),
                        const SizedBox(height: 12),
                      ] else if (_isLoadingDetail)
                        Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.grey[400],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '加载详情中...',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      
                      const SizedBox(height: 16),

                      // 操作按钮
                      Row(
                        children: [
                          // 收藏按钮
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final id = FavoritesService.generateId(widget.place);
                                if (_isFavorite) {
                                  await FavoritesService.removeFavorite(id);
                                  if (mounted) {
                                    setState(() {
                                      _isFavorite = false;
                                    });
                                    _showTopToast('已取消收藏');
                                  }
                                } else {
                                  await FavoritesService.addFavorite(
                                    FavoritePlace(
                                      id: id,
                                      name: widget.place.name,
                                      address: widget.place.address,
                                      province: widget.place.province,
                                      city: widget.place.city,
                                      district: widget.place.district,
                                      lat: widget.place.lat,
                                      lng: widget.place.lng,
                                      addedTime: DateTime.now().millisecondsSinceEpoch,
                                    ),
                                  );
                                  if (mounted) {
                                    setState(() {
                                      _isFavorite = true;
                                    });
                                    _showTopToast('已收藏');
                                  }
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _isFavorite ? Colors.red[50] : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _isFavorite ? Icons.favorite : Icons.favorite_border,
                                      color: _isFavorite ? Colors.red : Colors.grey[700],
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _isFavorite ? '已收藏' : '收藏',
                                      style: TextStyle(
                                        color: _isFavorite ? Colors.red : Colors.grey[700],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // 路线规划按钮
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => RoutePlanningPage(
                                      endPoint: widget.place,
                                      currentLat: widget.currentLat,
                                      currentLng: widget.currentLng,
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.directions, color: Colors.blue, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      '路线',
                                      style: TextStyle(
                                        color: Colors.blue,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // 附近搜按钮
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                // TODO: 搜索附近
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.search, color: Colors.grey, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      '附近',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: MediaQuery.of(context).padding.bottom),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: GestureDetector(
        onTap: widget.onDismiss,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 18, color: Colors.green[600]),
                  const SizedBox(width: 8),
                  Text(
                    widget.message,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
