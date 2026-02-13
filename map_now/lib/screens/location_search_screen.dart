import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/place_model.dart';

/// Full-screen search overlay.
/// Returns [PlaceModel] via Navigator.pop when the user selects a suggestion.
class LocationSearchScreen extends StatefulWidget {
  final String fieldLabel;
  final String? initialValue;

  const LocationSearchScreen({
    Key? key,
    required this.fieldLabel,
    this.initialValue,
  }) : super(key: key);

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<PlaceModel> _results = [];
  bool _isLoading = false;
  String? _error;
  Timer? _debounce;

  // ── Dummy locations for testing ──
  static final List<PlaceModel> _dummyPlaces = [
    PlaceModel(fullAddress: 'MG Road, Bengaluru, Karnataka 560001', latitude: 12.9758, longitude: 77.6045, placeId: 'dummy_1'),
    PlaceModel(fullAddress: 'Koramangala, Bengaluru, Karnataka 560034', latitude: 12.9352, longitude: 77.6245, placeId: 'dummy_2'),
    PlaceModel(fullAddress: 'Indiranagar, Bengaluru, Karnataka 560038', latitude: 12.9784, longitude: 77.6408, placeId: 'dummy_3'),
    PlaceModel(fullAddress: 'Whitefield, Bengaluru, Karnataka 560066', latitude: 12.9698, longitude: 77.7500, placeId: 'dummy_4'),
    PlaceModel(fullAddress: 'Jayanagar, Bengaluru, Karnataka 560041', latitude: 12.9308, longitude: 77.5838, placeId: 'dummy_5'),
    PlaceModel(fullAddress: 'HSR Layout, Bengaluru, Karnataka 560102', latitude: 12.9116, longitude: 77.6389, placeId: 'dummy_6'),
    PlaceModel(fullAddress: 'Electronic City, Bengaluru, Karnataka 560100', latitude: 12.8399, longitude: 77.6770, placeId: 'dummy_7'),
    PlaceModel(fullAddress: 'Malleshwaram, Bengaluru, Karnataka 560003', latitude: 12.9969, longitude: 77.5707, placeId: 'dummy_8'),
    PlaceModel(fullAddress: 'Brigade Road, Bengaluru, Karnataka 560025', latitude: 12.9724, longitude: 77.6065, placeId: 'dummy_9'),
    PlaceModel(fullAddress: 'Hebbal, Bengaluru, Karnataka 560024', latitude: 13.0358, longitude: 77.5970, placeId: 'dummy_10'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null && widget.initialValue!.isNotEmpty) {
      _controller.text = widget.initialValue!;
    }
    // Auto-focus the search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Simulate short network delay, then filter dummy places
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    final lowerQ = query.toLowerCase();
    final filtered = _dummyPlaces
        .where((p) => p.fullAddress.toLowerCase().contains(lowerQ))
        .toList();

    setState(() {
      _results = filtered.isEmpty ? _dummyPlaces : filtered;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFF171717),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          // ── Top bar ──
          Container(
            padding: EdgeInsets.fromLTRB(12, topPadding + 10, 12, 12),
            decoration: const BoxDecoration(
              color: Color(0xFF212121),
              border: Border(
                bottom: BorderSide(color: Color(0xFF333333), width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button + label
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.fieldLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Search input
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF333333),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      hintText: 'Search for a place...',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: 20,
                      ),
                      suffixIcon: _controller.text.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _controller.clear();
                                setState(() {
                                  _results = [];
                                  _error = null;
                                });
                              },
                              child: Icon(
                                Icons.close,
                                color: Colors.white.withValues(alpha: 0.5),
                                size: 18,
                              ),
                            )
                          : null,
                      border: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 12,
                      ),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
              ],
            ),
          ),

          // ── Results ──
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFB1FF8E),
                      strokeWidth: 2,
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _error!,
                            style: GoogleFonts.poppins(
                              color: Colors.red[300],
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : _results.isEmpty
                        ? Center(
                            child: Text(
                              _controller.text.isEmpty
                                  ? 'Type to search for a location'
                                  : 'No results found',
                              style: GoogleFonts.poppins(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 13,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _results.length,
                            separatorBuilder: (_, __) => Divider(
                              color: Colors.white.withValues(alpha: 0.08),
                              height: 1,
                              indent: 52,
                            ),
                            itemBuilder: (context, index) {
                              final place = _results[index];
                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 2,
                                ),
                                leading: Icon(
                                  Icons.location_on_outlined,
                                  color: Colors.white.withValues(alpha: 0.5),
                                  size: 20,
                                ),
                                title: Text(
                                  place.fullAddress,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () {
                                  Navigator.pop(context, place);
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
