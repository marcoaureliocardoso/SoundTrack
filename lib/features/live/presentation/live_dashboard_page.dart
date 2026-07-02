import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../events/domain/event_moment.dart';
import '../../playback/domain/playback_alert.dart';
import '../../playback/domain/playback_snapshot.dart';
import '../application/live_event_controller.dart';
import '../application/live_event_state.dart';
export 'live_dashboard_keys.dart';

import 'live_dashboard_keys.dart';
import 'widgets/emergency_volume_panel.dart';
import 'widgets/live_alert_banner.dart';
import 'widgets/moment_action_button.dart';
import 'widgets/now_playing_panel.dart';
import 'widgets/playback_controls.dart';

typedef OutputRouteReader = Future<String> Function();
typedef LiveMomentBuilder =
    Widget Function(
      BuildContext context,
      int number,
      EventMoment moment,
      MomentStatus status,
      VoidCallback onStart,
    );

class LiveDashboardPage extends StatefulWidget {
  const LiveDashboardPage({
    required this.controller,
    this.outputRouteLabel = 'Saída não confirmada',
    this.readOutputRoute,
    this.momentBuilder,
    super.key,
  });

  final LiveEventController controller;
  final String outputRouteLabel;
  final OutputRouteReader? readOutputRoute;
  final LiveMomentBuilder? momentBuilder;

  @override
  State<LiveDashboardPage> createState() => _LiveDashboardPageState();
}

class _LiveDashboardPageState extends State<LiveDashboardPage> {
  late final ValueNotifier<String> _outputRouteLabel;
  PlaybackAlert? _observedAlert;
  var _routeGeneration = 0;
  var _routeRefreshPending = false;
  var _routeRefreshQueued = false;
  var _stopDialogOpen = false;
  var _exitDialogOpen = false;
  var _allowPop = false;

  @override
  void initState() {
    super.initState();
    _outputRouteLabel = ValueNotifier(widget.outputRouteLabel);
    _observedAlert = widget.controller.state.value.visibleAlert;
    widget.controller.state.addListener(_onLiveState);
  }

  @override
  void dispose() {
    widget.controller.state.removeListener(_onLiveState);
    _outputRouteLabel.dispose();
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.controller.state.value.event;
    final momentCount = event.moments.length;
    return PopScope<void>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _confirmExit();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                'Modo Evento',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(32),
            child: SizedBox(
              height: 32,
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.speaker, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ValueListenableBuilder<String>(
                        valueListenable: _outputRouteLabel,
                        builder: (context, label, _) => Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxHeight < 650 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.4;
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  compact ? 4 : 12,
                  16,
                  compact ? 4 : 12,
                ),
                child: Column(
                  children: [
                    _LiveStateSelector<PlaybackAlert?>(
                      state: widget.controller.state,
                      select: (state) => state.visibleAlert,
                      builder: (context, alert) => alert == null
                          ? const SizedBox.shrink()
                          : _BoundedPanel(
                              maxHeight: compact ? 48 : 96,
                              child: LiveAlertBanner(
                                alert: alert,
                                onDismiss: widget.controller.dismissAlert,
                              ),
                            ),
                    ),
                    _BoundedPanel(
                      maxHeight: compact ? 52 : 190,
                      child: _LiveStateSelector<_NowPlayingSlice>(
                        state: widget.controller.state,
                        select: _selectNowPlaying,
                        builder: (context, _) => NowPlayingPanel(
                          key: nowPlayingPanelKey,
                          state: widget.controller.state.value,
                          compact: compact,
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 2 : 8),
                    SizedBox(
                      height: compact ? 24 : 32,
                      width: double.infinity,
                      child: Text(
                        'MOMENTOS — TOQUE PARA INICIAR',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 4),
                        itemCount: momentCount,
                        itemBuilder: (context, momentIndex) {
                          final moment = event.moments[momentIndex];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _LiveMomentItem(
                              controller: widget.controller,
                              number: momentIndex + 1,
                              moment: moment,
                              builder: widget.momentBuilder,
                            ),
                          );
                        },
                      ),
                    ),
                    _LiveStateSelector<_ControlsSlice>(
                      state: widget.controller.state,
                      select: _selectControls,
                      builder: (context, _) {
                        final state = widget.controller.state.value;
                        return PlaybackControls(
                          playback: state.playback,
                          narrationAvailable: state.narrationAvailable,
                          onPause: widget.controller.pause,
                          onResume: widget.controller.resume,
                          onStop: _confirmStop,
                          onNarrationChanged: widget.controller.setNarration,
                          compact: compact,
                        );
                      },
                    ),
                    _LiveStateSelector<_VolumesSlice>(
                      state: widget.controller.state,
                      select: _selectVolumes,
                      builder: (context, _) {
                        final state = widget.controller.state.value;
                        return EmergencyVolumePanel(
                          expanded: state.controlsExpanded,
                          playback: state.playback,
                          onToggle: widget.controller.toggleControlsExpanded,
                          onVolumesChanged: widget.controller.setSessionVolumes,
                          onRestore: widget.controller.restorePresetVolumes,
                          compact: compact,
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _onLiveState() {
    final alert = widget.controller.state.value.visibleAlert;
    if (identical(alert, _observedAlert)) return;
    _observedAlert = alert;
    if (alert?.code == PlaybackAlertCode.routeChanged) {
      _requestRouteRefresh();
    }
  }

  void _requestRouteRefresh() {
    _routeGeneration++;
    if (_routeRefreshPending) {
      _routeRefreshQueued = true;
      return;
    }
    _runRouteRefresh(_routeGeneration);
  }

  Future<void> _runRouteRefresh(int generation) async {
    _routeRefreshPending = true;
    try {
      final reader = widget.readOutputRoute;
      final label = reader == null ? 'Saída não confirmada' : await reader();
      if (mounted && generation == _routeGeneration) {
        _outputRouteLabel.value = label;
      }
    } catch (_) {
      if (mounted && generation == _routeGeneration) {
        _outputRouteLabel.value = 'Saída não confirmada';
      }
    } finally {
      _routeRefreshPending = false;
      if (_routeRefreshQueued && mounted) {
        _routeRefreshQueued = false;
        _runRouteRefresh(_routeGeneration);
      }
    }
  }

  Future<void> _confirmStop() async {
    if (_stopDialogOpen || !mounted) return;
    _stopDialogOpen = true;
    try {
      final momentName =
          widget.controller.state.value.currentMomentName ?? 'a reprodução';
      var completing = false;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Parar “$momentName”?'),
          content: const Text(
            'O áudio atual será interrompido. Você poderá iniciar outro '
            'momento depois.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (completing) return;
                completing = true;
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (completing) return;
                completing = true;
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Parar reprodução'),
            ),
          ],
        ),
      );
      if (confirmed == true && mounted) {
        await widget.controller.confirmStop();
      }
    } finally {
      _stopDialogOpen = false;
    }
  }

  Future<void> _confirmExit() async {
    if (_exitDialogOpen || _allowPop || !mounted) return;
    _exitDialogOpen = true;
    try {
      var completing = false;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Sair do Modo Evento?'),
          content: const Text(
            'Sair desta tela não interrompe a reprodução em andamento.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (completing) return;
                completing = true;
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Continuar no evento'),
            ),
            FilledButton(
              onPressed: () {
                if (completing) return;
                completing = true;
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Sair'),
            ),
          ],
        ),
      );
      if (confirmed == true && mounted) {
        setState(() => _allowPop = true);
        Navigator.of(context).pop();
      }
    } finally {
      _exitDialogOpen = false;
    }
  }

  Future<void> _disposeController() async {
    try {
      await widget.controller.dispose();
    } catch (_) {
      // Disposal only detaches subscriptions; there is no operator action.
    }
  }
}

class _BoundedPanel extends StatelessWidget {
  const _BoundedPanel({required this.maxHeight, required this.child});

  final double maxHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ClipRect(
        child: SingleChildScrollView(
          primary: false,
          physics: const ClampingScrollPhysics(),
          child: child,
        ),
      ),
    );
  }
}

class _LiveMomentItem extends StatefulWidget {
  const _LiveMomentItem({
    required this.controller,
    required this.number,
    required this.moment,
    required this.builder,
  });

  final LiveEventController controller;
  final int number;
  final EventMoment moment;
  final LiveMomentBuilder? builder;

  @override
  State<_LiveMomentItem> createState() => _LiveMomentItemState();
}

class _LiveMomentItemState extends State<_LiveMomentItem> {
  late _MomentSlice _slice;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _slice = _selectMoment(widget.controller.state.value);
    widget.controller.state.addListener(_onState);
  }

  @override
  void dispose() {
    widget.controller.state.removeListener(_onState);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.controller.state.value.momentStatus(widget.moment.id);
    final built =
        widget.builder?.call(
          context,
          widget.number,
          widget.moment,
          status,
          _start,
        ) ??
        MomentActionButton(
          key: liveMomentKey(widget.moment.id),
          number: widget.number,
          moment: widget.moment,
          status: status,
          onPressed: _start,
          commandEnabled: !_busy,
        );
    if (!_busy) return built;
    return IgnorePointer(child: Semantics(enabled: false, child: built));
  }

  void _onState() {
    final next = _selectMoment(widget.controller.state.value);
    if (next == _slice) return;
    _slice = next;
    if (mounted) setState(() {});
  }

  Future<void> _start() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.controller.startMoment(widget.moment.id);
    } catch (_) {
      // The controller publishes the operator-facing alert.
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

class _LiveStateSelector<T> extends StatefulWidget {
  const _LiveStateSelector({
    required this.state,
    required this.select,
    required this.builder,
  });

  final ValueListenable<LiveEventState> state;
  final T Function(LiveEventState state) select;
  final Widget Function(BuildContext context, T selected) builder;

  @override
  State<_LiveStateSelector<T>> createState() => _LiveStateSelectorState<T>();
}

class _LiveStateSelectorState<T> extends State<_LiveStateSelector<T>> {
  late T _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.select(widget.state.value);
    widget.state.addListener(_onState);
  }

  @override
  void didUpdateWidget(_LiveStateSelector<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      oldWidget.state.removeListener(_onState);
      _selected = widget.select(widget.state.value);
      widget.state.addListener(_onState);
    }
  }

  @override
  void dispose() {
    widget.state.removeListener(_onState);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _selected);

  void _onState() {
    final next = widget.select(widget.state.value);
    if (next == _selected) return;
    setState(() => _selected = next);
  }
}

typedef _NowPlayingSlice = ({
  String? activeMomentId,
  PlaybackPhase phase,
  Duration position,
  Duration? duration,
});

typedef _ControlsSlice = ({
  String? activeMomentId,
  PlaybackPhase phase,
  bool narrationActive,
  bool narrationAvailable,
});

typedef _VolumesSlice = ({
  double master,
  double music,
  double narration,
  bool expanded,
});

typedef _MomentSlice = ({
  String? activeMomentId,
  String? errorMomentId,
  PlaybackAlertCode? error,
});

_NowPlayingSlice _selectNowPlaying(LiveEventState state) => (
  activeMomentId: state.playback.activeMomentId,
  phase: state.playback.phase,
  position: state.playback.position,
  duration: state.currentAudioDuration,
);

_ControlsSlice _selectControls(LiveEventState state) => (
  activeMomentId: state.playback.activeMomentId,
  phase: state.playback.phase,
  narrationActive: state.playback.narrationActive,
  narrationAvailable: state.narrationAvailable,
);

_VolumesSlice _selectVolumes(LiveEventState state) => (
  master: state.playback.masterVolume,
  music: state.playback.musicVolume,
  narration: state.playback.narrationVolume,
  expanded: state.controlsExpanded,
);

_MomentSlice _selectMoment(LiveEventState state) {
  final alert = state.visibleAlert;
  final affectsMoment =
      alert?.code == PlaybackAlertCode.sourceFailed ||
      alert?.code == PlaybackAlertCode.sourceUnavailable;
  return (
    activeMomentId: state.playback.activeMomentId,
    errorMomentId: affectsMoment ? alert?.momentId : null,
    error: affectsMoment ? alert?.code : null,
  );
}
