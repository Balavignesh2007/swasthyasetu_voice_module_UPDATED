import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/clinical_voice_result.dart';
import '../models/patient.dart';
import '../models/voice_note.dart';
import '../services/api_service.dart';
import '../services/offline_sync_service.dart';
import '../services/session_service.dart';

class VoiceNoteScreen extends StatefulWidget {
  const VoiceNoteScreen({super.key});

  @override
  State<VoiceNoteScreen> createState() => _VoiceNoteScreenState();
}

class _VoiceNoteScreenState extends State<VoiceNoteScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _api = ApiService();
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();

  // Speech Recognition
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  String _speechStatus = '';
  double _soundLevel = 0.0;

  List<AshaPatient> _patients = [];
  String? _selectedPatientId;
  String _selectedLanguage = 'auto';

  bool _isProcessing = false;
  bool _isSaving = false;
  bool _isLoadingNotes = false;
  String? _errorMessage;

  ClinicalVoiceResult? _voiceResult;
  List<VoiceNote> _savedNotes = [];

  final List<Map<String, String>> _quickPhrases = [
    {
      'label': '🇮🇳 Hindi Emergency (Chest pain & breathing)',
      'lang': 'hi',
      'text': 'सीने में बहुत तेज़ दर्द है और सांस लेने में तकलीफ हो रही है',
    },
    {
      'label': '🇮🇳 Telugu Emergency (Heart pain & breathlessness)',
      'lang': 'te',
      'text': 'గుండె నొప్పి మరియు శ్వాస ఆడటం లేదు',
    },
    {
      'label': '🇮🇳 Tamil Emergency (Chest pain & breathing)',
      'lang': 'ta',
      'text': 'நெஞ்சு வலி மற்றும் மூச்சு விடுவதில் சிரமம்',
    },
    {
      'label': '🩺 Routine Check (Mild headache & cough)',
      'lang': 'hi',
      'text': 'हल्का सिरदर्द है और दो दिन से हल्की खांसी है',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
    _initSpeech();
  }

  @override
  void dispose() {
    _stopListening();
    _tabController.dispose();
    _textController.dispose();
    _summaryController.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (mounted) {
            setState(() {
              _speechStatus = status;
              if (status == 'done' || status == 'notListening') {
                _isListening = false;
              }
            });
          }
        },
        onError: (errorNotification) {
          if (mounted) {
            setState(() {
              _isListening = false;
              _errorMessage = 'Speech notice: ${errorNotification.errorMsg}';
            });
          }
        },
      );
      if (mounted) {
        setState(() => _speechEnabled = available);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _speechEnabled = false);
      }
    }
  }

  String _resolveLocaleId() {
    switch (_selectedLanguage) {
      case 'hi':
        return 'hi_IN';
      case 'te':
        return 'te_IN';
      case 'ta':
        return 'ta_IN';
      case 'en':
        return 'en_IN';
      default:
        return 'hi_IN';
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    if (!_speechEnabled) {
      await _initSpeech();
      if (!_speechEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Speech recognition not available on this browser/device. Please type or use quick presets.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    }

    final localeId = _resolveLocaleId();
    setState(() {
      _isListening = true;
      _errorMessage = null;
    });

    try {
      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _textController.text = result.recognizedWords;
              _textController.selection = TextSelection.fromPosition(
                TextPosition(offset: _textController.text.length),
              );
            });
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          cancelOnError: true,
          partialResults: true,
        ),
        localeId: localeId,
        onSoundLevelChange: (level) {
          if (mounted) setState(() => _soundLevel = level);
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isListening = false;
          _errorMessage = 'Failed to start microphone: $e';
        });
      }
    }
  }

  Future<void> _stopListening() async {
    try {
      await _speech.stop();
    } catch (_) {}
    if (mounted) {
      setState(() => _isListening = false);
    }
  }

  Future<void> _loadInitialData() async {
    final asha = await SessionService.getProfile();
    if (asha == null) return;

    try {
      final patients = await _api.fetchAssignedPatients(asha.id);
      if (mounted) setState(() => _patients = patients);
    } catch (_) {}

    _loadVoiceNotes();
  }

  Future<void> _loadVoiceNotes() async {
    final asha = await SessionService.getProfile();
    if (asha == null) return;

    setState(() => _isLoadingNotes = true);
    try {
      final notes = await _api.fetchVoiceNotes(ashaId: asha.id);
      if (mounted) {
        setState(() {
          _savedNotes = notes;
          _isLoadingNotes = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingNotes = false);
    }
  }

  Future<void> _processVoice() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter or dictate patient symptoms first.')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _voiceResult = null;
    });

    try {
      final result = await _api.processClinicalVoice(
        transcript: text,
        language: _selectedLanguage,
        patientId: _selectedPatientId,
      );

      if (mounted) {
        setState(() {
          _voiceResult = result;
          _isProcessing = false;
          if (result.suggestedAction != null) {
            _summaryController.text = result.suggestedAction!;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Online processing failed: $e. You can still save offline.';
        });
      }
    }
  }

  Future<void> _saveVoiceNote() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final asha = await SessionService.getProfile();
    if (asha == null) return;

    setState(() => _isSaving = true);

    final payload = {
      'patient_id': _selectedPatientId,
      'asha_id': asha.id,
      'author_role': 'asha',
      'raw_transcript': text,
      'translated_text': _voiceResult?.translatedText,
      'language': _voiceResult?.detectedLanguage ?? (_selectedLanguage == 'auto' ? 'en' : _selectedLanguage),
      'extracted_symptoms': _voiceResult?.standardizedSymptoms ?? [],
      'confirmed_symptoms': _voiceResult?.standardizedSymptoms ?? [],
      'is_emergency': _voiceResult?.emergency.isEmergency ?? false,
      'red_flag_type': _voiceResult?.emergency.redFlagType,
      'clinical_summary': _summaryController.text.trim().isNotEmpty
          ? _summaryController.text.trim()
          : _voiceResult?.suggestedAction,
    };

    try {
      await _api.saveVoiceNote(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Voice Note saved & Appointment directly scheduled in Doctor Portal!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
        _resetForm();
        _loadVoiceNotes();
        _tabController.animateTo(1);
      }
    } catch (e) {
      // Fallback to offline queue
      await OfflineSyncService.instance.queueVoiceNote(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved to Offline Queue. Will sync when online.'),
            backgroundColor: Colors.orange,
          ),
        );
        _resetForm();
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _resetForm() {
    _textController.clear();
    _summaryController.clear();
    setState(() {
      _voiceResult = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clinical Voice Module'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amberAccent,
          tabs: const [
            Tab(icon: Icon(Icons.mic), text: 'New Voice Note'),
            Tab(icon: Icon(Icons.history_edu), text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNewNoteTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildNewNoteTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Patient selector card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Assigned Patient (Optional)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedPatientId,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    isExpanded: true,
                    hint: const Text('General Community Check / Unverified Caller'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('General Community Check (No Patient Linked)'),
                      ),
                      ..._patients.map(
                        (p) => DropdownMenuItem<String>(
                          value: p.id,
                          child: Text('${p.name ?? "Unknown"} • ${p.village ?? "Unknown"}'),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedPatientId = val;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Quick Vernacular Phrases Chips
          const Text(
            'Quick Vernacular Symptom Presets (Tap to Test):',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _quickPhrases.map((phrase) {
              return ActionChip(
                avatar: const Icon(Icons.record_voice_over, size: 16),
                label: Text(phrase['label']!, style: const TextStyle(fontSize: 12)),
                backgroundColor: Colors.blue.shade50,
                onPressed: () {
                  _textController.text = phrase['text']!;
                  setState(() => _selectedLanguage = phrase['lang']!);
                  _processVoice();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Dictation input card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Patient Speech / Dictated Text',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      DropdownButton<String>(
                        value: _selectedLanguage,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'auto', child: Text('🌐 Auto-Detect')),
                          DropdownMenuItem(value: 'hi', child: Text('🇮🇳 Hindi')),
                          DropdownMenuItem(value: 'te', child: Text('🇮🇳 Telugu')),
                          DropdownMenuItem(value: 'ta', child: Text('🇮🇳 Tamil')),
                          DropdownMenuItem(value: 'en', child: Text('🇬🇧 English')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedLanguage = val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _textController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Type or speak symptoms in Hindi, Telugu, Tamil, or English...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _textController.clear(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Live Voice-to-Text Microphone Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isListening ? Colors.red.shade50 : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isListening ? Colors.red.shade300 : Colors.blue.shade200,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Material(
                          color: _isListening ? Colors.red : const Color(0xFF0D47A1),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _toggleListening,
                            child: Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Icon(
                                _isListening ? Icons.mic : Icons.mic_none,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isListening
                                    ? '🔴 Listening to patient speech (${_resolveLocaleId()})...'
                                    : '🎙️ Tap mic to detect patient voice in real-time',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _isListening ? Colors.red.shade900 : const Color(0xFF0D47A1),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isListening
                                    ? (_speechStatus.isNotEmpty
                                        ? '🔴 Listening (${_resolveLocaleId()}) • $_speechStatus'
                                        : '🔴 Listening (${_resolveLocaleId()}) • Speak now...')
                                    : 'Supports Hindi, Telugu, Tamil, & English voice input.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _isListening ? Colors.red.shade800 : Colors.grey.shade700,
                                ),
                              ),
                              if (_isListening)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: (_soundLevel / 10.0).clamp(0.15, 1.0),
                                      backgroundColor: Colors.red.shade100,
                                      color: Colors.red,
                                      minHeight: 3,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_isListening)
                          TextButton.icon(
                            onPressed: _stopListening,
                            icon: const Icon(Icons.stop_circle, color: Colors.red, size: 18),
                            label: const Text('Stop', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _processVoice,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.analytics_outlined),
                    label: Text(_isProcessing ? 'Analyzing Clinical Signals...' : 'Analyze Symptoms with AI'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Analysis Output Card
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade400),
              ),
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.brown)),
            ),

          if (_voiceResult != null) ...[
            _buildResultCard(_voiceResult!),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Clinical Summary / Recommendation for Doctor',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _summaryController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Add clinical notes, pulse, or follow-up instructions...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveVoiceNote,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isSaving ? 'Saving...' : 'Save Clinical Voice Note'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(46),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard(ClinicalVoiceResult result) {
    final isEmergency = result.emergency.isEmergency;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isEmergency ? Colors.red.shade600 : Colors.blue.shade200,
          width: isEmergency ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emergency Banner
            if (isEmergency) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'EMERGENCY RED FLAG DETECTED',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            result.emergency.redFlagType ?? 'Severe Medical Emergency',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (result.emergency.matchedSymptom != null)
                            Text(
                              'Matched symptom: ${result.emergency.matchedSymptom}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Pipeline Details
            Row(
              children: [
                Chip(
                  label: Text('Language: ${result.detectedLanguage.toUpperCase()}'),
                  backgroundColor: Colors.blue.shade50,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text('Triage: ${result.triageLevel ?? "LOW"}'),
                  backgroundColor: isEmergency ? Colors.red.shade100 : Colors.green.shade100,
                  labelStyle: TextStyle(
                    color: isEmergency ? Colors.red.shade900 : Colors.green.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),

            const Text(
              'English Translation (Multilingual Pivot):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              result.translatedText.isNotEmpty ? result.translatedText : result.rawTranscript,
              style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black87),
            ),
            const SizedBox(height: 8),

            const Text(
              'Extracted Symptoms & Standardized Terms:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            result.standardizedSymptoms.isEmpty
                ? const Text('No standard clinical symptoms detected.', style: TextStyle(color: Colors.grey))
                : Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: result.standardizedSymptoms.map((s) {
                      return Chip(
                        avatar: const Icon(Icons.check_circle, size: 14, color: Colors.teal),
                        label: Text(s, style: const TextStyle(fontSize: 12)),
                        backgroundColor: Colors.teal.shade50,
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 8),

            if (result.suggestedAction != null) ...[
              const Text(
                'Clinical Protocol Recommendation:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                result.suggestedAction!,
                style: TextStyle(
                  color: isEmergency ? Colors.red.shade800 : Colors.black87,
                  fontWeight: isEmergency ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_isLoadingNotes) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_savedNotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mic_none, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('No clinical voice notes recorded yet.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _tabController.animateTo(0),
              child: const Text('Record First Voice Note'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadVoiceNotes,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _savedNotes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final note = _savedNotes[index];
          final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(note.createdAt.toLocal());

          return Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: note.isEmergency ? Colors.red.shade300 : Colors.grey.shade300,
                width: note.isEmergency ? 1.5 : 0.5,
              ),
            ),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: note.isEmergency ? Colors.red.shade100 : Colors.blue.shade100,
                child: Icon(
                  note.isEmergency ? Icons.warning : Icons.mic,
                  color: note.isEmergency ? Colors.red.shade800 : Colors.blue.shade800,
                ),
              ),
              title: Text(
                note.rawTranscript,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '$dateStr • Lang: ${note.language.toUpperCase()}',
                style: const TextStyle(fontSize: 12),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (note.translatedText != null && note.translatedText!.isNotEmpty) ...[
                        const Text('Translation (English):', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(note.translatedText!),
                        const SizedBox(height: 8),
                      ],
                      if (note.extractedSymptoms.isNotEmpty) ...[
                        const Text('Symptoms:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Wrap(
                          spacing: 4,
                          children: note.extractedSymptoms
                              .map((s) => Chip(label: Text(s, style: const TextStyle(fontSize: 11))))
                              .toList(),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (note.clinicalSummary != null && note.clinicalSummary!.isNotEmpty) ...[
                        const Text('Summary / Plan:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(note.clinicalSummary!),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
