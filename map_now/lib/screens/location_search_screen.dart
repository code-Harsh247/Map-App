import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/place_model.dart';
import '../services/geocoding_service.dart';
import '../services/search_history_service.dart';

/// Full-screen search overlay.
/// Returns [PlaceModel] via Navigator.pop when the user selects a suggestion.
class LocationSearchScreen extends StatefulWidget {
  final String fieldLabel;
  final String? initialValue;

  const LocationSearchScreen({
    super.key,
    required this.fieldLabel,
    this.initialValue,
  });

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final GeocodingService _geocodingService = GeocodingService();
  final SearchHistoryService _historyService = SearchHistoryService();
  final FocusNode _focusNode = FocusNode();

  List<PlaceModel> _results = [];
  List<PlaceModel> _history = [];
  bool _isLoading = false;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null && widget.initialValue!.isNotEmpty) {
      _controller.text = widget.initialValue!;
    }
    _loadHistory();
    // Auto-focus the search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  Future<void> _loadHistory() async {
    final history = await _historyService.getHistory();
    if (mounted) {
      setState(() {
        _history = history;
      });
    }
  }

  Future<void> _addToHistory(PlaceModel place) async {
    await _historyService.addToHistory(place);
    // Don't need to reload full history here if we just pop, 
    // but if user stays on screen (unlikely), valid.
  }

  Future<void> _deleteHistoryItem(int index) async {
    await _historyService.removeFromHistory(index);
    _loadHistory();
  }

  Future<void> _clearAllHistory() async {
    await _historyService.clearHistory();
    _loadHistory();
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
    
    // Minimum 3 characters requirement
    if (query.trim().length < 3) {
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
    try {
      final results = await _geocodingService.searchAddress(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Search failed. Please try again.';
        _results = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bool showHistory = _controller.text.isEmpty && _history.isNotEmpty;

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
                                  _loadHistory(); // Reload history on clear
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

          // ── Results or History ──
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
                    : (showHistory
                        ? _buildHistoryList()
                        : _results.isEmpty
                            ? Center(
                                child: Text(
                                  _controller.text.isEmpty
                                      ? 'Type to search for a location'
                                      : _controller.text.length < 3 
                                        ? 'Type at least 3 characters' 
                                        : 'No results found',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : _buildResultsList()),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              GestureDetector(
                onTap: _clearAllHistory,
                child: Text(
                  'Clear All',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFB1FF8E),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _history.length,
            separatorBuilder: (_, __) => Divider(
              color: Colors.white.withValues(alpha: 0.08),
              height: 1,
              indent: 52,
            ),
            itemBuilder: (context, index) {
              final place = _history[index];
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 2,
                ),
                leading: const Icon(
                  Icons.history,
                  color: Color(0xFFB1FF8E),
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
                trailing: GestureDetector(
                  onTap: () => _deleteHistoryItem(index),
                  child: Icon(
                    Icons.close,
                    color: Colors.white.withValues(alpha: 0.3),
                    size: 16,
                  ),
                ),
                onTap: () {
                  // Re-add to move to top
                  _addToHistory(place);
                  Navigator.pop(context, place);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultsList() {
    return ListView.separated(
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
          onTap: () async {
            await _addToHistory(place);
            if (!mounted) return;
            Navigator.pop(context, place);
          },
        );
      },
    );
  }
}
