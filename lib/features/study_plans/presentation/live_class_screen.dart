import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/study_plan_service.dart';
import '../models/study_plan_models.dart';

/// Joins a live class as either the broadcaster (host/staff) or audience
/// (enrolled student), per the role the backend issues in the Agora token.
/// The caller is responsible for calling [StudyPlanService.startLiveClass]
/// before navigating here as host, and for only offering "Join" to students
/// once the class's status is 'live'.
class LiveClassScreen extends StatefulWidget {
  final int liveClassId;
  final String title;

  const LiveClassScreen({super.key, required this.liveClassId, required this.title});

  @override
  State<LiveClassScreen> createState() => _LiveClassScreenState();
}

enum _LoadState { loading, permissionDenied, error, ready }

class _LiveClassScreenState extends State<LiveClassScreen> {
  RtcEngine? _engine;
  AgoraJoinCredentials? _credentials;
  _LoadState _loadState = _LoadState.loading;
  String? _errorMessage;

  bool _joined = false;
  bool _micMuted = false;
  bool _cameraOff = false;
  final Set<int> _remoteUids = {};
  late final StudyPlanService _service;

  @override
  void initState() {
    super.initState();
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    _service = StudyPlanService(apiClient: apiClient);
    _setup();
  }

  @override
  void dispose() {
    _teardown();
    super.dispose();
  }

  Future<void> _teardown() async {
    final engine = _engine;
    if (engine == null) return;
    try {
      await engine.leaveChannel();
      await engine.release();
    } catch (_) {
      // Best-effort cleanup -- the screen is closing regardless.
    }
  }

  Future<void> _setup() async {
    final camera = await Permission.camera.request();
    final mic = await Permission.microphone.request();
    if (!camera.isGranted || !mic.isGranted) {
      if (!mounted) return;
      setState(() => _loadState = _LoadState.permissionDenied);
      return;
    }

    try {
      final credentials = await _service.getLiveClassToken(widget.liveClassId);
      final engine = createAgoraRtcEngine();
      await engine.initialize(RtcEngineContext(appId: credentials.appId));

      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            if (!mounted) return;
            setState(() => _joined = true);
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            if (!mounted) return;
            setState(() => _remoteUids.add(remoteUid));
          },
          onUserOffline: (connection, remoteUid, reason) {
            if (!mounted) return;
            setState(() => _remoteUids.remove(remoteUid));
          },
          onError: (err, msg) {
            if (!mounted) return;
            setState(() {
              _loadState = _LoadState.error;
              _errorMessage = msg;
            });
          },
          onLeaveChannel: (connection, stats) {
            if (!mounted) return;
            setState(() {
              _joined = false;
              _remoteUids.clear();
            });
          },
        ),
      );

      await engine.enableVideo();
      if (credentials.isHost) {
        await engine.startPreview();
      }

      await engine.joinChannel(
        token: credentials.token ?? '',
        channelId: credentials.channelName,
        uid: credentials.uid,
        options: ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          clientRoleType: credentials.isHost
              ? ClientRoleType.clientRoleBroadcaster
              : ClientRoleType.clientRoleAudience,
        ),
      );

      if (!mounted) return;
      setState(() {
        _engine = engine;
        _credentials = credentials;
        _loadState = _LoadState.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadState = _LoadState.error;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _toggleMic() async {
    final engine = _engine;
    if (engine == null) return;
    await engine.muteLocalAudioStream(!_micMuted);
    setState(() => _micMuted = !_micMuted);
  }

  Future<void> _toggleCamera() async {
    final engine = _engine;
    if (engine == null) return;
    await engine.muteLocalVideoStream(!_cameraOff);
    setState(() => _cameraOff = !_cameraOff);
  }

  Future<void> _endClassAndLeave() async {
    final isHost = _credentials?.isHost ?? false;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (isHost) {
      try {
        await _service.endLiveClass(widget.liveClassId);
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Could not end class on server: $e')));
      }
    }
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    switch (_loadState) {
      case _LoadState.loading:
        return const Center(child: CircularProgressIndicator(color: Colors.white));
      case _LoadState.permissionDenied:
        return _buildMessageState(
          icon: Icons.videocam_off_rounded,
          title: 'Camera & microphone needed',
          message: 'Allow camera and microphone access in your device settings to join this live class.',
        );
      case _LoadState.error:
        return _buildMessageState(
          icon: Icons.error_outline_rounded,
          title: "Couldn't join the class",
          message: _errorMessage ?? 'Something went wrong.',
        );
      case _LoadState.ready:
        return _joined
            ? _buildLiveView()
            : const Center(child: CircularProgressIndicator(color: Colors.white));
    }
  }

  Widget _buildMessageState({required IconData icon, required String title, required String message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white54, size: 48),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go back', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveView() {
    final credentials = _credentials!;
    final engine = _engine!;
    final isHost = credentials.isHost;

    return Stack(
      children: [
        Positioned.fill(child: _buildMainVideo(engine, isHost)),

        if (isHost && _remoteUids.isNotEmpty)
          Positioned(
            top: 12,
            right: 12,
            child: SizedBox(
              width: 96,
              height: 130,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AgoraVideoView(
                  controller: VideoViewController.remote(
                    rtcEngine: engine,
                    canvas: VideoCanvas(uid: _remoteUids.first),
                    connection: RtcConnection(channelId: credentials.channelName),
                  ),
                ),
              ),
            ),
          ),

        Positioned(
          top: 12,
          left: 12,
          child: Row(
            children: [
              _buildLiveBadge(),
              const SizedBox(width: 8),
              _buildParticipantChip(isHost),
            ],
          ),
        ),

        Positioned(
          top: 12,
          right: isHost && _remoteUids.isNotEmpty ? 116 : 12,
          child: _buildIconButton(
            icon: Icons.close_rounded,
            onPressed: _endClassAndLeave,
          ),
        ),

        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: Center(child: _buildControlsBar(isHost)),
        ),
      ],
    );
  }

  Widget _buildMainVideo(RtcEngine engine, bool isHost) {
    if (isHost) {
      return AgoraVideoView(
        controller: VideoViewController(rtcEngine: engine, canvas: const VideoCanvas(uid: 0)),
      );
    }

    if (_remoteUids.isEmpty) {
      return Container(
        color: const Color(0xFF0F172A),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Waiting for the host to start video…',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: engine,
        canvas: VideoCanvas(uid: _remoteUids.first),
        connection: RtcConnection(channelId: _credentials!.channelName),
      ),
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: AppColors.berry, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text('LIVE', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildParticipantChip(bool isHost) {
    final count = isHost ? _remoteUids.length : _remoteUids.length + 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_alt_rounded, color: Colors.white, size: 13),
          const SizedBox(width: 4),
          Text('$count', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11.5)),
        ],
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onPressed, Color? background}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: background ?? Colors.black45, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildControlsBar(bool isHost) {
    if (!isHost) {
      return _buildIconButton(icon: Icons.call_end_rounded, background: AppColors.berry, onPressed: _endClassAndLeave);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIconButton(
          icon: _micMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
          background: _micMuted ? Colors.white24 : Colors.black45,
          onPressed: _toggleMic,
        ),
        const SizedBox(width: 16),
        _buildIconButton(icon: Icons.call_end_rounded, background: AppColors.berry, onPressed: _endClassAndLeave),
        const SizedBox(width: 16),
        _buildIconButton(
          icon: _cameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
          background: _cameraOff ? Colors.white24 : Colors.black45,
          onPressed: _toggleCamera,
        ),
        const SizedBox(width: 16),
        _buildIconButton(icon: Icons.cameraswitch_rounded, onPressed: () => _engine?.switchCamera()),
      ],
    );
  }
}
