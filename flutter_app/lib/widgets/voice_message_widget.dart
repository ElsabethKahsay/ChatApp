import 'dart:async';
import 'package:flutter/material.dart';
import '../services/voice_message_service.dart';

/// Widget for recording voice messages
class VoiceRecorderWidget extends StatefulWidget {
  final Function(String filePath, Duration duration) onRecordingComplete;
  final VoidCallback? onCancel;

  const VoiceRecorderWidget({
    super.key,
    required this.onRecordingComplete,
    this.onCancel,
  });

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget> {
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _durationTimer;

  @override
  void dispose() {
    _durationTimer?.cancel();
    if (_isRecording) {
      VoiceMessageService.cancelRecording();
    }
    super.dispose();
  }

  Future<void> _startRecording() async {
    final path = await VoiceMessageService.startRecording();
    if (path != null) {
      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });
      
      // Start duration timer
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration += const Duration(seconds: 1);
        });
      });
    }
  }

  Future<void> _stopRecording() async {
    _durationTimer?.cancel();
    final path = await VoiceMessageService.stopRecording();
    
    setState(() {
      _isRecording = false;
    });
    
    if (path != null && _recordingDuration.inSeconds > 1) {
      widget.onRecordingComplete(path, _recordingDuration);
    } else {
      widget.onCancel?.call();
    }
  }

  Future<void> _cancelRecording() async {
    _durationTimer?.cancel();
    await VoiceMessageService.cancelRecording();
    
    setState(() {
      _isRecording = false;
      _recordingDuration = Duration.zero;
    });
    
    widget.onCancel?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_isRecording) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Recording indicator
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            // Duration
            Text(
              VoiceMessageService.formatDuration(_recordingDuration),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(width: 16),
            // Cancel button
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: _cancelRecording,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            // Send button
            GestureDetector(
              onTap: _stopRecording,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      );
    }

    // Recording button
    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressEnd: (_) => _stopRecording(),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.mic, color: Colors.grey),
      ),
    );
  }
}

/// Widget for playing voice messages
class VoicePlayerWidget extends StatefulWidget {
  final String filePath;
  final bool isMe;
  final Color? backgroundColor;

  const VoicePlayerWidget({
    super.key,
    required this.filePath,
    required this.isMe,
    this.backgroundColor,
  });

  @override
  State<VoicePlayerWidget> createState() => _VoicePlayerWidgetState();
}

class _VoicePlayerWidgetState extends State<VoicePlayerWidget> {
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _stateSubscription;

  @override
  void initState() {
    super.initState();
    _loadDuration();
    _subscribeToStreams();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _stateSubscription?.cancel();
    
    // Stop playback if this is the currently playing message
    if (VoiceMessageService.currentlyPlayingPath == widget.filePath) {
      VoiceMessageService.stopPlayback();
    }
    
    super.dispose();
  }

  Future<void> _loadDuration() async {
    final duration = await VoiceMessageService.getVoiceDuration(widget.filePath);
    setState(() => _duration = duration);
  }

  void _subscribeToStreams() {
    _positionSubscription = VoiceMessageService.positionStream.listen((position) {
      if (VoiceMessageService.currentlyPlayingPath == widget.filePath) {
        setState(() => _position = position);
      }
    });

    _stateSubscription = VoiceMessageService.playerStateStream.listen((state) {
      if (VoiceMessageService.currentlyPlayingPath == widget.filePath) {
        setState(() => _isPlaying = state.playing);
      } else {
        setState(() => _isPlaying = false);
      }
    });
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await VoiceMessageService.pausePlayback();
    } else {
      await VoiceMessageService.playVoiceMessage(widget.filePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? (widget.isMe ? Colors.white.withValues(alpha: 0.3) : Colors.grey[200]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button
          GestureDetector(
            onTap: _togglePlayback,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.isMe ? Colors.white : const Color(0xFFCA8BF1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: widget.isMe ? const Color(0xFFCA8BF1) : Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Progress bar
          SizedBox(
            width: 100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Waveform visualization (simplified as progress bar)
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: widget.isMe ? Colors.white30 : Colors.grey[400],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.isMe ? Colors.white : const Color(0xFFCA8BF1),
                    ),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 4),
                // Duration
                Text(
                  '${VoiceMessageService.formatDuration(_position)} / ${VoiceMessageService.formatDuration(_duration)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.isMe ? Colors.white70 : Colors.grey[600],
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
