import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class OfflineSyncItem {
  final String clientId;
  final String type; // voice_note | follow_up_update | alert_ack
  final Map<String, dynamic> data;
  final DateTime timestamp;

  OfflineSyncItem({
    required this.clientId,
    required this.type,
    required this.data,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'client_id': clientId,
        'type': type,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
      };

  factory OfflineSyncItem.fromJson(Map<String, dynamic> json) {
    return OfflineSyncItem(
      clientId: json['client_id'] as String? ?? 'item_${DateTime.now().millisecondsSinceEpoch}',
      type: json['type'] as String? ?? 'voice_note',
      data: json['data'] as Map<String, dynamic>? ?? {},
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class OfflineSyncService extends ChangeNotifier {
  static final OfflineSyncService instance = OfflineSyncService._internal();
  OfflineSyncService._internal();

  static const String _storageKey = 'swasthyasetu_offline_queue';
  final List<OfflineSyncItem> _queue = [];
  bool _isSyncing = false;
  bool _isInitialized = false;

  bool get isSyncing => _isSyncing;
  int get pendingCount => _queue.length;
  List<OfflineSyncItem> get pendingItems => List.unmodifiable(_queue);

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        _queue.clear();
        for (var item in list) {
          _queue.add(OfflineSyncItem.fromJson(item as Map<String, dynamic>));
        }
      }
    } catch (e) {
      debugPrint('OfflineSyncService init error: $e');
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serialized = jsonEncode(_queue.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, serialized);
    } catch (e) {
      debugPrint('OfflineSyncService persist error: $e');
    }
    notifyListeners();
  }

  Future<void> queueVoiceNote(Map<String, dynamic> data) async {
    await init();
    final item = OfflineSyncItem(
      clientId: 'vn_${DateTime.now().millisecondsSinceEpoch}',
      type: 'voice_note',
      data: data,
      timestamp: DateTime.now(),
    );
    _queue.add(item);
    await _persist();
  }

  Future<void> queueFollowUpUpdate(String followUpId, Map<String, dynamic> data) async {
    await init();
    final payload = Map<String, dynamic>.from(data);
    payload['follow_up_id'] = followUpId;
    final item = OfflineSyncItem(
      clientId: 'fu_${DateTime.now().millisecondsSinceEpoch}',
      type: 'follow_up_update',
      data: payload,
      timestamp: DateTime.now(),
    );
    _queue.add(item);
    await _persist();
  }

  Future<void> queueAlertAck(String eventId, String status) async {
    await init();
    final item = OfflineSyncItem(
      clientId: 'ack_${DateTime.now().millisecondsSinceEpoch}',
      type: 'alert_ack',
      data: {'event_id': eventId, 'status': status},
      timestamp: DateTime.now(),
    );
    _queue.add(item);
    await _persist();
  }

  Future<void> queuePatientRegistration(Map<String, dynamic> data) async {
    await init();
    final item = OfflineSyncItem(
      clientId: 'pat_${DateTime.now().millisecondsSinceEpoch}',
      type: 'patient_registration',
      data: data,
      timestamp: DateTime.now(),
    );
    _queue.add(item);
    await _persist();
  }

  Future<int> syncWithBackend(ApiService api, String ashaId) async {
    if (_queue.isEmpty || _isSyncing) return 0;
    _isSyncing = true;
    notifyListeners();

    int syncedCount = 0;
    try {
      final itemsToSync = _queue.map((e) => e.toJson()).toList();
      final result = await api.batchSync(ashaId: ashaId, items: itemsToSync);

      final results = result['results'] as List<dynamic>? ?? [];
      final succeededClientIds = <String>{};

      for (var r in results) {
        if (r['status'] == 'success') {
          succeededClientIds.add(r['client_id'].toString());
        }
      }

      // Remove succeeded items from local queue
      _queue.removeWhere((item) => succeededClientIds.contains(item.clientId));
      syncedCount = (result['synced_count'] as num?)?.toInt() ?? succeededClientIds.length;
      await _persist();
    } catch (e) {
      debugPrint('Sync failed: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
    return syncedCount;
  }
}
