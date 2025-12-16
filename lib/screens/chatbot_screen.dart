import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final List<_Message> _messages = [
    _Message(text: 'Welcome to Ask AI. How can I help?', isAi: true),
  ];
  final TextEditingController _input = TextEditingController();

  void _send() {
    final t = _input.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _messages.add(_Message(text: t, isAi: false));
    });
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ask AI', style: GoogleFonts.roboto(color: const Color(0xFF1A1A1A))),
        backgroundColor: const Color(0xFFFAF7F0),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFFAF7F0),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                return Align(
                  alignment: m.isAi ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: m.isAi ? const Color(0xFFEBE7DD) : const Color(0xFFCDDC39).withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1A1A1A).withOpacity(0.12), width: 1.0),
                    ),
                    child: Text(
                      m.text,
                      style: GoogleFonts.roboto(fontSize: 12, color: const Color(0xFF1A1A1A)),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            bottom: true,
            minimum: const EdgeInsets.only(bottom: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F0),
                border: Border(top: BorderSide(color: const Color(0xFF1A1A1A).withOpacity(0.12), width: 1.0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      decoration: InputDecoration(
                        hintText: 'Type a message',
                        hintStyle: GoogleFonts.roboto(fontSize: 12, color: const Color(0xFF6B7280)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        filled: true,
                        fillColor: const Color(0xFFFAF7F0),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: const Color(0xFF1A1A1A).withOpacity(0.15), width: 1.0),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          borderSide: BorderSide(color: Color(0xFFCDDC39), width: 1.2),
                        ),
                      ),
                      style: GoogleFonts.roboto(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _send,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCDDC39),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Send', style: GoogleFonts.roboto(fontSize: 12, color: const Color(0xFF1A1A1A), fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message {
  final String text;
  final bool isAi;
  const _Message({required this.text, required this.isAi});
}
