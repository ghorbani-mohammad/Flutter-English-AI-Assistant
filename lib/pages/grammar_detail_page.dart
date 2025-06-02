import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import '../models/grammar.dart';
import '../services/ai_service.dart';

class GrammarDetailPage extends StatefulWidget {
  final Grammar grammar;

  const GrammarDetailPage({
    super.key,
    required this.grammar,
  });

  @override
  State<GrammarDetailPage> createState() => _GrammarDetailPageState();
}

class _GrammarDetailPageState extends State<GrammarDetailPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _grammarScrollController = ScrollController();
  
  // Audio waveforms controller
  final RecorderController _recorderController = RecorderController();
  
  bool _isRecording = false;
  bool _isLoading = false;
  String? _recordingPath;
  List<ChatMessage> _messages = [];
  WebSocketChannel? _webSocketChannel;
  bool _isGrammarScrollable = false;
  bool _isGrammarExpanded = true;

  @override
  void initState() {
    super.initState();
    _addSystemMessage();
    _checkGrammarScrollable();
    _initializeRecorder();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _grammarScrollController.dispose();
    _recorderController.dispose();
    _webSocketChannel?.sink.close();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recheck scrollability when dependencies change (like screen rotation)
    _checkGrammarScrollable();
  }

  void _addSystemMessage() {
    setState(() {
      _messages.add(ChatMessage(
        text: 'Hi! I\'m here to help you with "${widget.grammar.title}". You can ask me questions about this grammar topic using text or voice. How can I assist you?',
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
  }

  Future<void> _initializeRecorder() async {
    await _recorderController.checkPermission();
  }

  Future<void> _startRecording() async {
    try {
      if (_recorderController.hasPermission) {
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _recorderController.record(path: path);
        
        setState(() {
          _isRecording = true;
          _recordingPath = path;
        });
      } else {
        await _recorderController.checkPermission();
        if (_recorderController.hasPermission) {
          await _startRecording();
        } else {
          _showErrorSnackBar('Microphone permission is required');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorderController.stop();
      
      setState(() {
        _isRecording = false;
      });
      
      if (path != null) {
        await _sendVoiceMessage(path);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to stop recording: $e');
    }
  }

  Future<void> _sendTextMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _textController.clear();
    _scrollToBottom();

    try {
      await _connectTextWebSocket();
      await _sendTextToWebSocket(text);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to send message: $e');
    }
  }

  Future<void> _connectTextWebSocket() async {
    try {
      // Close existing connection if any
      _webSocketChannel?.sink.close();
      
      _webSocketChannel = WebSocketChannel.connect(
        Uri.parse('wss://english-assistant.m-gh.com/chat/${widget.grammar.id}/'),
      );

      String currentResponse = '';
      bool hasAddedResponseMessage = false;
      
      _webSocketChannel!.stream.listen(
        (data) {
          final response = json.decode(data);
          
          if (response['error'] == false && response['message'] == 'completed.') {
            // Final completion message - just stop loading
            setState(() {
              _isLoading = false;
            });
          } else if (response['error'] == false && response['message'] != null) {
            // Streaming response - accumulate the text
            currentResponse += response['message'];
            
            setState(() {
              if (!hasAddedResponseMessage) {
                // Add the first response message
                _messages.add(ChatMessage(
                  text: currentResponse,
                  isUser: false,
                  timestamp: DateTime.now(),
                ));
                hasAddedResponseMessage = true;
              } else {
                // Update the last message with accumulated response
                if (_messages.isNotEmpty && !_messages.last.isUser) {
                  _messages.last = ChatMessage(
                    text: currentResponse,
                    isUser: false,
                    timestamp: _messages.last.timestamp,
                  );
                }
              }
            });
            _scrollToBottom();
          }
        },
        onError: (error) {
          setState(() {
            _isLoading = false;
          });
          _showErrorSnackBar('WebSocket error: $error');
        },
        onDone: () {
          setState(() {
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      throw Exception('Failed to connect to WebSocket: $e');
    }
  }

  Future<void> _sendTextToWebSocket(String message) async {
    try {
      _webSocketChannel!.sink.add(json.encode({
        'data': message,
      }));
    } catch (e) {
      throw Exception('Failed to send message to WebSocket: $e');
    }
  }

  Future<void> _sendVoiceMessage(String audioPath) async {
    setState(() {
      _messages.add(ChatMessage(
        text: '🎤 Voice message',
        isUser: true,
        timestamp: DateTime.now(),
        isVoice: true,
      ));
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      await _connectVoiceWebSocket();
      await _sendAudioToWebSocket(audioPath);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to send voice message: $e');
    }
  }

  Future<void> _connectVoiceWebSocket() async {
    try {
      // Close existing connection if any
      _webSocketChannel?.sink.close();
      
      _webSocketChannel = WebSocketChannel.connect(
        Uri.parse('wss://english-assistant.m-gh.com/chat/${widget.grammar.id}/'),
      );

      String currentResponse = '';
      bool hasAddedResponseMessage = false;
      bool hasReceivedTranscript = false;
      
      _webSocketChannel!.stream.listen(
        (data) {
          final response = json.decode(data);
          
          // Handle audio transcript first
          if (response['error'] == false && response['audio_text'] != null && !hasReceivedTranscript) {
            hasReceivedTranscript = true;
            setState(() {
              // Update the last voice message with the transcript
              if (_messages.isNotEmpty && _messages.last.isUser && _messages.last.isVoice) {
                _messages[_messages.length - 1] = ChatMessage(
                  text: response['audio_text'],
                  isUser: true,
                  timestamp: _messages.last.timestamp,
                  isVoice: true,
                );
              }
            });
          } else if (response['error'] == false && response['message'] == 'completed.') {
            // Final completion message - just stop loading
            setState(() {
              _isLoading = false;
            });
          } else if (response['error'] == false && response['message'] != null) {
            // Streaming response - accumulate the text
            currentResponse += response['message'];
            
            setState(() {
              if (!hasAddedResponseMessage) {
                // Add the first response message
                _messages.add(ChatMessage(
                  text: currentResponse,
                  isUser: false,
                  timestamp: DateTime.now(),
                ));
                hasAddedResponseMessage = true;
              } else {
                // Update the last message with accumulated response
                if (_messages.isNotEmpty && !_messages.last.isUser) {
                  _messages.last = ChatMessage(
                    text: currentResponse,
                    isUser: false,
                    timestamp: _messages.last.timestamp,
                  );
                }
              }
            });
            _scrollToBottom();
          }
        },
        onError: (error) {
          setState(() {
            _isLoading = false;
          });
          _showErrorSnackBar('WebSocket error: $error');
        },
        onDone: () {
          setState(() {
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      throw Exception('Failed to connect to WebSocket: $e');
    }
  }

  Future<void> _sendAudioToWebSocket(String audioPath) async {
    try {
      final file = File(audioPath);
      final audioBytes = await file.readAsBytes();
      
      _webSocketChannel!.sink.add(json.encode({
        'audio': 'data:audio/wav;base64,${base64Encode(audioBytes)}',
      }));
    } catch (e) {
      throw Exception('Failed to send audio to WebSocket: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToBottomOnKeyboard() {
    // Additional scroll when keyboard appears
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _checkGrammarScrollable() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_grammarScrollController.hasClients) {
        setState(() {
          _isGrammarScrollable = _grammarScrollController.position.maxScrollExtent > 0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          'Grammar #${widget.grammar.id}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Grammar content section
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              constraints: BoxConstraints(
                maxHeight: _isGrammarExpanded 
                    ? MediaQuery.of(context).size.height * 0.4 
                    : 80, // Collapsed height
              ),
              decoration: const BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Stack(
                children: [
                  if (_isGrammarExpanded)
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      controller: _grammarScrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 40), // Space for collapse button
                          Text(
                            widget.grammar.title,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.grammar.description.replaceAll(RegExp(r'\\r\\n|\r\n'), '\n'),
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 16,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Created: ${_formatDate(widget.grammar.createdAt)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    // Collapsed view
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                      child: Text(
                        widget.grammar.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  
                  // Expand/Collapse button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isGrammarExpanded = !_isGrammarExpanded;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          _isGrammarExpanded ? Icons.expand_less : Icons.expand_more,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  
                  // Scroll indicator for long content (only when expanded)
                  if (_isGrammarScrollable && _isGrammarExpanded)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.swipe_vertical,
                              size: 12,
                              color: Colors.white.withOpacity(0.7),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Scroll',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Chat section
            Expanded(
              child: Column(
                children: [
                  // Chat messages
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      itemCount: _messages.length + (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length && _isLoading) {
                          return _buildLoadingMessage();
                        }
                        
                        final message = _messages[index];
                        return _buildMessageBubble(message);
                      },
                    ),
                  ),
                  
                  // Input section
                  Container(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                      bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 16 : 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Waveform display when recording
                        if (_isRecording) ...[
                          Container(
                            width: double.infinity,
                            height: 80,
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.deepPurple.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurple,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.deepPurple.withOpacity(0.3),
                                            spreadRadius: 2,
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Recording...',
                                      style: TextStyle(
                                        color: Colors.deepPurple,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Bottom waveform (flipped)
                                      Transform(
                                        alignment: Alignment.center,
                                        transform: Matrix4.rotationX(3.14159), // Flip vertically
                                        child: AudioWaveforms(
                                          recorderController: _recorderController,
                                          size: Size(double.infinity, 20),
                                          waveStyle: WaveStyle(
                                            waveColor: Colors.deepPurple.withOpacity(0.8),
                                            extendWaveform: true,
                                            showMiddleLine: false,
                                            waveThickness: 2.0,
                                            spacing: 3,
                                            scaleFactor: 25.0,
                                          ),
                                        ),
                                      ),
                                      // Top waveform (normal)
                                      AudioWaveforms(
                                        recorderController: _recorderController,
                                        size: Size(double.infinity, 20),
                                        waveStyle: WaveStyle(
                                          waveColor: Colors.deepPurple,
                                          extendWaveform: true,
                                          showMiddleLine: false,
                                          waveThickness: 2.0,
                                          spacing: 3,
                                          scaleFactor: 25.0,
                                        ),
                                      ),
                                      // Center line
                                      Container(
                                        height: 1,
                                        width: double.infinity,
                                        color: Colors.deepPurple.withOpacity(0.3),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _textController,
                                onTap: _scrollToBottomOnKeyboard,
                                decoration: InputDecoration(
                                  hintText: 'Ask about this grammar topic...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(25),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                ),
                                maxLines: null,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _sendTextMessage(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Recording button with waveform feedback
                            GestureDetector(
                              onTap: _isRecording ? _stopRecording : _startRecording,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: _isRecording ? 60 : 50,
                                height: _isRecording ? 60 : 50,
                                decoration: BoxDecoration(
                                  color: _isRecording ? const Color(0xFFE91E63) : Colors.deepPurple,
                                  shape: BoxShape.circle,
                                  boxShadow: _isRecording ? [
                                    BoxShadow(
                                      color: const Color(0xFFE91E63).withOpacity(0.4),
                                      spreadRadius: 3,
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                    BoxShadow(
                                      color: Colors.deepPurple.withOpacity(0.2),
                                      spreadRadius: 1,
                                      blurRadius: 6,
                                      offset: const Offset(0, 1),
                                    ),
                                  ] : [
                                    BoxShadow(
                                      color: Colors.deepPurple.withOpacity(0.3),
                                      spreadRadius: 1,
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _isRecording ? Icons.stop : Icons.mic,
                                  color: Colors.white,
                                  size: _isRecording ? 30 : 24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _sendTextMessage,
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: const BoxDecoration(
                                  color: Colors.deepPurple,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.send,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.deepPurple,
              child: const Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser ? Colors.deepPurple : Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.isVoice)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.mic,
                              size: 16,
                              color: message.isUser ? Colors.white : Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Voice message',
                              style: TextStyle(
                                color: message.isUser ? Colors.white70 : Colors.grey[500],
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                        if (message.text != '🎤 Voice message') ...[
                          const SizedBox(height: 4),
                          Text(
                            message.text,
                            style: TextStyle(
                              color: message.isUser ? Colors.white : Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ],
                    )
                  else
                    Text(
                      message.text,
                      style: TextStyle(
                        color: message.isUser ? Colors.white : Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: message.isUser ? Colors.white70 : Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: Icon(
                Icons.person,
                color: Colors.grey[600],
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.deepPurple,
            child: const Icon(
              Icons.smart_toy,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Thinking...',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
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

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isVoice;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isVoice = false,
  });
} 