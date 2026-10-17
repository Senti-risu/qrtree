import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Measure real content first, then size every neighboring card to the tallest.
/// Unlike IntrinsicHeight, this supports cards containing LayoutBuilder widgets.
class EqualHeightCards extends MultiChildRenderObjectWidget {
  final int columns;
  final double gap;

  const EqualHeightCards({
    super.key,
    required super.children,
    this.columns = 2,
    this.gap = 16,
  }) : assert(columns > 0),
       assert(gap >= 0);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderEqualHeightCards(columns, gap);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderEqualHeightCards renderObject,
  ) {
    renderObject.update(columns, gap);
  }
}

class _CardParentData extends ContainerBoxParentData<RenderBox> {}

class RenderEqualHeightCards extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _CardParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _CardParentData> {
  int _columns;
  double _gap;

  RenderEqualHeightCards(this._columns, this._gap);

  void update(int columns, double gap) {
    if (_columns == columns && _gap == gap) return;
    _columns = columns;
    _gap = gap;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _CardParentData) {
      child.parentData = _CardParentData();
    }
  }

  @override
  void performLayout() {
    assert(
      constraints.hasBoundedWidth,
      'EqualHeightCards needs a bounded width.',
    );
    final width = constraints.maxWidth;
    final cellWidth = math.max(0.0, (width - _gap * (_columns - 1)) / _columns);
    var tallest = 0.0;
    var child = firstChild;
    while (child != null) {
      child.layout(
        BoxConstraints.tightFor(width: cellWidth),
        parentUsesSize: true,
      );
      tallest = math.max(tallest, child.size.height);
      child = (child.parentData! as _CardParentData).nextSibling;
    }
    final rows = (childCount / _columns).ceil();
    size = constraints.constrain(
      Size(width, rows == 0 ? 0 : rows * tallest + (rows - 1) * _gap),
    );
    var index = 0;
    child = firstChild;
    while (child != null) {
      child.layout(
        BoxConstraints.tightFor(width: cellWidth, height: tallest),
        parentUsesSize: true,
      );
      final data = child.parentData! as _CardParentData;
      data.offset = Offset(
        (index % _columns) * (cellWidth + _gap),
        (index ~/ _columns) * (tallest + _gap),
      );
      child = data.nextSibling;
      index++;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
