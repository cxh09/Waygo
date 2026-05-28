import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:math' show cos, sqrt, asin;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String _amapKey = '0f206954e6a24d40a66b42dc3fd24d01';

class SearchResult {
  final String name;
  final String address;
  final String province;
  final String city;
  final String district;
  final double lat;
  final double lng;
  final double? distance;

  const SearchResult({
    required this.name,
    required this.address,
    this.province = '',
    this.city = '',
    this.district = '',
    required this.lat,
    required this.lng,
    this.distance,
  });
}

class SearchService {
  static Future<List<SearchResult>> searchPlaces(String keyword, {double? currentLat, double? currentLng}) async {
    if (keyword.trim().isEmpty) {
      return [];
    }
    final uri = Uri.parse(
      'https://restapi.amap.com/v3/place/text'
      '?key=$_amapKey'
      '&keywords=${Uri.encodeComponent(keyword)}'
      '&offset=20'
      '&page=1'
      '&extensions=base',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('搜索失败，服务器异常');
    }
    final data = json.decode(response.body) as Map<String, dynamic>;
    if (data['status'] != '1' || data['pois'] == null) {
      throw Exception(data['info'] ?? '搜索失败');
    }
    final pois = data['pois'] as List;
    if (pois.isEmpty) {
      throw Exception('未找到相关地点');
    }
    return pois.map((p) {
      final location = (p['location'] as String).split(',');
      final lat = double.parse(location[1]);
      final lng = double.parse(location[0]);
      double? distance;
      if (currentLat != null && currentLng != null) {
        distance = _calculateDistance(currentLat, currentLng, lat, lng);
      }
      return SearchResult(
        name: p['name'] ?? '',
        address: p['address'] ?? '',
        province: p['pname'] ?? '',
        city: p['cityname'] ?? '',
        district: p['adname'] ?? '',
        lat: lat,
        lng: lng,
        distance: distance,
      );
    }).toList();
  }

  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    const c = cos;
    final a = 0.5 - c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000; // 单位：米
  }
}

class SearchWidget extends StatefulWidget {
  final Function(SearchResult) onResultTap;
  final ValueChanged<bool>? onFocusChange;
  final double? currentLat;
  final double? currentLng;

  const SearchWidget({
    super.key,
    required this.onResultTap,
    this.onFocusChange,
    this.currentLat,
    this.currentLng,
  });

  @override
  State<SearchWidget> createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<SearchResult> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;
  Timer? _searchDebounce;
  bool _isSearchFocused = false;
  List<String> _searchHistory = [];
  static const String _historyKey = 'search_history';

  String _formatDistance(double distance) {
    if (distance < 1000) {
      return '${distance.toStringAsFixed(0)}m';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)}km';
    }
  }
  static const int _maxHistoryItems = 10;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      final hasFocus = _searchFocusNode.hasFocus;
      setState(() {
        _isSearchFocused = hasFocus;
      });
      widget.onFocusChange?.call(hasFocus);
    });
    _loadSearchHistory();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_historyKey);
    if (history != null && mounted) {
      setState(() {
        _searchHistory = history;
      });
    }
  }

  Future<void> _saveToHistory(String keyword) async {
    if (keyword.trim().isEmpty) return;
    
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_historyKey) ?? [];
    
    history.remove(keyword);
    history.insert(0, keyword);
    
    if (history.length > _maxHistoryItems) {
      history.removeLast();
    }
    
    await prefs.setStringList(_historyKey, history);
    
    if (mounted) {
      setState(() {
        _searchHistory = history;
      });
    }
  }

  Future<void> _clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    if (mounted) {
      setState(() {
        _searchHistory = [];
      });
    }
  }

  Future<void> _searchPlaces() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      setState(() {
        _searchError = '请输入搜索关键词';
        _searchResults = [];
      });
      return;
    }
    await _saveToHistory(keyword);
    setState(() {
      _isSearching = true;
      _searchError = null;
      _searchResults = [];
    });
    try {
      final results = await SearchService.searchPlaces(
        keyword,
        currentLat: widget.currentLat,
        currentLng: widget.currentLng,
      );
      setState(() {
        _searchResults = results;
      });
    } on TimeoutException {
      setState(() => _searchError = '搜索超时，请检查网络连接');
    } catch (e) {
      setState(() => _searchError = '搜索失败，请稍后重试');
    } finally {
      setState(() => _isSearching = false);
    }
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

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildBlurredContainer(
          child: Container(
            width: double.infinity,
            decoration: _buildBoxDecoration(),
            child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            textInputAction: TextInputAction.search,
            onChanged: (value) {
              _searchDebounce?.cancel();
              if (_searchError != null) setState(() => _searchError = null);
              if (value.trim().isEmpty) {
                if (_searchResults.isNotEmpty) setState(() => _searchResults = []);
                return;
              }
              _searchDebounce = Timer(const Duration(milliseconds: 500), _searchPlaces);
            },
            onSubmitted: (_) {
              _searchDebounce?.cancel();
              _searchPlaces();
            },
            decoration: InputDecoration(
              hintText: '搜索地址',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _isSearching
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        ),
        if (_isSearchFocused && (_searchResults.isNotEmpty || _searchError != null || _isSearching || (_searchController.text.trim().isEmpty && _searchHistory.isNotEmpty)))
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                ),
                child: _isSearching
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _searchError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline, size: 18, color: Colors.grey[500]),
                              const SizedBox(width: 8),
                              Text(
                                _searchError!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _searchController.text.trim().isEmpty && _searchHistory.isNotEmpty
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.history, size: 18, color: Colors.grey),
                                        const SizedBox(width: 8),
                                        const Text(
                                          '搜索历史',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    GestureDetector(
                                      onTap: _clearSearchHistory,
                                      child: Row(
                                        children: [
                                          const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(
                                            '清除',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                                padding: EdgeInsets.zero,
                                itemCount: _searchHistory.length,
                                itemBuilder: (context, index) {
                                  final keyword = _searchHistory[index];
                                  return ListTile(
                                    dense: true,
                                    leading: Icon(Icons.history, size: 20, color: Colors.grey[400]),
                                    title: Text(
                                      keyword,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    onTap: () {
                                      _searchController.text = keyword;
                                      _searchDebounce?.cancel();
                                      _searchPlaces();
                                    },
                                  );
                                },
                              ),
                            ],
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                            padding: EdgeInsets.zero,
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final poi = _searchResults[index];
                              return ListTile(
                                dense: true,
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        poi.name,
                                        style: const TextStyle(fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (poi.distance != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          _formatDistance(poi.distance!),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  poi.address,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                onTap: () => widget.onResultTap(poi),
                              );
                            },
                          ),
                ),
              ),
            ),
      ],
    );
  }
}
