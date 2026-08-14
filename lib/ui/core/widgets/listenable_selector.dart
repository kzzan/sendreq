import 'package:flutter/widgets.dart';

typedef ListenableSelection<S> = S Function();
typedef ListenableSelectionEquals<S> = bool Function(S previous, S next);
typedef ListenableSelectionBuilder<S> =
    Widget Function(BuildContext context, S value, Widget? child);

/// Rebuilds only when the selected projection of a [Listenable] changes.
class ListenableSelector<S> extends StatefulWidget {
  const ListenableSelector({
    super.key,
    required this.listenable,
    required this.select,
    required this.builder,
    this.equals,
    this.child,
  });

  final Listenable listenable;
  final ListenableSelection<S> select;
  final ListenableSelectionBuilder<S> builder;
  final ListenableSelectionEquals<S>? equals;
  final Widget? child;

  @override
  State<ListenableSelector<S>> createState() => _ListenableSelectorState<S>();
}

class _ListenableSelectorState<S> extends State<ListenableSelector<S>> {
  late S _selection;

  @override
  void initState() {
    super.initState();
    _selection = widget.select();
    widget.listenable.addListener(_handleChange);
  }

  @override
  void didUpdateWidget(covariant ListenableSelector<S> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.listenable, oldWidget.listenable)) {
      oldWidget.listenable.removeListener(_handleChange);
      widget.listenable.addListener(_handleChange);
    }
    _selection = widget.select();
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_handleChange);
    super.dispose();
  }

  void _handleChange() {
    final next = widget.select();
    final equals = widget.equals ?? _defaultEquals;
    if (equals(_selection, next)) return;
    setState(() => _selection = next);
  }

  static bool _defaultEquals<T>(T previous, T next) => previous == next;

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _selection, widget.child);
}
