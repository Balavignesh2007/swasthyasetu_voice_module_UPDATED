import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models/clinical_voice_result.dart';
import '../services/api_service.dart';

class VoiceSymptomScreen extends StatefulWidget {
  final String patientId;

  const VoiceSymptomScreen({super.key, required this.patientId});

  @override
  State<VoiceSymptomScreen> createState() => _VoiceSymptomScreenState();
}

class _VoiceSymptomScreenState extends State<VoiceSymptomScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  final TextEditingController _textController = TextEditingController();

  // Speech to text state
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  String _speechStatus = '';
  double _soundLevel = 0.0;

  String _selectedLanguage = 'auto';
  bool _isProcessing = false;
  String? _errorMessage;
  ClinicalVoiceResult? _voiceResult;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<Map<String, String>> _quickPhrases = [
    {
      'label': '🇮🇳 Hindi Emergency (Chest Pain & Breathing)',
      'lang': 'hi',
      'text': 'सीने में बहुत तेज़ दर्द है और सांस लेने में तकलीफ हो रही है',
    },
    {
      'label': '🇮🇳 Telugu Emergency (Heart Pain & Breathless)',
      'lang': 'te',
      'text': 'గుండె నొప్పి మరియు శ్వాస ఆడటం లేదు',
    },
    {
      'label': '🇮🇳 Tamil Emergency (Chest Pain & Breathing)',
      'lang': 'ta',
      'text': 'நெஞ்சு வலி மற்றும் மூச்சு விடுவதில் சிரமம்',
    },
    {
      'label': '🩺 Routine Check (Headache & Cough)',
      'lang': 'hi',
      'text': 'हल्का सिरदर्द है और दो दिन से हल्की खांसी है',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _stopListening();
    _pulseController.dispose();
    _textController.dispose();
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
              content: Text('Microphone speech recognition is not supported on this browser/device. Please type or use preset buttons.'),
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
      _voiceResult = null;
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
          _errorMessage = 'Microphone error: $e';
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

  Future<void> _processSymptoms() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please speak or type your symptoms first.')),
      );
      return;
    }

    if (_isListening) {
      await _stopListening();
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
        patientId: widget.patientId,
      );

      if (mounted) {
        setState(() {
          _voiceResult = result;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Could not process symptoms: $e';
        });
      }
    }
  }

  Future<void> _callEmergency() async {
    final uri = Uri(scheme: 'tel', path: '108');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _callHelpline() async {
    final uri = Uri(scheme: 'tel', path: AppConfig.helplineNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Health Check (आवाज़ जांच)'),
        backgroundColor: const Color(0xFF00695C),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome / Helper Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00695C), Color(0xFF00897B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.record_voice_over, color: Colors.white, size: 36),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Speak in your Voice (अपनी आवाज़ में बताएं)',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Talk about how you are feeling in Hindi, Telugu, Tamil, or English. SwasthyaSetu AI will detect your speech, check safety red-flags, and guide you.',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Language Selector Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.translate, color: Color(0xFF00695C), size: 20),
                        SizedBox(width: 8),
                        Text('Your Spoken Language:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                    DropdownButton<String>(
                      value: _selectedLanguage,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'auto', child: Text('🌐 Auto-Detect')),
                        DropdownMenuItem(value: 'hi', child: Text('🇮🇳 Hindi (हिंदी)')),
                        DropdownMenuItem(value: 'te', child: Text('🇮🇳 Telugu (తెలుగు)')),
                        DropdownMenuItem(value: 'ta', child: Text('🇮🇳 Tamil (தமிழ்)')),
                        DropdownMenuItem(value: 'en', child: Text('🇬🇧 English')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedLanguage = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Live Microphone Talking Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Tap the Microphone to Speak Symptoms',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isListening
                          ? (_speechStatus.isNotEmpty
                              ? '🔴 Listening (${_resolveLocaleId()}) • $_speechStatus'
                              : '🔴 Listening live in ${_resolveLocaleId()}... Speak now!')
                          : 'Tap microphone and tell what problems you are experiencing.',
                      style: TextStyle(
                        color: _isListening ? Colors.red.shade700 : Colors.grey.shade600,
                        fontWeight: _isListening ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Animated Mic Button
                    Center(
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _isListening ? _pulseAnimation.value : 1.0,
                            child: child,
                          );
                        },
                        child: Material(
                          color: _isListening ? Colors.red : const Color(0xFF00695C),
                          shape: const CircleBorder(),
                          elevation: _isListening ? 8 : 4,
                          shadowColor: _isListening ? Colors.red.shade300 : Colors.black26,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _toggleListening,
                            child: Padding(
                              padding: const EdgeInsets.all(22.0),
                              child: Icon(
                                _isListening ? Icons.mic : Icons.mic_none,
                                color: Colors.white,
                                size: 44,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Real-time Sound level wave indicator
                    if (_isListening) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (_soundLevel / 10.0).clamp(0.2, 1.0),
                          backgroundColor: Colors.red.shade100,
                          color: Colors.red,
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: _stopListening,
                        icon: const Icon(Icons.stop_circle, color: Colors.red),
                        label: const Text('Finish Speaking (रोकें)', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Detected Text Field
                    TextField(
                      controller: _textController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Detected Spoken Symptoms (बोले गए लक्षण)',
                        hintText: 'Your spoken words will appear here automatically...',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _textController.clear(),
                          tooltip: 'Clear',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Analyze Symptoms Button
                    ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _processSymptoms,
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.health_and_safety),
                      label: Text(
                        _isProcessing ? 'Analyzing Health Signals with AI...' : 'Check Symptoms (लक्षणों की जांच करें)',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00695C),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Quick Preset Chips for Easy Testing
            const Text(
              'Sample Voice Presets (Tap to Test Voice Symptoms):',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _quickPhrases.map((phrase) {
                return ActionChip(
                  avatar: const Icon(Icons.record_voice_over, size: 16, color: Color(0xFF00695C)),
                  label: Text(phrase['label']!, style: const TextStyle(fontSize: 12)),
                  backgroundColor: const Color(0xFFE0F2F1),
                  onPressed: () {
                    _textController.text = phrase['text']!;
                    setState(() => _selectedLanguage = phrase['lang']!);
                    _processSymptoms();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Error Display
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    ),
                  ],
                ),
              ),

            // Clinical Voice Result Display
            if (_voiceResult != null) _buildResultCard(_voiceResult!),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(ClinicalVoiceResult result) {
    final isEmergency = result.emergency.isEmergency;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Emergency Red Flag Banner
          if (isEmergency)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFB71C1C),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.redAccent, blurRadius: 8, offset: Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.white, size: 30),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '🚨 CRITICAL MEDICAL RED FLAG DETECTED',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Red Flag Category: ${result.emergency.redFlagType ?? "Acute Emergency"}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  if (result.emergency.matchedSymptom != null)
                    Text(
                      'Triggered by: ${result.emergency.matchedSymptom}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    'Please do not delay. Seek immediate medical emergency care or call emergency helpline services.',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _callEmergency,
                          icon: const Icon(Icons.emergency, color: Colors.red),
                          label: const Text('CALL 108 AMBULANCE', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.red.shade900,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _callHelpline,
                          icon: const Icon(Icons.phone, color: Colors.white),
                          label: const Text('Call Helpline', style: TextStyle(color: Colors.white)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Clinical Assessment Card
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Clinical Health Assessment',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isEmergency
                              ? Colors.red.shade100
                              : (result.triageLevel == 'HIGH' ? Colors.orange.shade100 : Colors.green.shade100),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isEmergency ? 'EMERGENCY' : (result.triageLevel ?? 'ROUTINE'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isEmergency
                                ? Colors.red.shade900
                                : (result.triageLevel == 'HIGH' ? Colors.orange.shade900 : Colors.green.shade900),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Detected Language & Translation
                  Text(
                    'Spoken Speech (${result.detectedLanguage.toUpperCase()}):',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(result.rawTranscript, style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),

                  if (result.translatedText != result.rawTranscript) ...[
                    const SizedBox(height: 8),
                    Text(
                      'English Translation (Pivot):',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(result.translatedText, style: const TextStyle(fontSize: 14)),
                  ],

                  const SizedBox(height: 14),

                  // Standardized Symptoms
                  const Text(
                    'Extracted Symptoms (पहचाने गए लक्षण):',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  if (result.standardizedSymptoms.isEmpty)
                    const Text('No specific clinical symptoms identified.', style: TextStyle(color: Colors.black54, fontSize: 13))
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: result.standardizedSymptoms.map((symptom) {
                        return Chip(
                          label: Text(symptom, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          backgroundColor: const Color(0xFFE0F2F1),
                          avatar: const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF00695C)),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 14),

                  // Suggested Action
                  if (result.suggestedAction != null && result.suggestedAction!.isNotEmpty) ...[
                    const Text(
                      'Recommended Care Action:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFF0D47A1), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              result.suggestedAction!,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF0D47A1), height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
