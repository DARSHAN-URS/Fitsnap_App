import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../models/chat_message.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

class ChatScreen extends StatefulWidget {
  final int? mealId;
  const ChatScreen({super.key, this.mealId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late stt.SpeechToText _speech;
  late FlutterTts _tts;
  bool _isListening = false;
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _initTts();
  }

  void _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.0);
  }

  void _speak(String text) async {
    await _tts.speak(text);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    
    // Auto-scroll when messages update
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        toolbarHeight: 70,
        title: Row(
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFF5E3A).withOpacity(0.5), width: 1.5),
                  ),
                  child: const CircleAvatar(
                    radius: 20,
                    backgroundColor: Color(0xFF1E293B),
                    child: Icon(Icons.psychology_rounded, color: Color(0xFFFF5E3A), size: 24),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF1E293B), width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('FitSnap AI', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white, letterSpacing: -0.5)),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5E3A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('PREFERRED ADVISOR', style: TextStyle(color: Color(0xFFFF5E3A), fontSize: 9, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 6),
                    const Text('Online', style: TextStyle(color: Colors.blueGrey, fontSize: 11, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 4),
                    const Text('• Powered by Gemini', style: TextStyle(color: Colors.blueGrey, fontSize: 10, fontWeight: FontWeight.w400)),
                  ],
                ),
              ],
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.blueGrey),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0F172A),
              const Color(0xFF0F172A).withOpacity(0.8),
              const Color(0xFF1E293B).withOpacity(0.5),
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: chatProvider.messages.isEmpty
                  ? _buildWelcomeState(chatProvider)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      itemCount: chatProvider.messages.length + (chatProvider.isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == chatProvider.messages.length) {
                          return _buildTypingIndicator();
                        }
                        final msg = chatProvider.messages[index];
                        // Speak ONLY the last AI message if it just arrived
                        if (index == chatProvider.messages.length - 1 && msg.role == 'assistant' && !chatProvider.isLoading) {
                           _speak(msg.content);
                        }
                        return _buildMessageBubble(msg);
                      },
                    ),
            ),
            _buildInputArea(chatProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('AI is thinking', style: TextStyle(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(width: 8),
            _buildDot(0),
            _buildDot(1),
            _buildDot(2),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      width: 4,
      height: 4,
      decoration: const BoxDecoration(color: Color(0xFFFF5E3A), shape: BoxShape.circle),
    );
  }

  Widget _buildWelcomeState(ChatProvider chatProvider) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFFFF5E3A).withOpacity(0.2), const Color(0xFFFF5E3A).withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFF5E3A).withOpacity(0.2), width: 2),
              ),
              child: const Icon(Icons.auto_awesome_rounded, size: 60, color: Color(0xFFFF5E3A)),
            ),
            const SizedBox(height: 32),
            const Text(
              'Preferred Health Advisor',
              style: TextStyle(
                fontSize: 28, 
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                color: Colors.white,
                height: 1.1
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Your elite intelligence for nutrition, workouts, and real-time health analysis.',
              style: TextStyle(color: Colors.blueGrey[300], fontSize: 15, fontWeight: FontWeight.w400),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            Wrap(
              spacing: 8,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _buildQuickPrompt('How do I log a meal?', chatProvider),
                _buildQuickPrompt('Analyze my daily progress', chatProvider),
                _buildQuickPrompt('Optimal dinner suggestions', chatProvider),
                _buildQuickPrompt('Log hydration habit', chatProvider),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPrompt(String text, ChatProvider provider) {
    return InkWell(
      onTap: () {
        _controller.text = text;
        _handleSend(provider);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF1E293B),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
          ]
        ),
        child: Text(
          text,
          style: TextStyle(color: Colors.blueGrey[100], fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMsg msg) {
    bool isUser = msg.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFFFF5E3A) : const Color(0xFF1E293B),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isUser ? 0.2 : 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4)
                  )
                ]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.content, 
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.blueGrey[50], 
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: isUser ? FontWeight.w500 : FontWeight.w400
                    )
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                DateFormat('hh:mm a').format(msg.createdAt),
                style: TextStyle(color: Colors.blueGrey[600], fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(ChatProvider provider) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withOpacity(0.9),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
          ),
          child: Column(
            children: [
              if (_selectedImage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Stack(
                    children: [
                      Container(
                        height: 60,
                        width: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover),
                          border: Border.all(color: const Color(0xFFFF5E3A), width: 2),
                        ),
                      ),
                      Positioned(
                        top: -5,
                        right: -5,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedImage = null),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  _buildIconButton(Icons.add_a_photo_rounded, _pickImage),
                  const SizedBox(width: 10),
                  _buildIconButton(
                    _isListening ? Icons.mic_rounded : Icons.mic_none_rounded, 
                    _toggleListening,
                    isActive: _isListening
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: _isListening ? 'Listening...' : 'Type a message...',
                          hintStyle: TextStyle(color: _isListening ? const Color(0xFFFF5E3A) : Colors.blueGrey[600]),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _handleSend(provider),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _handleSend(provider),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF5E3A), Color(0xFFFF8E3A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Color(0xFFFF5E3A), blurRadius: 8, offset: Offset(0, 3), spreadRadius: -2)
                        ]
                      ),
                      child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap, {bool isActive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFFF5E3A).withOpacity(0.2) : const Color(0xFF0F172A),
          shape: BoxShape.circle,
          border: Border.all(color: isActive ? const Color(0xFFFF5E3A) : Colors.white.withOpacity(0.05)),
        ),
        child: Icon(icon, color: isActive ? const Color(0xFFFF5E3A) : Colors.blueGrey, size: 20),
      ),
    );
  }

  void _toggleListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _controller.text = val.recognizedWords;
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _selectedImage = File(image.path));
    }
  }

  void _handleSend(ChatProvider provider) async {
    String? imageBase64;
    if (_selectedImage != null) {
      final bytes = await _selectedImage!.readAsBytes();
      imageBase64 = base64Encode(bytes);
    }

    if (_controller.text.trim().isNotEmpty || imageBase64 != null) {
      provider.sendMessage(
        _controller.text.trim(), 
        mealId: widget.mealId,
        imageBase64: imageBase64
      );
      _controller.clear();
      setState(() => _selectedImage = null);
    }
  }
}
