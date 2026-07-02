import 'dart:async';

import 'package:flutter/material.dart';

import '../application/live_event_controller.dart';
import '../application/live_event_state.dart';
export 'live_dashboard_keys.dart';

import 'live_dashboard_keys.dart';
import 'widgets/emergency_volume_panel.dart';
import 'widgets/live_alert_banner.dart';
import 'widgets/moment_action_button.dart';
import 'widgets/now_playing_panel.dart';
import 'widgets/playback_controls.dart';

class LiveDashboardPage extends StatefulWidget {
  const LiveDashboardPage({
    required this.controller,
    this.outputRouteLabel = 'Saída não confirmada',
    super.key,
  });

  final LiveEventController controller;
  final String outputRouteLabel;

  @override
  State<LiveDashboardPage> createState() => _LiveDashboardPageState();
}

class _LiveDashboardPageState extends State<LiveDashboardPage> {
  var _stopDialogOpen = false;
  var _exitDialogOpen = false;
  var _allowPop = false;

  @override
  void dispose() {
    unawaited(widget.controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LiveEventState>(
      valueListenable: widget.controller.state,
      builder: (context, state, _) {
        return PopScope<void>(
          canPop: _allowPop,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              unawaited(_confirmExit());
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.event.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
                          child: Text(
                            widget.outputRouteLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (state.visibleAlert case final alert?)
                    LiveAlertBanner(
                      alert: alert,
                      onDismiss: widget.controller.dismissAlert,
                    ),
                  NowPlayingPanel(key: nowPlayingPanelKey, state: state),
                  const SizedBox(height: 20),
                  Text(
                    'MOMENTOS — TOQUE PARA INICIAR',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final moment in state.event.moments) ...[
                    MomentActionButton(
                      key: liveMomentKey(moment.id),
                      number: moment.position + 1,
                      moment: moment,
                      status: state.momentStatus(moment.id),
                      onPressed: () =>
                          unawaited(widget.controller.startMoment(moment.id)),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 4),
                  PlaybackControls(
                    playback: state.playback,
                    narrationAvailable: state.narrationAvailable,
                    onPause: widget.controller.pause,
                    onResume: widget.controller.resume,
                    onStop: _confirmStop,
                    onNarrationChanged: widget.controller.setNarration,
                  ),
                  const SizedBox(height: 12),
                  EmergencyVolumePanel(
                    expanded: state.controlsExpanded,
                    playback: state.playback,
                    onToggle: widget.controller.toggleControlsExpanded,
                    onVolumesChanged: widget.controller.setSessionVolumes,
                    onRestore: widget.controller.restorePresetVolumes,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
}
