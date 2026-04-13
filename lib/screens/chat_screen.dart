import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../models/chat_message.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final int? mealId;
  const ChatScreen({super.key, this.mealId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nutrition Assistant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Always online', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: chatProvider.messages.isEmpty
                ? _buildWelcomeState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: chatProvider.messages.length,
                    itemBuilder: (context, index) {
                      final msg = chatProvider.messages[index];
                      return _buildMessageBubble(msg);
                    },
                  ),
          ),
          if (chatProvider.isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF5E3A)),
              ),
            ),
          _buildInputArea(chatProvider),
        ],
      ),
    );
  }

  Widget _buildWelcomeState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5E3A).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.psychology_rounded, size: 60, color: Color(0xFFFF5E3A)),
            ),
            const SizedBox(height: 24),
            const Text(
              'How can I help you today?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Ask me about your calories, macro balance, or to correct a meal log.',
              style: TextStyle(color: Colors.blueGrey[400]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMsg msg) {
    bool isUser = msg.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFFFF5E3A) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg.content, style: const TextStyle(color: Colors.white, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(msg.createdAt),
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(ChatProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Ask anything...',
                  hintStyle: TextStyle(color: Colors.blueGrey),
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
                color: Color(0xFFFF5E3A),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSend(ChatProvider provider) {
    if (_controller.text.trim().isNotEmpty) {
      provider.sendMessage(_controller.text, mealId: widget.mealId);
      _controller.clear();
    }
  }
}
