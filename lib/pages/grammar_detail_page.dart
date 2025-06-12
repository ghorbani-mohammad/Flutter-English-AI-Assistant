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
import '../services/auth_service.dart';
import '../services/chat_history_service.dart';
import 'chat_history_page.dart';
import '../models/chat_message.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_indicators.dart';
import '../models/chat_history.dart';

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
  final GlobalKey _inputKey = GlobalKey();
  
  // Audio waveforms controller
  final RecorderController _recorderController = RecorderController();
  
  // Auth service for JWT token
  final AuthService _authService = AuthService();
  
  // Chat history service for infinite scroll
  final ChatHistoryService _chatHistoryService = ChatHistoryService();
  
  bool _isRecording = false;
  bool _isLoading = false;
  String? _recordingPath;
  List<ChatMessage> _messages = [];
  WebSocketChannel? _webSocketChannel;
  bool _isGrammarScrollable = false;
  bool _isGrammarExpanded = true;
  
  // Infinite scroll state variables
  bool _isLoadingHistory = false;
  bool _hasMoreHistory = false;
  int _currentHistoryPage = 1;
  double _bottomPadding = 80.0; // Default padding
  List<ChatHistoryMessage> _historyMessages = [];
  bool _hasCheckedInitialHistory = false;

  @override
  void initState() {
    super.initState();
    _addSystemMessage();
    _checkGrammarScrollable();
    _initializeRecorder();
    _setupScrollListener();
    _checkForInitialHistory();
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

  Future<void> _cancelRecording() async {
    try {
      await _recorderController.stop();
      
      setState(() {
        _isRecording = false;
      });
      
      // Clean up the recording file if it exists
      if (_recordingPath != null) {
        final file = File(_recordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
        _recordingPath = null;
      }
    } catch (e) {
      _showErrorSnackBar('Failed to cancel recording: $e');
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
      
      // Add an initial empty response message
      setState(() {
        _messages.add(ChatMessage(
          text: '',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
      
      // Get JWT token for authentication
      final accessToken = await _authService.getAccessToken();
      final wsUrl = accessToken != null 
        ? 'wss://english-assistant.m-gh.com/chat/${widget.grammar.id}/?token=$accessToken'
        : 'wss://english-assistant.m-gh.com/chat/${widget.grammar.id}/';
      
      _webSocketChannel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
      );

      String currentResponse = '';
      
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
              // Update the last message with accumulated response
              if (_messages.isNotEmpty && !_messages.last.isUser) {
                _messages.last = ChatMessage(
                  text: currentResponse,
                  isUser: false,
                  timestamp: _messages.last.timestamp,
                );
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
      
      // Get JWT token for authentication
      final accessToken = await _authService.getAccessToken();
      final wsUrl = accessToken != null 
        ? 'wss://english-assistant.m-gh.com/chat/${widget.grammar.id}/?token=$accessToken'
        : 'wss://english-assistant.m-gh.com/chat/${widget.grammar.id}/';
      
      _webSocketChannel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
      );

      String currentResponse = '';
      bool hasReceivedTranscript = false;
      bool hasAddedResponseMessage = false;
      
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
                // Add the first response message when we start receiving AI response
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
          0,                                 // 👈 top of reversed list
          duration: const Duration(milliseconds: 250),
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

  void _setupScrollListener() {
    // No longer loading history on scroll
    // Simply monitor positioning for other UI needs if required
    _scrollController.addListener(() {
      // Empty listener maintained for potential future use
      // Auto-loading of history on scroll has been disabled
    });
  }

  Future<void> _loadMoreHistory() async {
    if (_isLoadingHistory) return;
    setState(() => _isLoadingHistory = true);

    try {
      // Always load from page 1 when button is clicked (no auto-incrementation on scroll)
      final response = await _chatHistoryService.getChatHistory(
          grammarId: widget.grammar.id,
          page: _currentHistoryPage,
          pageSize: 5);

      if (response.results.isNotEmpty) {
        // convert & APPEND (because reverse:true)
        final older = response.results      // oldest->newest
            .map(_toChatMessage)            // ChatHistory → ChatMessage
            .toList()
            .reversed                       // newest->oldest
            .toList();

        setState(() {
          // Remove the initial system message when loading history for the first time
          if (_currentHistoryPage == 1 && _messages.isNotEmpty && 
              !_messages[0].isUser && 
              _messages[0].text.startsWith('Hi! I\'m here to help you with')) {
            _messages.removeAt(0);
          }
          
          _messages.addAll(older);          // Add to the messages list
          _currentHistoryPage++;            // Increment page counter for next load
          _hasMoreHistory = response.next != null;  // Check if there are more messages
        });
      } else {
        setState(() => _hasMoreHistory = false);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load history: $e');
    } finally {
      setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _checkForInitialHistory() async {
    if (_hasCheckedInitialHistory) return;

    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final response = await _chatHistoryService.getChatHistory(
        grammarId: widget.grammar.id,
        page: 1,
        pageSize: 1, // Just check if there's any history
      );

      setState(() {
        _hasMoreHistory = response.results.isNotEmpty;
        _hasCheckedInitialHistory = true;
      });
    } catch (e) {
      // If there's an error, assume no history
      setState(() {
        _hasMoreHistory = false;
        _hasCheckedInitialHistory = true;
      });
    } finally {
      setState(() {
        _isLoadingHistory = false;
      });
    }
  }

  ChatMessage _toChatMessage(dynamic historyMessage) {
    return ChatMessage(
      text: historyMessage.displayContent,
      isUser: historyMessage.isUser,
      timestamp: historyMessage.createdAt,
      isVoice: historyMessage.isAudioMessage,
    );
  }

  void _updateBottomPadding() {
    final context = _inputKey.currentContext;
    if (context != null) {
      final size = context.size;
      final newPadding = (size?.height ?? 0);
      if (_bottomPadding != newPadding && newPadding > 0) {
        // Use a post-frame callback to avoid calling setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _bottomPadding = newPadding;
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _updateBottomPadding();
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
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatHistoryPage(
                    grammar: widget.grammar,
                  ),
                ),
              );
            },
            tooltip: 'Chat History',
          ),
        ],
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
                        // Scroll to top of reversed list after collapsing/expanding
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_scrollController.hasClients) {
                            _scrollController.animateTo(
                              0.0,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            );
                          }
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
                      primary: false,
                      reverse: true,                         // 👈 important
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(16, _isGrammarExpanded ? 8 : 0, 16, _bottomPadding),
                      itemCount: _messages.length +
                          ((_hasMoreHistory && _hasCheckedInitialHistory) ? 1 : 0),
                      itemBuilder: (context, index) {
                        // The button/indicator is at the "end" of the list (top of the screen).
                        if (index >= _messages.length) {
                          if (_isLoadingHistory) {
                            return const HistoryLoadingIndicator();
                          }
                          if (_hasMoreHistory && _hasCheckedInitialHistory) {
                            return LoadPreviousChatIndicator(
                              isLoading: false,
                              onTap: _loadMoreHistory,
                            );
                          }
                          return const SizedBox.shrink(); // Should not happen
                        }
                        
                        // because the list is reversed we show newest->oldest = end->start
                        final message = _messages[_messages.length - 1 - index];

                        // -----------------------------------------
                        // 2. give each bubble a stable ValueKey
                        //    (timestamp or server id – anything unique & immutable)
                        // -----------------------------------------
                        return KeyedSubtree(
                          key: ValueKey(message.timestamp.millisecondsSinceEpoch),
                          child: MessageBubble(message: message),
                        );
                      },
                    ),
                  ),
                  
                  // Input section
                  Container(
                    key: _inputKey,
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
                            // Recording/Cancel button
                            GestureDetector(
                              onTap: _isRecording ? _cancelRecording : _startRecording,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: _isRecording ? 50 : 50,
                                height: _isRecording ? 50 : 50,
                                decoration: BoxDecoration(
                                  color: _isRecording ? Colors.red : Colors.deepPurple,
                                  shape: BoxShape.circle,
                                  boxShadow: _isRecording ? [
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.4),
                                      spreadRadius: 3,
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.2),
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
                                  _isRecording ? Icons.close : Icons.mic,
                                  color: Colors.white,
                                  size: _isRecording ? 24 : 24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Send button (changes to green when recording)
                            GestureDetector(
                              onTap: _isRecording ? _stopRecording : _sendTextMessage,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: _isRecording ? 60 : 50,
                                height: _isRecording ? 60 : 50,
                                decoration: BoxDecoration(
                                  color: _isRecording ? Colors.green : Colors.deepPurple,
                                  shape: BoxShape.circle,
                                  boxShadow: _isRecording ? [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.4),
                                      spreadRadius: 3,
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.2),
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
                                  Icons.send,
                                  color: Colors.white,
                                  size: _isRecording ? 30 : 24,
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
} 