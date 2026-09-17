import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/patient_models.dart';
import '../services/api_service.dart';

class CallHistoryScreen extends StatefulWidget {
  final String patientId;
  const CallHistoryScreen({super.key, required this.patientId});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  final _apiService = ApiService();
  List<VoiceHistoryEntry> _history = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _apiService.fetchVoiceHistory(widget.patientId);
      if (!mounted) return;
      setState(() {
        _history = data;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load call history: ${e.message}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not reach the server.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(onRefresh: _load, child: _buildBody());
  }

  Widget _buildBody() {
    if (_loading && _history.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _history.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Center(child: Text(_error!, textAlign: TextAlign.center)),
          const SizedBox(height: 12),
          Center(child: OutlinedButton(onPressed: _load, child: const Text('Retry'))),
        ],
      );
    }
    if (_history.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 100),
          Center(child: Text('No previous helpline calls found.')),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _history.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = _history[index];
        return ListTile(
          leading: CircleAvatar(
            child: Icon(entry.inputType == 'voice' ? Icons.mic : Icons.dialpad, size: 18),
          ),
          title: Text(
            entry.transcript ?? entry.interactionType.replaceAll('_', ' '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${DateFormat('MMM d, h:mm a').format(entry.createdAt.toLocal())}'
            '${entry.language != null ? " · ${entry.language!.toUpperCase()}" : ""}',
          ),
        );
      },
    );
  }
}
