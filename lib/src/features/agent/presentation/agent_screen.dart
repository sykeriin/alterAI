import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/app_state.dart';
import '../../backend/application/backend_config_controller.dart';
import '../../contextos/application/gemma_model_manager.dart';
import '../../home/presentation/main_shell.dart';
import '../../summon/bubble_bridge.dart';
import '../../voice/application/native_wake_service_controller.dart';
import '../application/agent_controller.dart';
import '../application/agent_execution_runtime.dart';
import '../application/persistent_intelligence_store.dart';
import '../application/proactive_background.dart';
import '../application/proactive_controller.dart';

// ALTER "Standalone" design language (from the HTML mockup).
const _bg = Color(0xFF0A0810);
const _panel = Color(0xFF15101F);
const _lime = Color(0xFFCDF74D);
const _cyan = Color(0xFF5BE0FF);
const _purple = Color(0xFF9B6BFF);
const _pink = Color(0xFFFF6BD0);
const _orange = Color(0xFFFF8A3C);
const _textHi = Color(0xFFF1EDFA);
const _textLo = Color(0xFF9A93AD);
const _eqColors = <Color>[_lime, _cyan, _purple, _pink, _orange];

class AgentScreen extends ConsumerStatefulWidget {
  const AgentScreen({super.key});

  @override
  ConsumerState<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends ConsumerState<AgentScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _showControl = false;

  @override
  void initState() {
    super.initState();
    // Rigid voice model: the mic stays CLOSED on open. It opens ONLY when the
    // user taps the mic button or says "Hey ALTER" (when the wake detector is
    // enabled in Settings). No auto-listening, no hands-free loop.

    // Feed the background proactive pass the context it needs (gateway + user)
    // so it can post tailored nudges even while the app is closed.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final cfg = await ref.read(backendConfigProvider.future);
        if (cfg.hasGateway) {
          await ProactiveBackground.persistContext(
            gateway: cfg.gatewayUrl,
            userId: Supabase.instance.client.auth.currentUser?.id,
          );
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agentControllerProvider);
    final runtime = ref.watch(agentExecutionRuntimeProvider);
    final store = ref.watch(persistentIntelligenceStoreProvider);
    final notifier = ref.read(agentControllerProvider.notifier);

    // "Hey ALTER" detected by the background service → open the mic once.
    // A single-shot listen; the wake handler itself ignores it if ALTER is
    // already speaking, thinking, or listening, so it can never loop.
    ref.listen<int>(
      nativeWakeServiceControllerProvider.select((s) => s.wakeCount),
      (prev, next) {
        if (next > (prev ?? 0)) {
          notifier.startListeningFromWake();
        }
      },
    );
    _scrollToEnd();

    final voiceActive =
        state.isListening || state.isSarvamRecording || state.isThinking;
    // The greeting message is always present; "idle" == nothing said yet.
    final idle = state.messages.length <= 1 && !voiceActive;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.7),
          radius: 1.2,
          colors: [Color(0xFF1B1330), _bg],
          stops: [0.0, 0.75],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 10, 18, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                sarvamOn: state.isSarvamRecording,
                controlOpen: _showControl,
                onSarvam: notifier.toggleSarvamLiveVoice,
                onStopTalk: notifier.stopSpeaking,
                onToggleControl: () =>
                    setState(() => _showControl = !_showControl),
              ),
              if (_showControl) ...[
                const SizedBox(height: 10),
                _LiveControlCenter(
                  runtime: runtime,
                  store: store.asData?.value,
                  liveVoiceStatus: state.liveVoiceStatus,
                  onRunGoal: () {
                    final goal = _input.text.trim();
                    if (goal.isEmpty) return;
                    ref
                        .read(agentExecutionRuntimeProvider.notifier)
                        .runGoal(goal);
                  },
                  onStop: () =>
                      ref.read(agentExecutionRuntimeProvider.notifier).stop(),
                  onExport: () async {
                    final json = await ref
                        .read(persistentIntelligenceStoreProvider.notifier)
                        .exportData();
                    await Clipboard.setData(ClipboardData(text: json));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Local twin export copied.')),
                      );
                    }
                  },
                  onDelete: () {
                    ref
                        .read(persistentIntelligenceStoreProvider.notifier)
                        .deleteScopes(const ['audit', 'memories']);
                  },
                ),
              ],
              Expanded(
                child: idle
                    ? Column(
                        children: [
                          Expanded(child: _VoiceHero(active: voiceActive)),
                          const _ProactiveStrip(),
                        ],
                      )
                    : _Transcript(
                        scroll: _scroll,
                        messages: state.messages,
                        thinking: state.isThinking,
                        active: voiceActive,
                      ),
              ),
              if (state.partial.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, top: 2),
                  child: Text(
                    '“${state.partial}”',
                    style: const TextStyle(
                      color: _lime,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else if (state.isSarvamRecording || state.liveVoiceStatus.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, top: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (state.isSarvamRecording)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: const BoxDecoration(
                            color: _pink,
                            shape: BoxShape.circle,
                          ),
                        ),
                      Text(
                        state.liveVoiceStatus.isNotEmpty
                            ? state.liveVoiceStatus
                            : 'Listening… tap to send',
                        style: const TextStyle(
                          color: _lime,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              if (state.error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    state.error,
                    style: const TextStyle(color: _orange, fontSize: 12),
                  ),
                ),
              _Composer(
                controller: _input,
                listening: state.isListening,
                onMic: () {
                  HapticFeedback.mediumImpact();
                  notifier.toggleListening();
                },
                onSend: () {
                  final t = _input.text.trim();
                  if (t.isEmpty) return;
                  _input.clear();
                  notifier.send(t);
                },
              ),
              SizedBox(height: 86 + bottomInset),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.sarvamOn,
    required this.controlOpen,
    required this.onSarvam,
    required this.onStopTalk,
    required this.onToggleControl,
  });

  final bool sarvamOn;
  final bool controlOpen;
  final VoidCallback onSarvam;
  final VoidCallback onStopTalk;
  final VoidCallback onToggleControl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(color: _lime, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        const Text(
          'ALTER',
          style: TextStyle(
            color: _textHi,
            fontWeight: FontWeight.w800,
            letterSpacing: 4,
            fontSize: 15,
          ),
        ),
        const SizedBox(width: 6),
        const Text('voice',
            style: TextStyle(color: _textLo, fontSize: 12, letterSpacing: 1)),
        const Spacer(),
        _GhostIconButton(
          icon: Icons.apps,
          tooltip: 'All screens',
          onTap: () => _showNavSheet(context),
        ),
        const _OnDeviceToggle(),
        _GhostIconButton(
          icon: sarvamOn ? LucideIcons.square : LucideIcons.audio_lines,
          tint: sarvamOn ? _pink : _cyan,
          tooltip: sarvamOn ? 'Stop Sarvam voice' : 'Sarvam live voice',
          onTap: onSarvam,
        ),
        _GhostIconButton(
          icon: LucideIcons.volume_x,
          tooltip: 'Stop talking',
          onTap: onStopTalk,
        ),
        _GhostIconButton(
          icon: LucideIcons.sliders_horizontal,
          tint: controlOpen ? _lime : null,
          tooltip: 'Control center',
          onTap: onToggleControl,
        ),
      ],
    );
  }
}

class _GhostIconButton extends StatelessWidget {
  const _GhostIconButton({
    required this.icon,
    required this.onTap,
    this.tint,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? tint;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 18, color: tint ?? _textLo),
      onPressed: onTap,
    );
  }
}

/// Header toggle for On-device mode. When lime/on, plain conversational turns
/// are answered by the installed local model instead of the cloud; the agent
/// still reaches the cloud for tools or deep reasoning. Dimmed until a model is
/// installed (tapping it on with no model is harmless — it just stays on cloud).
class _OnDeviceToggle extends ConsumerWidget {
  const _OnDeviceToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(alterAppControllerProvider).onDeviceMode;
    final ready = ref.watch(gemmaModelProvider).isReady;
    return IconButton(
      tooltip: on
          ? 'On-device mode ON — simple chats run on the phone'
          : ready
          ? 'On-device mode OFF — tap to run simple chats on the phone'
          : 'Install an edge model to enable on-device chat',
      icon: Icon(
        LucideIcons.cpu,
        size: 18,
        color: on ? _lime : (ready ? _textLo : _textLo.withValues(alpha: 0.4)),
      ),
      onPressed:
          ref.read(alterAppControllerProvider.notifier).toggleOnDeviceMode,
    );
  }
}

class _VoiceHero extends StatelessWidget {
  const _VoiceHero({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        const SizedBox(
          height: 150,
          width: 150,
          child: _SparkleHero(),
        ),
        const SizedBox(height: 18),
        const Text(
          'ALTER',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 10,
            fontSize: 30,
          ),
        ),
        const SizedBox(height: 26),
        _EqualizerBars(active: active, height: 56, bars: 11),
        const SizedBox(height: 22),
        Text(
          active ? 'Listening…' : 'Tap to speak, or say “Hey Alter”',
          style: const TextStyle(color: _textLo, fontSize: 13.5),
        ),
        const Spacer(flex: 2),
      ],
    );
  }
}

class _SparkleHero extends StatefulWidget {
  const _SparkleHero();

  @override
  State<_SparkleHero> createState() => _SparkleHeroState();
}

class _SparkleHeroState extends State<_SparkleHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        painter: _SparklePainter(_c.value),
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  _SparklePainter(this.t);
  final double t;

  void _star(Canvas canvas, Offset c, double r, double thin, Color color) {
    final p = Path();
    // vertical spike
    p.moveTo(c.dx, c.dy - r);
    p.lineTo(c.dx + thin, c.dy);
    p.lineTo(c.dx, c.dy + r);
    p.lineTo(c.dx - thin, c.dy);
    p.close();
    // horizontal spike
    p.moveTo(c.dx - r, c.dy);
    p.lineTo(c.dx, c.dy - thin);
    p.lineTo(c.dx + r, c.dy);
    p.lineTo(c.dx, c.dy + thin);
    p.close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi);

    // purple glow
    canvas.drawCircle(
      c,
      size.width * (0.34 + 0.04 * pulse),
      Paint()
        ..color = _purple.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34),
    );
    canvas.drawCircle(
      c,
      size.width * 0.2,
      Paint()
        ..color = _pink.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
    );

    // central sparkle
    _star(canvas, c, size.width * 0.34, size.width * 0.05,
        Colors.white.withValues(alpha: 0.96));
    // side sparkles
    _star(canvas, Offset(c.dx - size.width * 0.36, c.dy + size.width * 0.02),
        size.width * 0.08, size.width * 0.018,
        Colors.white.withValues(alpha: 0.6 + 0.3 * pulse));
    _star(canvas, Offset(c.dx + size.width * 0.36, c.dy - size.width * 0.04),
        size.width * 0.07, size.width * 0.016,
        Colors.white.withValues(alpha: 0.5 + 0.3 * (1 - pulse)));
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) => old.t != t;
}

class _EqualizerBars extends StatefulWidget {
  const _EqualizerBars({
    required this.active,
    this.height = 48,
    this.bars = 11,
  });

  final bool active;
  final double height;
  final int bars;

  @override
  State<_EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<_EqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final amp = widget.active ? 1.0 : 0.22;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.bars; i++) ...[
              _bar(i, amp),
              if (i != widget.bars - 1) const SizedBox(width: 6),
            ],
          ],
        );
      },
    );
  }

  Widget _bar(int i, double amp) {
    final phase = _c.value * 2 * math.pi + i * 0.9;
    final mid = (widget.bars - 1) / 2;
    final centerBias = 1 - (i - mid).abs() / (mid + 1) * 0.55;
    final h = widget.height *
        (0.18 + amp * centerBias * (0.5 + 0.5 * math.sin(phase)).abs() * 0.82);
    final color = _eqColors[i % _eqColors.length];
    return Container(
      width: 8,
      height: h.clamp(6, widget.height).toDouble(),
      decoration: BoxDecoration(
        color: color.withValues(alpha: widget.active ? 0.95 : 0.5),
        borderRadius: BorderRadius.circular(4),
        boxShadow: widget.active
            ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
            : null,
      ),
    );
  }
}

class _Transcript extends StatelessWidget {
  const _Transcript({
    required this.scroll,
    required this.messages,
    required this.thinking,
    required this.active,
  });

  final ScrollController scroll;
  final List<AgentMessage> messages;
  final bool thinking;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (active)
          Padding(
            padding: const EdgeInsets.only(bottom: 6, top: 2),
            child: _EqualizerBars(active: true, height: 26, bars: 13),
          ),
        Expanded(
          child: ListView.builder(
            controller: scroll,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 10, top: 4),
            itemCount: messages.length + (thinking ? 1 : 0),
            itemBuilder: (context, i) {
              if (i >= messages.length) return const _ThinkingBubble();
              return _Bubble(message: messages[i]);
            },
          ),
        ),
      ],
    );
  }
}

class _LiveControlCenter extends StatelessWidget {
  const _LiveControlCenter({
    required this.runtime,
    required this.store,
    required this.liveVoiceStatus,
    required this.onRunGoal,
    required this.onStop,
    required this.onExport,
    required this.onDelete,
  });

  final AgentExecutionState runtime;
  final IntelligenceStoreState? store;
  final String liveVoiceStatus;
  final VoidCallback onRunGoal;
  final VoidCallback onStop;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final active = runtime.running || runtime.plan.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                runtime.running ? LucideIcons.activity : LucideIcons.workflow,
                color: runtime.running ? _lime : _cyan,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  runtime.currentGoal.isEmpty
                      ? 'Live control center'
                      : runtime.currentGoal,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textHi,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: runtime.running ? 'Stop loop' : 'Run phone loop',
                icon: Icon(
                  runtime.running ? LucideIcons.square : LucideIcons.play,
                  size: 17,
                  color: _lime,
                ),
                onPressed: runtime.running ? onStop : onRunGoal,
              ),
              IconButton(
                tooltip: 'Export local twin',
                icon: const Icon(LucideIcons.download, size: 17, color: _textLo),
                onPressed: store == null ? null : onExport,
              ),
              IconButton(
                tooltip: 'Delete local audit and memories',
                icon: const Icon(LucideIcons.trash_2, size: 17, color: _textLo),
                onPressed: store == null ? null : onDelete,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniChip(
                label: runtime.currentAgent.label,
                icon: LucideIcons.bot,
                selected: runtime.running,
              ),
              _MiniChip(
                label: '${runtime.completedSteps}/${runtime.plan.length} steps',
                icon: LucideIcons.list_checks,
                selected: runtime.completedSteps > 0,
              ),
              _MiniChip(
                label: '${store?.memories.length ?? 0} memories',
                icon: LucideIcons.database,
                selected: (store?.memories.length ?? 0) > 0,
              ),
              _MiniChip(
                label: '${store?.audit.length ?? 0} audit',
                icon: LucideIcons.clipboard_check,
                selected: (store?.audit.length ?? 0) > 0,
              ),
            ],
          ),
          if (liveVoiceStatus.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              liveVoiceStatus,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _cyan,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (active) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: runtime.plan.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final step = runtime.plan[index];
                  return _StepPill(step: step, index: index + 1);
                },
              ),
            ),
          ],
          if (runtime.audit.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              runtime.audit.first.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: runtime.audit.first.ok ? _textLo : _orange,
              ),
            ),
          ],
          if (runtime.failures.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              runtime.failures.first,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _orange,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.label,
    required this.icon,
    required this.selected,
  });

  final String label;
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = selected ? _lime : _textLo;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: c),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: c, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _StepPill extends StatelessWidget {
  const _StepPill({required this.step, required this.index});

  final AgentRuntimeStep step;
  final int index;

  @override
  Widget build(BuildContext context) {
    final color = switch (step.status) {
      AgentStepStatus.done => _lime,
      AgentStepStatus.failed || AgentStepStatus.blocked => _orange,
      AgentStepStatus.running => _cyan,
      AgentStepStatus.planned => _purple,
    };
    return SizedBox(
      width: 190,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$index. ${step.agent.label}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                step.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textHi,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final AgentMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.role == AgentRole.tool) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _cyan.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: _cyan.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.pending)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _cyan),
                  )
                else
                  const Icon(LucideIcons.zap, size: 12, color: _cyan),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    message.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _cyan,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isUser = message.role == AgentRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          gradient: isUser
              ? const LinearGradient(
                  colors: [_lime, Color(0xFFA6D63A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isUser ? null : _panel,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser ? const Color(0xFF14110A) : _textHi,
            height: 1.4,
            fontSize: 14.5,
            fontWeight: isUser ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: const _EqualizerBars(active: true, height: 16, bars: 5),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.listening,
    required this.onMic,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool listening;
  final VoidCallback onMic;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            minLines: 1,
            maxLines: 4,
            style: const TextStyle(color: _textHi),
            cursorColor: _lime,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSend(),
            decoration: InputDecoration(
              hintText: listening ? 'Listening…' : 'Talk or type to ALTER…',
              hintStyle: const TextStyle(color: _textLo),
              filled: true,
              fillColor: _panel,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: const Icon(LucideIcons.send_horizontal,
                    size: 18, color: _lime),
                onPressed: onSend,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onMic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: listening
                    ? const [_pink, _orange]
                    : const [_lime, Color(0xFFA6D63A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (listening ? _pink : _lime).withValues(alpha: 0.5),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              listening ? LucideIcons.square : LucideIcons.mic,
              color: const Color(0xFF14110A),
              size: 24,
            ),
          ),
        ),
      ],
    );
  }
}

/// "ALTER suggests" — proactive, tailored nudges drawn from the user's twin +
/// day. Shown only when idle; tapping a nudge hands its action to the agent.
class _ProactiveStrip extends ConsumerWidget {
  const _ProactiveStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nudges =
        ref.watch(proactiveNudgesProvider).asData?.value ??
            const <ProactiveNudge>[];
    if (nudges.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8, top: 2),
          child: Row(
            children: [
              Icon(LucideIcons.zap, size: 13, color: _lime),
              SizedBox(width: 6),
              Text(
                'ALTER SUGGESTS',
                style: TextStyle(
                  color: _textLo,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
        for (final n in nudges)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _NudgeCard(
              nudge: n,
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(agentControllerProvider.notifier).send(n.action);
              },
            ),
          ),
      ],
    );
  }
}

class _NudgeCard extends StatelessWidget {
  const _NudgeCard({required this.nudge, required this.onTap});

  final ProactiveNudge nudge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _lime.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nudge.title,
                      style: const TextStyle(
                        color: _textHi,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    if (nudge.why.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        nudge.why,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _textLo, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward_ios, size: 14, color: _lime),
            ],
          ),
        ),
      ),
    );
  }
}

/// App menu opened from the voice screen so every screen (NFC, Graph, Twin,
/// Memory, etc.) is reachable — the bottom nav shell isn't wired into routing.
void _showNavSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: _panel,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _BubbleToggle(),
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 10),
                child: Text(
                  'Go to a screen',
                  style: TextStyle(
                    color: _textHi,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              Flexible(
                child: GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 4,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.82,
                  children: [
                    for (final d in MainShell.destinations)
                      _NavTile(
                        label: d.label,
                        icon: d.icon,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          context.push(d.path);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _lime.withValues(alpha: 0.16)),
            ),
            child: Icon(icon, color: _lime, size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _textLo, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// "Summon from anywhere" — toggles the native floating-bubble overlay so ALTER
/// can be opened over any app, system-assistant style.
class _BubbleToggle extends StatefulWidget {
  const _BubbleToggle();

  @override
  State<_BubbleToggle> createState() => _BubbleToggleState();
}

class _BubbleToggleState extends State<_BubbleToggle> {
  static const _bridge = BubbleBridge();
  bool _running = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final running = await _bridge.isRunning();
    if (mounted) setState(() => _running = running);
  }

  Future<void> _toggle() async {
    setState(() => _busy = true);
    try {
      if (_running) {
        await _bridge.stop();
      } else if (!await _bridge.isOverlayGranted()) {
        await _bridge.requestOverlay();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Allow "display over other apps" for ALTER, then tap again.',
              ),
            ),
          );
        }
      } else {
        await _bridge.start();
      }
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _busy ? null : _toggle,
        child: Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _lime.withValues(alpha: _running ? 0.45 : 0.16),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.bubble_chart, color: _lime, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _running
                          ? 'Floating bubble is ON'
                          : 'Summon from anywhere',
                      style: const TextStyle(
                        color: _textHi,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'A draggable bubble that opens ALTER over any app',
                      style: TextStyle(color: _textLo, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (_busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _lime),
                )
              else
                Text(
                  _running ? 'Turn off' : 'Turn on',
                  style: const TextStyle(
                    color: _lime,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
