import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../models/unified_models.dart';
import '../../services/unified_api_service.dart';
import '../../utils/vernacular_script_converter.dart';

class PatientVoiceSymptomView extends StatefulWidget {
  final UnifiedApiService api;
  final UnifiedUserSession session;

  const PatientVoiceSymptomView({super.key, required this.api, required this.session});

  @override
  State<PatientVoiceSymptomView> createState() => _PatientVoiceSymptomViewState();
}

class _PatientVoiceSymptomViewState extends State<PatientVoiceSymptomView> {
  final _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  final _textController = TextEditingController();
  String _selectedLanguage = 'hi';
  bool _analyzing = false;
  bool _booking = false;
  ClinicalVoiceResult? _result;

  final Map<String, List<Map<String, String>>> _presets = {
    'hi': [
      {'label': 'छाती में दर्द (Chest Pain)', 'text': 'मुझे सीने में बहुत तेज दर्द हो रहा है और सांस फूल रही है।'},
      {'label': 'तेज बुखार (Fever)', 'text': 'मुझे तीन दिन से तेज बुखार है और बदन में बहुत दर्द है।'},
      {'label': 'पेट दर्द (Stomach Pain)', 'text': 'मेरे पेट में बहुत तेज दर्द हो रहा है और उल्टी जैसा लग रहा है।'},
    ],
    'te': [
      {'label': 'ఛాతీ నొప్పి (Chest Pain)', 'text': 'నాకు ఛాతీలో తీవ్రమైన నొప్పి ఉంది మరియు శ్వాస ఆడటం లేదు.'},
      {'label': 'తీవ్ర జ్వరం (Fever)', 'text': 'నాకు మూడు రోజుల నుండి తీవ్ర జ్వరం మరియు దగ్గు ఉంది.'},
    ],
    'ta': [
      {'label': 'நெஞ்சு வலி (Chest Pain)', 'text': 'எனக்கு நெஞ்சு வலி மற்றும் மூச்சு திணறல் உள்ளது.'},
      {'label': 'காய்ச்சல் (Fever)', 'text': 'எனக்கு இரண்டு நாட்களாக அதிக காய்ச்சல் உள்ளது.'},
    ],
    'mr': [
      {'label': 'छातीत तीव्र वेदना (Chest Pain)', 'text': 'माझ्या छातीत खूप तीव्र वेदना होत आहेत आणि मला श्वास घेता येत नाही.'},
      {'label': 'खूप ताप (High Fever)', 'text': 'मला गेल्या तीन दिवसांपासून खूप ताप आणि डोकेदुखी आहे.'},
      {'label': 'पोटदुखी (Stomach Pain)', 'text': 'माझ्या पोटात खूप दुखत आहे आणि सतत उलटी होत आहे.'},
    ],
    'en': [
      {'label': 'Chest Pain & Breathlessness', 'text': 'I have severe chest tightness, sweating, and difficulty breathing.'},
      {'label': 'Persistent High Fever', 'text': 'I have high fever and severe throat irritation for the past 2 days.'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _speech.stop();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (mounted && (status == 'done' || status == 'notListening')) {
            setState(() => _isListening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _isListening = false);
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
      if (!_speechEnabled) await _initSpeech();
      setState(() => _isListening = true);
      final localeId = _resolveLocaleId();
      await _speech.listen(
        onResult: (r) {
          if (mounted) {
            final nativeText = VernacularScriptConverter.convertToNativeScript(
              r.recognizedWords,
              _selectedLanguage,
            );
            setState(() => _textController.text = nativeText);
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

  Future<void> _analyze() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please speak or type your symptoms first.')),
      );
      return;
    }
    setState(() => _analyzing = true);
    try {
      final res = await widget.api.processClinicalVoice(
        text: text,
        language: '$_selectedLanguage-IN',
      );
      if (mounted) {
        setState(() {
          _result = res;
          _analyzing = false;
        });

        // Immediately trigger High Risk Alert to Doctor Dashboard if triage flagged high risk / emergency
        if (res.emergencyFlag || res.triageUrgency.toUpperCase() == 'HIGH' || res.triageUrgency.toUpperCase() == 'EMERGENCY') {
          widget.api.escalatePatientEmergency(
            patientId: widget.session.id,
            redFlagType: res.emergencyReason ?? 'High Risk Symptom Escalation',
            symptoms: text,
            severity: 'HIGH',
          ).catchError((_) {});
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _analyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error analyzing symptoms: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _bookAppointment() async {
    if (_result == null) return;
    setState(() => _booking = true);
    try {
      final resp = await widget.api.createPatientAppointment(
        patientId: widget.session.id,
        result: _result!,
        language: _selectedLanguage,
      );
      if (mounted) {
        setState(() => _booking = false);
        _showSuccessDialog(
          queueNumber: resp['queue_number'] ?? 1,
          specialty: resp['speciality'] ?? _result!.suggestedSpecialty,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _booking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to book appointment: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showSuccessDialog({required dynamic queueNumber, required String specialty}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 52),
        title: const Text('Appointment Booked in Doctor Portal!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your voice symptoms have been submitted directly to the Doctor\'s OPD Queue.',
              style: TextStyle(fontSize: 14),
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
                  Text('Queue Number: #$queueNumber', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F766E))),
                  const SizedBox(height: 4),
                  Text('Doctor Specialty: $specialty', style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  const Text('Status: Booked (Awaiting Doctor Review)', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
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
                _result = null;
              });
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 12.0 : 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Voice Symptom Checker & OPD Triage',
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Speak your symptoms in your own language. Immediate health guidance & doctor routing.',
                  style: TextStyle(fontSize: isMobile ? 12 : 13, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 14.0 : 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Language: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: _selectedLanguage,
                          items: const [
                            DropdownMenuItem(value: 'hi', child: Text('हिन्दी (Hindi)')),
                            DropdownMenuItem(value: 'te', child: Text('తెలుగు (Telugu)')),
                            DropdownMenuItem(value: 'mr', child: Text('मराठी (Marathi)')),
                            DropdownMenuItem(value: 'ta', child: Text('தமிழ் (Tamil)')),
                            DropdownMenuItem(value: 'en', child: Text('English (Indian)')),
                          ],
                          onChanged: (val) => setState(() => _selectedLanguage = val ?? 'hi'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _toggleListening,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isListening ? Colors.red : const Color(0xFF1976D2),
                                boxShadow: _isListening
                                    ? [
                                        BoxShadow(
                                          color: Colors.red.withValues(alpha: 0.4),
                                          blurRadius: 16,
                                          spreadRadius: 6,
                                        ),
                                      ]
                                    : [
                                        BoxShadow(
                                          color: Colors.blue.withValues(alpha: 0.2),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ],
                              ),
                              child: Icon(
                                _isListening ? Icons.mic : Icons.mic_none,
                                color: Colors.white,
                                size: 38,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _isListening ? 'Listening... Speak your symptoms' : 'Tap to speak your health issue',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _isListening ? Colors.red : const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _textController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Your Symptoms (Voice Transcribed or Typed)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (_presets[_selectedLanguage] ?? _presets['hi']!).map((p) {
                        return ActionChip(
                          avatar: const Icon(Icons.touch_app, size: 14),
                          label: Text(p['label']!),
                          onPressed: () {
                            setState(() => _textController.text = p['text']!);
                            _analyze();
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _analyzing ? null : _analyze,
                        icon: _analyzing
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.health_and_safety),
                        label: Text(_analyzing ? 'Analyzing Health Issue...' : 'Check Symptoms & Get Medical Advice'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_result != null) ...[
              const SizedBox(height: 20),
              _buildResultCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final r = _result!;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: r.emergencyFlag ? Colors.red.shade400 : Colors.blue.shade300,
          width: 1.5,
        ),
      ),
      color: r.emergencyFlag ? Colors.red.shade50 : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  r.emergencyFlag ? Icons.warning_rounded : Icons.check_circle_outline,
                  color: r.emergencyFlag ? Colors.red.shade700 : Colors.blue.shade700,
                  size: 26,
                ),
                const SizedBox(width: 8),
                Text(
                  r.emergencyFlag ? 'URGENT: Emergency Attention Required' : 'Assessment: Non-Emergency (Routine OPD)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: r.emergencyFlag ? Colors.red.shade900 : Colors.blue.shade900,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text('Symptoms Detected: ${r.extractedSymptoms.join(", ")}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Recommended Specialist: ${r.suggestedSpecialty}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1976D2))),
            if (r.emergencyReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(6)),
                child: Text('Clinical Warning: ${r.emergencyReason}', style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold)),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              r.emergencyFlag
                  ? 'Please visit the nearest Community Health Centre or Emergency Room immediately. Your ASHA worker has been notified.'
                  : 'You can book an OPD appointment with the Primary Health Centre doctor below.',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _booking ? null : _bookAppointment,
                icon: _booking
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  _booking ? 'Booking Appointment in Doctor Queue...' : 'Confirm & Book OPD Appointment with Doctor',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
        ),
      ),
    );
  }
}
