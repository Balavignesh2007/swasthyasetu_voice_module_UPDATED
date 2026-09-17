import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../models/unified_models.dart';
import '../../services/unified_api_service.dart';
import '../../utils/vernacular_script_converter.dart';

class AshaVoiceNoteView extends StatefulWidget {
  final UnifiedApiService api;
  final UnifiedUserSession session;

  const AshaVoiceNoteView({
    super.key,
    required this.api,
    required this.session,
  });

  @override
  State<AshaVoiceNoteView> createState() => _AshaVoiceNoteViewState();
}

class _AshaVoiceNoteViewState extends State<AshaVoiceNoteView> {
  final _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;

  final _textController = TextEditingController();
  final _notesController = TextEditingController();

  List<AshaPatient> _patients = [];
  AshaPatient? _selectedPatient;
  String _selectedLanguage = 'hi';
  bool _loadingPatients = true;
  bool _processing = false;
  bool _submitting = false;
  ClinicalVoiceResult? _voiceResult;
  String? _statusMessage;
  bool _isEmergency = false;

  final Map<String, List<Map<String, String>>> _languagePresets = {
    'hi': [
      {
        'label': 'सीने में दर्द (Cardiac Flag)',
        'text': 'मरीज को सीने में तेज दर्द हो रहा है, पसीना आ रहा है और सांस लेने में बहुत दिक्कत हो रही है।',
        'emergency': 'true',
      },
      {
        'label': 'तेज बुखार और खांसी (Routine)',
        'text': 'मरीज को पिछले तीन दिनों से तेज बुखार, बदन दर्द और सूखी खांसी हो रही है।',
        'emergency': 'false',
      },
      {
        'label': 'पेट में गंभीर दर्द (Surgical Flag)',
        'text': 'मरीज के पेट के निचले हिस्से में असहनीय दर्द है और लगातार उल्टियां हो रही हैं।',
        'emergency': 'true',
      },
    ],
    'te': [
      {
        'label': 'ఛాతీ నొప్పి (Cardiac Flag)',
        'text': 'రోగికి ఛాతీలో తీవ్రమైన నొప్పి మరియు శ్వాస తీసుకోవడంలో ఇబ్బంది ఉంది.',
        'emergency': 'true',
      },
      {
        'label': 'తీవ్ర జ్వరం (Routine)',
        'text': 'రోగికి రెండు రోజుల నుండి తీవ్ర జ్వరం మరియు ఒళ్లు నొప్పులు ఉన్నాయి.',
        'emergency': 'false',
      },
    ],
    'ta': [
      {
        'label': 'நெஞ்சு வலி (Cardiac Flag)',
        'text': 'நோயாளிக்கு நெஞ்சு வலி மற்றும் மூச்சு விடுவதில் சிரமம் உள்ளது.',
        'emergency': 'true',
      },
      {
        'label': 'காய்ச்சல் (Routine)',
        'text': 'கடந்த மூன்று நாட்களாக நோயாளிக்கு அதிக காய்ச்சல் மற்றும் சளி உள்ளது.',
        'emergency': 'false',
      },
    ],
    'mr': [
      {
        'label': 'छातीत दुखणे (Cardiac Flag)',
        'text': 'रुग्णाला छातीत खूप तीव्र दुखत आहे, घाम येत आहे आणि श्वास घेण्यास त्रास होत आहे.',
        'emergency': 'true',
      },
      {
        'label': 'तीव्र ताप आणि खोकला (Routine)',
        'text': 'रुग्णाला गेल्या तीन दिवसांपासून खूप ताप, अंगदुखी आणि कोरडा खोकला येत आहे.',
        'emergency': 'false',
      },
      {
        'label': 'पोटात असह्य वेदना (Surgical Flag)',
        'text': 'रुग्णाच्या पोटात तीव्र वेदना होत आहेत आणि सतत उलट्या होत आहेत.',
        'emergency': 'true',
      },
    ],
    'en': [
      {
        'label': 'Severe Chest Pain (Cardiac Flag)',
        'text': 'Patient reports severe crushing chest pain radiating to the left arm and severe shortness of breath.',
        'emergency': 'true',
      },
      {
        'label': 'Fever & Cough (Routine)',
        'text': 'Patient has high grade fever for 3 days with throat pain and mild dry cough.',
        'emergency': 'false',
      },
    ],
  };

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _loadPatients();
  }

  @override
  void dispose() {
    _speech.stop();
    _textController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (mounted && (status == 'done' || status == 'notListening')) {
            setState(() {
              _isListening = false;
            });
          }
        },
        onError: (err) {
          if (mounted) {
            setState(() {
              _isListening = false;
              _statusMessage = 'Speech recognition note: ${err.errorMsg}';
            });
          }
        },
      );
      if (mounted) setState(() => _speechEnabled = available);
    } catch (_) {
      if (mounted) setState(() => _speechEnabled = false);
    }
  }

  String _resolveLocaleId() {
    switch (_selectedLanguage) {
      case 'hi':
        return 'hi-IN';
      case 'te':
        return 'te-IN';
      case 'mr':
        return 'mr-IN';
      case 'ta':
        return 'ta-IN';
      case 'en':
        return 'en-IN';
      default:
        return 'hi-IN';
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      if (!_speechEnabled) {
        await _initSpeech();
      }
      setState(() {
        _isListening = true;
        _statusMessage = null;
      });

      final localeId = _resolveLocaleId();
      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            final nativeText = VernacularScriptConverter.convertToNativeScript(
              result.recognizedWords,
              _selectedLanguage,
            );
            setState(() {
              _textController.text = nativeText;
            });
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
          localeId: localeId,
        ),
      );
    }
  }

  Future<void> _loadPatients() async {
    setState(() => _loadingPatients = true);
    try {
      final list = await widget.api.fetchAshaPatients(ashaId: widget.session.id);
      if (mounted) {
        setState(() {
          _patients = list;
          if (list.isNotEmpty) _selectedPatient = list.first;
          _loadingPatients = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingPatients = false);
    }
  }

  Future<void> _analyzeVoiceSymptoms() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please record or type symptoms first.')),
      );
      return;
    }

    setState(() {
      _processing = true;
      _statusMessage = null;
    });

    try {
      final res = await widget.api.processClinicalVoice(
        text: text,
        language: '$_selectedLanguage-IN',
      );
      if (mounted) {
        setState(() {
          _voiceResult = res;
          _isEmergency = res.emergencyFlag;
          _processing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _processing = false;
          _statusMessage = 'AI analysis error: $e';
        });
      }
    }
  }

  Future<void> _saveAndCreateDoctorAppointment() async {
    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a patient')),
      );
      return;
    }

    if (_voiceResult == null) {
      await _analyzeVoiceSymptoms();
      if (_voiceResult == null) return;
    }

    setState(() => _submitting = true);
    try {
      final resp = await widget.api.saveAshaVoiceNote(
        ashaId: widget.session.id,
        patientId: _selectedPatient!.id,
        result: _voiceResult!,
      );

      final appointmentId = resp['appointment_id'];
      final queueNumber = resp['queue_number'];
      final specialty = resp['suggested_specialty'] ?? _voiceResult!.suggestedSpecialty;

      if (mounted) {
        setState(() => _submitting = false);
        _showSuccessDialog(
          patientName: _selectedPatient!.name,
          queueNumber: queueNumber,
          specialty: specialty,
          appointmentId: appointmentId,
          isEmergency: _isEmergency,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save & create appointment: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showSuccessDialog({
    required String patientName,
    dynamic queueNumber,
    required String specialty,
    dynamic appointmentId,
    required bool isEmergency,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          isEmergency ? Icons.warning_rounded : Icons.check_circle,
          color: isEmergency ? Colors.red : Colors.green,
          size: 48,
        ),
        title: Text(
          isEmergency ? 'Appointment & Emergency Alert Created!' : 'Appointment Created in Doctor Portal!',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Patient $patientName\'s voice symptoms have been submitted to the Doctor Portal.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Assigned Queue: #${queueNumber ?? 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F766E))),
                  const SizedBox(height: 4),
                  Text('Specialty: $specialty', style: const TextStyle(fontWeight: FontWeight.w500)),
                  if (appointmentId != null)
                    Text('Appointment ID: ${appointmentId.toString().substring(0, 8)}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  if (isEmergency) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'ALERT: High triage red flag identified! Priority notification dispatched to Doctor & PHC.',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _textController.clear();
                _voiceResult = null;
                _isEmergency = false;
              });
            },
            child: const Text('Done & Record Next'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildPatientAndLangSelector(),
            const SizedBox(height: 16),
            _buildRecordingCard(),
            const SizedBox(height: 16),
            _buildPresetsSection(),
            if (_processing) ...[
              const SizedBox(height: 20),
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('Analyzing clinical symptoms & red flags with AI...'),
                  ],
                ),
              ),
            ],
            if (_voiceResult != null) ...[
              const SizedBox(height: 16),
              _buildAnalysisResultCard(),
            ],
            const SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Record Patient Voice Symptoms',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Dictate patient symptoms in vernacular language. Submitting auto-creates a Doctor OPD appointment.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPatientAndLangSelector() {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: _loadingPatients
                  ? const LinearProgressIndicator()
                  : DropdownButtonFormField<AshaPatient>(
                      initialValue: _selectedPatient,
                      decoration: const InputDecoration(
                        labelText: 'Select Patient',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: _patients.map((p) {
                        return DropdownMenuItem(
                          value: p,
                          child: Text('${p.name} (ABHA: ${p.healthId}, ${p.village ?? "Village"})'),
                        );
                      }).toList(),
                      onChanged: (p) => setState(() => _selectedPatient = p),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: DropdownButtonFormField<String>(
                initialValue: _selectedLanguage,
                decoration: const InputDecoration(
                  labelText: 'Speech Language',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: const [
                  DropdownMenuItem(value: 'hi', child: Text('Hindi (हिन्दी)')),
                  DropdownMenuItem(value: 'te', child: Text('Telugu (తెలుగు)')),
                  DropdownMenuItem(value: 'mr', child: Text('Marathi (मराठी)')),
                  DropdownMenuItem(value: 'ta', child: Text('Tamil (தமிழ்)')),
                  DropdownMenuItem(value: 'en', child: Text('English (Indian)')),
                ],
                onChanged: (lang) => setState(() => _selectedLanguage = lang ?? 'hi'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingCard() {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: _toggleListening,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening ? Colors.red : const Color(0xFF0F766E),
                      boxShadow: _isListening
                          ? [
                              BoxShadow(
                                color: Colors.red.withValues(alpha: 0.4),
                                blurRadius: 12,
                                spreadRadius: 4,
                              ),
                            ]
                          : [],
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isListening ? 'Listening to voice...' : 'Click microphone to start speech dictation',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _isListening ? Colors.red : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isListening
                            ? 'Speak now in ${_resolveLocaleId()} — speaking will automatically transcribe below.'
                            : 'Or type/edit symptoms manually or select a preset chip below.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                if (_isListening)
                  OutlinedButton.icon(
                    onPressed: _toggleListening,
                    icon: const Icon(Icons.stop, color: Colors.red, size: 16),
                    label: const Text('Stop Recording', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                  ),
              ],
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 8),
              Text(_statusMessage!, style: const TextStyle(fontSize: 11, color: Colors.orange)),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Recognized Voice Symptoms Transcript',
                hintText: 'Speech will transcribe here in real-time. You can also edit or type directly...',
                border: const OutlineInputBorder(),
                suffixIcon: _textController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _textController.clear()),
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetsSection() {
    final presets = _languagePresets[_selectedLanguage] ?? _languagePresets['hi']!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.flash_on, size: 16, color: Colors.amber.shade800),
            const SizedBox(width: 6),
            const Text(
              'Quick Vernacular Symptom Presets (Click to load):',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets.map((preset) {
            final isEm = preset['emergency'] == 'true';
            return ActionChip(
              avatar: Icon(
                isEm ? Icons.warning_amber_rounded : Icons.medical_services_outlined,
                size: 14,
                color: isEm ? Colors.red.shade700 : const Color(0xFF0F766E),
              ),
              label: Text(preset['label']!),
              backgroundColor: isEm ? Colors.red.shade50 : const Color(0xFFF1F5F9),
              side: BorderSide(color: isEm ? Colors.red.shade200 : const Color(0xFFCBD5E1)),
              onPressed: () {
                setState(() {
                  _textController.text = preset['text']!;
                });
                _analyzeVoiceSymptoms();
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAnalysisResultCard() {
    final res = _voiceResult!;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: res.emergencyFlag ? Colors.red.shade400 : Colors.teal.shade300,
          width: 1.5,
        ),
      ),
      color: res.emergencyFlag ? Colors.red.shade50 : const Color(0xFFF0FDFA),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  res.emergencyFlag ? Icons.warning_rounded : Icons.auto_awesome,
                  color: res.emergencyFlag ? Colors.red.shade700 : const Color(0xFF0F766E),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  res.emergencyFlag ? 'RED FLAG DETECTED - CRITICAL EMERGENCY' : 'AI Clinical Analysis & Triage',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: res.emergencyFlag ? Colors.red.shade800 : const Color(0xFF0F766E),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: res.emergencyFlag ? Colors.red.shade600 : const Color(0xFF0F766E),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    res.triageUrgency,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            if (res.englishTranscript.isNotEmpty) ...[
              Text(
                'English Translation: "${res.englishTranscript}"',
                style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                const Text('Suggested Doctor Specialty: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(
                  res.suggestedSpecialty,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0284C7), fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Extracted Symptoms: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: res.extractedSymptoms.map((s) {
                return Chip(
                  label: Text(s, style: const TextStyle(fontSize: 11)),
                  backgroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
            if (res.emergencyReason != null) ...[
              const SizedBox(height: 8),
              Text(
                'Reason: ${res.emergencyReason}',
                style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: _analyzeVoiceSymptoms,
          icon: const Icon(Icons.psychology, size: 18),
          label: const Text('Analyze Symptoms (AI)'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _submitting ? null : _saveAndCreateDoctorAppointment,
            icon: _submitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(
              _submitting ? 'Creating Appointment...' : 'Save & Send to Doctor Portal (Create Appointment)',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }
}
