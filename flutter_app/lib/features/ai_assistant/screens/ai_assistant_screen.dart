// lib/features/ai_assistant/screens/ai_assistant_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:crisis_response_app/core/theme/app_theme.dart';

class _Message {
  final String text;
  final bool isUser;
  final DateTime time;
  final String? action;
  const _Message({required this.text, required this.isUser, required this.time, this.action});
}

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _stt = SpeechToText();
  final _tts = FlutterTts();

  final List<_Message> _messages = [];
  bool _isListening = false;
  bool _isThinking = false;
  bool _ttsEnabled = true;
  bool _sttAvailable = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
    _addWelcome();
  }

  Future<void> _initSpeech() async {
    _sttAvailable = await _stt.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-IN');
    await _tts.setSpeechRate(0.9);
    await _tts.setPitch(1.0);
  }

  void _addWelcome() {
    _messages.add(_Message(
      text: "Hello! I'm your Crisis Response AI assistant. I can help you with:\n\n• Nearest shelters & hospitals\n• Emergency contact numbers\n• Safety guidelines for specific disasters\n• Resource availability in your area\n\nHow can I assist you right now?",
      isUser: false,
      time: DateTime.now(),
    ));
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    _textCtrl.clear();

    setState(() {
      _messages.add(_Message(text: text, isUser: true, time: DateTime.now()));
      _isThinking = true;
    });
    _scrollToBottom();

    // Short delay to simulate thinking
    await Future.delayed(const Duration(milliseconds: 800));

    final answer = _localRag(text);
    final action = _getActionFor(text, answer);
    if (mounted) {
      setState(() {
        _messages.add(_Message(text: answer, isUser: false, time: DateTime.now(), action: action));
        _isThinking = false;
      });
      _scrollToBottom();
      if (_ttsEnabled) _tts.speak(answer);
    }
  }

  String? _getActionFor(String query, String answer) {
    if (query.toLowerCase().contains('rescue') || query.toLowerCase().contains('boat') || query.toLowerCase().contains('food')) {
      return 'REQUEST_HELP';
    }
    if (query.toLowerCase().contains('shelter') || query.toLowerCase().contains('hospital')) {
      return 'VIEW_MAP';
    }
    return null;
  }

  // Basic local RAG — keyword matching with cached knowledge
  String _localRag(String query) {
    final q = query.toLowerCase();
    if (q.contains('shelter') || q.contains('safe place')) {
      return "Nearest shelters in Chennai:\n\n1. Nehru Indoor Stadium — ICF (Cap: 2000)\n2. YMCA Grounds Nandanam (Cap: 500)\n3. DRJ Convention Centre, Teynampet\n\nAll shelters are currently open. Tap the Map tab to navigate there.";
    }
    if (q.contains('hospital') || q.contains('medical') || q.contains('doctor')) {
      return "Nearest hospitals:\n\n1. Rajiv Gandhi Govt. Hospital — 044-25305000\n2. Stanley Hospital — 044-25281361\n3. Apollo Hospitals — 1860-500-1066\n\nFor emergencies, call 108 for a free ambulance.";
    }
    if (q.contains('flood')) {
      return "Flood safety guidelines:\n\n• Move to highest ground immediately\n• Avoid walking through moving water\n• Call NDRF: 011-24363260\n• Disaster Management: 1078\n• Request boat rescue through the app\n\nDo you want me to submit a rescue request for you?";
    }
    if (q.contains('cyclone') || q.contains('storm')) {
      return "Cyclone preparedness:\n\n• Stay indoors, away from windows\n• Store 3 days of water and food\n• Charge all devices now\n• IMD Cyclone alerts: 044-28131000\n• Monitor IMD: mausam.imd.gov.in";
    }
    if (q.contains('contact') || q.contains('number') || q.contains('call')) {
      return "Key emergency numbers:\n\n• Police: 100\n• Ambulance: 108\n• Fire: 101\n• Women's Helpline: 1091\n• Disaster Mgmt: 1078\n• NDRF: 011-24363260\n• Coast Guard: 1554\n• National Emergency: 112";
    }
    if (q.contains('food') || q.contains('water') || q.contains('resource')) {
      return "To request emergency resources:\n\n1. Tap the 'Request Help' button on Home\n2. Select Food / Water / Shelter\n3. Your location is auto-attached\n4. Submit — our team responds within 30 minutes\n\nAlternatively, relief camps are active at:\n• Kilpauk Medical College\n• Corporation School, Adyar";
    }
    if (q.contains('earthquake')) {
      return "Earthquake safety:\n\nDURING: Drop → Cover → Hold On\n• Get under sturdy table/desk\n• Away from windows/heavy objects\n\nAFTER:\n• Expect aftershocks\n• Check for gas leaks\n• Don't use elevators\n• Call 1078 for rescue";
    }
    return "I'm here to help during the crisis. You can ask me about:\n\n• Nearest shelters or hospitals\n• Emergency helpline numbers\n• Safety tips for specific disasters\n• How to request food, water or rescue\n\nTry asking: \"Where is the nearest shelter?\" or \"Flood safety tips\"";
  }

  Future<void> _toggleListening() async {
    if (!_sttAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone not available')));
      return;
    }

    if (_isListening) {
      await _stt.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      await _stt.listen(
        onResult: (result) {
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            _send(result.recognizedWords);
            setState(() => _isListening = false);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
        localeId: 'en_IN',
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _stt.stop();
    _tts.stop();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: const Row(
          children: [
            Icon(Icons.smart_toy_outlined, color: AppColors.accentGreen, size: 20),
            SizedBox(width: 8),
            Text('AI Crisis Assistant'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_ttsEnabled ? Icons.volume_up : Icons.volume_off, color: _ttsEnabled ? AppColors.accentGreen : AppColors.textMuted),
            onPressed: () {
              setState(() => _ttsEnabled = !_ttsEnabled);
              if (!_ttsEnabled) _tts.stop();
            },
            tooltip: 'Toggle voice output',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.surface,
            child: Row(
              children: [
                Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.safe, shape: BoxShape.circle)),
                const SizedBox(width: 7),
                const Text('Online • Using local crisis knowledge base', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isThinking ? 1 : 0),
              itemBuilder: (_, i) {
                if (_isThinking && i == _messages.length) return const _ThinkingBubble();
                return _MessageBubble(message: _messages[i]);
              },
            ),
          ),

          // Listening indicator
          if (_isListening)
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.mic, color: AppColors.accent, size: 16),
                  const SizedBox(width: 8),
                  const Text('Listening...', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(width: 12),
                  _WaveformIndicator(),
                ],
              ),
            ),

          // Quick suggestion chips
          if (_messages.length <= 2)
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _SuggestionChip('Nearest shelter', onTap: () => _send('Where is the nearest shelter?')),
                    const SizedBox(width: 8),
                    _SuggestionChip('Flood safety', onTap: () => _send('Flood safety tips')),
                    const SizedBox(width: 8),
                    _SuggestionChip('Emergency numbers', onTap: () => _send('Key emergency contact numbers')),
                    const SizedBox(width: 8),
                    _SuggestionChip('Request food', onTap: () => _send('How do I request food and water?')),
                  ],
                ),
              ),
            ),

          // Input bar
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: Row(
              children: [
                // Mic button
                GestureDetector(
                  onTap: _toggleListening,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _isListening ? AppColors.accent : AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _isListening ? AppColors.accent : AppColors.divider),
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? Colors.white : AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Text field
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Ask anything about the crisis...',
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: _send,
                    textInputAction: TextInputAction.send,
                  ),
                ),

                const SizedBox(width: 8),

                // Send button
                GestureDetector(
                  onTap: () => _send(_textCtrl.text),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _Message message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.accentGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accentGreen.withOpacity(0.4)),
              ),
              child: const Icon(Icons.smart_toy_outlined, color: AppColors.accentGreen, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? AppColors.accent : AppColors.card,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser ? null : Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isUser ? Colors.white : AppColors.textPrimary,
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  ),
                  if (message.action != null && !isUser) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Icon(
                          message.action == 'REQUEST_HELP' ? Icons.sos : Icons.map_outlined,
                          size: 14,
                        ),
                        label: Text(
                          message.action == 'REQUEST_HELP' ? 'REQUEST HELP NOW' : 'VIEW ON MAP',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: message.action == 'REQUEST_HELP' ? AppColors.critical : AppColors.accentGreen,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          if (message.action == 'REQUEST_HELP') {
                            context.push('/home/request-help');
                          } else {
                            // Logic to switch to map tab
                            // Since we are in Home, we navigate there
                            context.go('/map');
                          }
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble();

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(color: AppColors.accentGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.accentGreen.withOpacity(0.4))),
            child: const Icon(Icons.smart_toy_outlined, color: AppColors.accentGreen, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(16), bottomLeft: Radius.circular(4)), border: Border.all(color: AppColors.divider)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) => AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) => Container(
                  margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withOpacity(i == 0 ? _ctrl.value : i == 1 ? 0.5 + _ctrl.value * 0.5 : 1 - _ctrl.value),
                    shape: BoxShape.circle,
                  ),
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveformIndicator extends StatefulWidget {
  @override
  State<_WaveformIndicator> createState() => _WaveformIndicatorState();
}

class _WaveformIndicatorState extends State<_WaveformIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        children: List.generate(5, (i) {
          final h = 4.0 + (i % 3 == 0 ? _ctrl.value * 12 : i % 3 == 1 ? (1 - _ctrl.value) * 12 : 6);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            width: 3,
            height: h,
            decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2)),
          );
        }),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SuggestionChip(this.label, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
      ),
    );
  }
}
