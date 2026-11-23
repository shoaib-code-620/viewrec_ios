import 'package:flutter/material.dart';
import 'theme.dart';
import 'widgets.dart';

/// Loads data once, then shows: a pulsing skeleton while loading, a retry
/// screen on error, and the real content when ready.
/// [builder] also receives a `refresh` function (used for pull-to-refresh and
/// after changes that need new server data).
class AsyncView<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() refresh) builder;
  final int skeletonCards;
  const AsyncView({super.key, required this.load, required this.builder, this.skeletonCards = 4});
  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  late Future<T> _future = widget.load();

  Future<void> _refresh() async {
    final f = widget.load();
    setState(() => _future = f);
    try {
      await f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return SkeletonList(cards: widget.skeletonCards);
          if (snap.hasError) return ErrorState(message: snap.error.toString().replaceFirst('Exception: ', ''), onRetry: _refresh);
          return widget.builder(context, snap.data as T, _refresh);
        },
      );
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorState({super.key, required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_off_rounded, size: 44, color: C.muted),
            const SizedBox(height: 14),
            const Text("Couldn't load this page", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Muted(message, size: 13, align: TextAlign.center),
            const SizedBox(height: 18),
            SizedBox(width: 160, child: AppButton('Try again', icon: Icons.refresh_rounded, small: true, onTap: onRetry)),
          ]),
        ),
      );
}

/// Pulsing placeholder cards shown while data loads.
class SkeletonList extends StatefulWidget {
  final int cards;
  const SkeletonList({super.key, this.cards = 4});
  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _bar(double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(6)),
      );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Opacity(
          opacity: 0.45 + 0.55 * _c.value,
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              for (var i = 0; i < widget.cards; i++)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(rLg), border: Border.all(color: C.border)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(width: 40, height: 40, decoration: BoxDecoration(color: C.surface2, shape: BoxShape.circle)),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_bar(140, 14), const SizedBox(height: 8), _bar(90, 10)]),
                    ]),
                    const SizedBox(height: 16),
                    _bar(double.infinity, 10),
                    const SizedBox(height: 8),
                    _bar(220, 10),
                  ]),
                ),
            ],
          ),
        ),
      );
}
