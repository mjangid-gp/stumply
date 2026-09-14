import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';

final streamingRepositoryProvider = Provider<StreamingRepository>((ref) {
  return StreamingRepository();
});

/// Live streaming via Agora SDK (Phase 5).
/// Configure AppConstants.agoraAppIdPlaceholder with your Agora App ID.
class StreamingRepository {
  bool _isBroadcasting = false;
  String? _currentChannel;

  bool get isBroadcasting => _isBroadcasting;
  String? get currentChannel => _currentChannel;

  Future<void> startBroadcast({
    required String matchId,
    required String userId,
  }) async {
    debugPrint('Starting Agora broadcast on channel: match_$matchId');
    _currentChannel = 'match_$matchId';
    _isBroadcasting = true;
    // Integrate: await _engine.joinChannel(token, 'match_$matchId', null, userId);
  }

  Future<void> stopBroadcast() async {
    _isBroadcasting = false;
    _currentChannel = null;
  }

  Future<void> joinAsViewer({
    required String matchId,
    required String userId,
  }) async {
    debugPrint('Joining stream: match_$matchId (App ID: ${AppConstants.agoraAppIdPlaceholder})');
  }

  Future<String?> uploadHighlight({
    required String matchId,
    required String filePath,
  }) async {
    debugPrint('Upload highlight for match $matchId from $filePath');
    return null;
  }
}
