import 'dart:async';

import 'package:flutter/material.dart';

import '../application/live_event_controller.dart';
import '../application/live_event_state.dart';

class LiveDashboardPage extends StatefulWidget {
  const LiveDashboardPage({required this.controller, super.key});

  final LiveEventController controller;

  @override
  State<LiveDashboardPage> createState() => _LiveDashboardPageState();
}

class _LiveDashboardPageState extends State<LiveDashboardPage> {
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
        return Scaffold(
          appBar: AppBar(title: const Text('Modo Evento')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                state.event.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Modo Evento ativo. Os controles completos do painel serão '
                'apresentados nesta tela.',
              ),
              const SizedBox(height: 24),
              Text('Momentos', style: Theme.of(context).textTheme.titleLarge),
              for (final moment in state.event.moments)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(moment.name),
                  subtitle: Text(
                    moment.audioPending
                        ? 'Áudio indisponível'
                        : moment.audio!.displayName,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
