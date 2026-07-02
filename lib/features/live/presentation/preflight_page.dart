import 'package:flutter/material.dart';

import '../../events/domain/soundtrack_event.dart';
import '../application/preflight_service.dart';
import '../domain/preflight_result.dart';

typedef LiveDashboardBuilder =
    Widget Function(BuildContext context, SoundTrackEvent checkedEvent);

class PreflightPage extends StatefulWidget {
  const PreflightPage({
    required this.event,
    required this.preflightService,
    required this.dashboardBuilder,
    super.key,
  });

  final SoundTrackEvent event;
  final PreflightService preflightService;
  final LiveDashboardBuilder dashboardBuilder;

  @override
  State<PreflightPage> createState() => _PreflightPageState();
}

class _PreflightPageState extends State<PreflightPage> {
  PreflightResult? _result;
  Object? _failure;
  var _checking = false;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verificação pré-evento')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.event.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Confira áudio, sistema e rota de saída antes de entrar no '
            'Modo Evento.',
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _check,
            icon: const Icon(Icons.refresh),
            label: const Text('Reverificar'),
          ),
          if (_checking) ...[
            const SizedBox(height: 32),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 12),
            const Center(child: Text('Verificando preparação do evento…')),
          ] else if (_failure != null) ...[
            const SizedBox(height: 24),
            const Text('Não foi possível concluir a verificação.'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _check,
              child: const Text('Tentar novamente'),
            ),
          ] else if (_result != null) ...[
            const SizedBox(height: 16),
            ..._buildGroups(_result!),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _enter,
              icon: const Icon(Icons.play_arrow),
              label: Text(
                _result!.hasErrors
                    ? 'Entrar mesmo assim'
                    : 'Iniciar Modo Evento',
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildGroups(PreflightResult result) {
    const groups = [
      (PreflightSeverity.error, 'Erros', Icons.error_outline),
      (PreflightSeverity.warning, 'Avisos', Icons.warning_amber),
      (PreflightSeverity.info, 'Informações', Icons.info_outline),
    ];
    final widgets = <Widget>[];
    for (final group in groups) {
      final items = result.items
          .where((item) => item.severity == group.$1)
          .toList();
      if (items.isEmpty) continue;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Row(
            children: [
              Icon(group.$3),
              const SizedBox(width: 8),
              Text(group.$2, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      );
      widgets.addAll(
        items.map(
          (item) => ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 8),
            title: Text(item.message),
          ),
        ),
      );
    }
    return widgets;
  }

  Future<void> _check() async {
    final generation = ++_generation;
    setState(() {
      _checking = true;
      _failure = null;
    });
    try {
      final result = await widget.preflightService.check(widget.event);
      if (!mounted || generation != _generation) return;
      setState(() {
        _result = result;
        _checking = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _failure = error;
        _result = null;
        _checking = false;
      });
    }
  }

  Future<void> _enter() async {
    final result = _result;
    if (result == null || _checking) return;
    if (result.hasErrors) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Confirmar entrada'),
          content: const Text(
            'Há erros na verificação. Entrar mesmo assim pode deixar '
            'momentos sem áudio. Deseja continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Entrar no Modo Evento'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => widget.dashboardBuilder(context, widget.event),
      ),
    );
  }
}
