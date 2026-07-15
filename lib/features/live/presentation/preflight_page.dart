import 'package:flutter/material.dart';

import '../../../app/theme/soundtrack_theme.dart';
import '../../../app/widgets/editorial_components.dart';
import '../../events/domain/soundtrack_event.dart';
import '../application/preflight_service.dart';
import '../domain/preflight_result.dart';
import 'preflight_summary.dart';

const preflightEnterKey = Key('preflight-enter');

typedef LiveDashboardBuilder =
    Widget Function(
      BuildContext context,
      SoundTrackEvent checkedEvent,
      String outputRouteLabel,
    );

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
  var _entering = false;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verificação')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          SoundTrackTokens.pagePadding,
          8,
          SoundTrackTokens.pagePadding,
          32,
        ),
        children: [
          Text(
            widget.event.name,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Confira músicas, sistema e saída antes de entrar no Modo Evento.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: SoundTrackTokens.secondaryText,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _checking ? null : _check,
              icon: const Icon(Icons.refresh),
              label: const Text('Reverificar'),
            ),
          ),
          if (_checking) ...[
            const SizedBox(height: 32),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 12),
            const Center(child: Text('Verificando preparação do evento…')),
          ] else if (_failure != null) ...[
            const SizedBox(height: 24),
            const StatusIndicator.error(
              label: 'Não foi possível concluir a verificação',
            ),
            const SizedBox(height: 8),
            OperationalActionRow(
              icon: Icons.refresh,
              title: 'Tentar novamente',
              description: 'Executar uma nova verificação do evento',
              onTap: _check,
            ),
          ] else if (_result != null) ...[
            const SizedBox(height: SoundTrackTokens.sectionGap),
            _MetricStrip(
              summary: summarizePreflight(
                _result!,
                widget.event.moments.length,
              ),
            ),
            const SizedBox(height: SoundTrackTokens.sectionGap),
            ..._buildGroups(_result!),
            const SizedBox(height: SoundTrackTokens.sectionGap),
            OperationalActionRow(
              key: preflightEnterKey,
              icon: Icons.play_arrow,
              title: _result!.hasErrors
                  ? 'Entrar mesmo assim'
                  : 'Entrar no Modo Evento',
              description: _result!.hasErrors
                  ? 'Alguns momentos podem ficar sem áudio'
                  : 'Abre o Dashboard sem iniciar uma faixa',
              destructive: _result!.hasErrors,
              onTap: _entering ? null : _enter,
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildGroups(PreflightResult result) {
    final summary = summarizePreflight(result, widget.event.moments.length);
    final widgets = <Widget>[];
    if (summary.totalMomentCount > 0 &&
        summary.readyAudioCount == summary.totalMomentCount) {
      widgets.addAll(const [
        EditorialSectionHeader(title: 'ÁUDIOS'),
        SizedBox(height: 4),
        StatusIndicator.success(label: 'Todos os áudios estão prontos'),
        SizedBox(height: 12),
      ]);
    }
    const groups = [
      (PreflightSeverity.error, 'ERROS'),
      (PreflightSeverity.warning, 'AVISOS'),
      (PreflightSeverity.info, 'INFORMAÇÕES'),
    ];
    for (final group in groups) {
      final items = result.items
          .where((item) => item.severity == group.$1)
          .toList();
      if (items.isEmpty) continue;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: EditorialSectionHeader(title: group.$2),
        ),
      );
      widgets.addAll(
        items.map(
          (item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: StatusIndicator(
              label: item.message,
              severity: switch (item.severity) {
                PreflightSeverity.error => StatusSeverity.error,
                PreflightSeverity.warning => StatusSeverity.warning,
                PreflightSeverity.info => StatusSeverity.neutral,
              },
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  Future<void> _check() async {
    if (_checking) return;
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
    if (result == null || _checking || _entering) return;
    setState(() => _entering = true);
    try {
      if (result.hasErrors) {
        var dialogCompleting = false;
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
                onPressed: () {
                  if (dialogCompleting) return;
                  dialogCompleting = true;
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  if (dialogCompleting) return;
                  dialogCompleting = true;
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Entrar no Modo Evento'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (context) => widget.dashboardBuilder(
            context,
            widget.event,
            result.outputRouteLabel,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _entering = false);
      }
    }
  }
}

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({required this.summary});

  final PreflightSummary summary;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 24,
      runSpacing: 12,
      children: [
        _Metric(
          label: 'ÁUDIOS PRONTOS',
          value: '${summary.readyAudioCount}/${summary.totalMomentCount}',
          color: Theme.of(context).colorScheme.primary,
        ),
        _Metric(
          label: 'AVISOS',
          value: '${summary.warningCount}',
          color: SoundTrackTokens.warning,
        ),
        _Metric(
          label: 'ERROS',
          value: '${summary.errorCount}',
          color: SoundTrackTokens.destructive,
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: SoundTrackTokens.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}
