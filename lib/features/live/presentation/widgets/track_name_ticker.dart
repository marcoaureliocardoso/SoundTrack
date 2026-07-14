import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class TrackNameTicker extends StatefulWidget {
  const TrackNameTicker({
    required this.text,
    this.style,
    this.initialPause = const Duration(seconds: 2),
    this.endPause = const Duration(seconds: 1),
    this.startHold = const Duration(seconds: 3),
    this.resetFade = const Duration(milliseconds: 120),
    this.pixelsPerSecond = 36,
    super.key,
  });

  final String text;
  final TextStyle? style;
  final Duration initialPause;
  final Duration endPause;
  final Duration startHold;
  final Duration resetFade;
  final double pixelsPerSecond;

  @override
  State<TrackNameTicker> createState() => _TrackNameTickerState();
}

class _TrackNameTickerState extends State<TrackNameTicker> {
  final _scrollController = ScrollController();
  Timer? _timer;
  int? _configurationSignature;
  var _generation = 0;
  var _visible = true;

  @override
  void didUpdateWidget(TrackNameTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.style != widget.style ||
        oldWidget.pixelsPerSecond != widget.pixelsPerSecond) {
      _invalidateCycle();
      _configurationSignature = null;
    }
  }

  @override
  void dispose() {
    _invalidateCycle();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    final textScaler = MediaQuery.textScalerOf(context);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: textScaler,
        )..layout();
        final overflows =
            constraints.maxWidth.isFinite &&
            painter.width > constraints.maxWidth;
        final signature = Object.hash(
          widget.text,
          style,
          textScaler,
          constraints.maxWidth,
          disableAnimations,
          overflows,
        );
        if (_configurationSignature != signature) {
          _configurationSignature = signature;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _configureCycle(
              overflows: overflows,
              disableAnimations: disableAnimations,
              signature: signature,
            );
          });
        }

        final child = disableAnimations
            ? Text(
                widget.text,
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: AnimatedOpacity(
                  opacity: _visible ? 1 : 0,
                  duration: widget.resetFade,
                  child: Text(
                    widget.text,
                    style: style,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              );

        return Semantics(
          label: widget.text,
          excludeSemantics: true,
          child: child,
        );
      },
    );
  }

  void _configureCycle({
    required bool overflows,
    required bool disableAnimations,
    required int signature,
  }) {
    if (!mounted || _configurationSignature != signature) return;
    _invalidateCycle();
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    if (!_visible) {
      setState(() => _visible = true);
    }
    if (!overflows || disableAnimations) return;
    final generation = _generation;
    _schedule(widget.initialPause, generation, _scrollToEnd);
  }

  void _scrollToEnd(int generation) {
    if (!_isCurrent(generation) || !_scrollController.hasClients) return;
    final distance = _scrollController.position.maxScrollExtent;
    if (distance <= 0) return;
    final milliseconds = math.max(
      1,
      (distance / widget.pixelsPerSecond * 1000).round(),
    );
    _scrollController
        .animateTo(
          distance,
          duration: Duration(milliseconds: milliseconds),
          curve: Curves.linear,
        )
        .whenComplete(() {
          if (_isCurrent(generation)) {
            _schedule(widget.endPause, generation, _fadeToStart);
          }
        });
  }

  void _fadeToStart(int generation) {
    if (!_isCurrent(generation)) return;
    setState(() => _visible = false);
    _schedule(widget.resetFade, generation, _resetToStart);
  }

  void _resetToStart(int generation) {
    if (!_isCurrent(generation)) return;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    setState(() => _visible = true);
    _schedule(widget.startHold, generation, _scrollToEnd);
  }

  void _schedule(
    Duration delay,
    int generation,
    void Function(int generation) action,
  ) {
    _timer?.cancel();
    _timer = Timer(delay, () => action(generation));
  }

  bool _isCurrent(int generation) => mounted && generation == _generation;

  void _invalidateCycle() {
    _generation++;
    _timer?.cancel();
    _timer = null;
  }
}
