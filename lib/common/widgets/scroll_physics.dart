import 'package:PiliPlus/common/widgets/flutter/page/tabs.dart';
import 'package:PiliPlus/common/widgets/gesture/horizontal_drag_gesture_recognizer.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/material.dart' hide TabBarView;

Widget tabBarView({
  required List<Widget> children,
  TabController? controller,
}) => TabBarView<CustomHorizontalDragGestureRecognizer>(
  controller: controller,
  physics: clampingScrollPhysics,
  horizontalDragGestureRecognizer: CustomHorizontalDragGestureRecognizer.new,
  children: children,
);

SpringDescription _customSpringDescription() {
  final List<double> springDescription = Pref.springDescription;
  return SpringDescription(
    mass: springDescription[0],
    stiffness: springDescription[1],
    damping: springDescription[2],
  );
}

const clampingScrollPhysics = CustomTabBarViewScrollPhysics(
  parent: ClampingScrollPhysics(),
);

class CustomTabBarViewScrollPhysics extends ScrollPhysics {
  const CustomTabBarViewScrollPhysics({super.parent});

  @override
  CustomTabBarViewScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return CustomTabBarViewScrollPhysics(parent: buildParent(ancestor));
  }

  static final _springDescription = _customSpringDescription();

  @override
  SpringDescription get spring => _springDescription;
}

mixin ReloadMixin {
  late bool reload = false;
}

class AutoScrollPhysics extends ScrollPhysics {
  const AutoScrollPhysics({
    super.parent,
    this.minBoostVelocity = 180,
    this.maxBoostVelocity = 1800,
    this.maxExtraVelocityRatio = 0.22,
    this.maxAdjustedVelocity = 2200,
  }) : assert(minBoostVelocity > 0),
       assert(maxBoostVelocity >= minBoostVelocity),
       assert(maxExtraVelocityRatio >= 0),
       assert(maxAdjustedVelocity >= minBoostVelocity);

  final double minBoostVelocity;
  final double maxBoostVelocity;
  final double maxExtraVelocityRatio;
  final double maxAdjustedVelocity;

  @override
  AutoScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return AutoScrollPhysics(
      parent: buildParent(ancestor),
      minBoostVelocity: minBoostVelocity,
      maxBoostVelocity: maxBoostVelocity,
      maxExtraVelocityRatio: maxExtraVelocityRatio,
      maxAdjustedVelocity: maxAdjustedVelocity,
    );
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final parentSimulation = super.createBallisticSimulation(
      position,
      velocity,
    );
    if (position.outOfRange) {
      return parentSimulation;
    }

    final absVelocity = velocity.abs();
    if (parentSimulation == null ||
        absVelocity < minBoostVelocity ||
        absVelocity > maxBoostVelocity) {
      return parentSimulation;
    }

    if (velocity < 0 && position.pixels <= position.minScrollExtent) {
      return parentSimulation;
    }
    if (velocity > 0 && position.pixels >= position.maxScrollExtent) {
      return parentSimulation;
    }

    final double progress = maxBoostVelocity == minBoostVelocity
        ? 1.0
        : ((absVelocity - minBoostVelocity) /
                  (maxBoostVelocity - minBoostVelocity))
              .clamp(0.0, 1.0)
              .toDouble();
    final double adjustedVelocity =
        (absVelocity * (1.0 + (1.0 - progress) * maxExtraVelocityRatio))
            .clamp(minBoostVelocity, maxAdjustedVelocity)
            .toDouble() *
        velocity.sign;
    final Tolerance tolerance = toleranceFor(position);

    if (parentSimulation is BouncingScrollSimulation) {
      return BouncingScrollSimulation(
        spring: spring,
        position: position.pixels,
        velocity: adjustedVelocity,
        leadingExtent: position.minScrollExtent,
        trailingExtent: position.maxScrollExtent,
        tolerance: tolerance,
        constantDeceleration: switch (_findBouncingPhysics(
          parent,
        )?.decelerationRate) {
          ScrollDecelerationRate.fast => 1400,
          _ => 0,
        },
      );
    }

    if (parentSimulation is ClampingScrollSimulation) {
      return ClampingScrollSimulation(
        position: position.pixels,
        velocity: adjustedVelocity,
        tolerance: tolerance,
      );
    }

    return parentSimulation;
  }
}

BouncingScrollPhysics? _findBouncingPhysics(ScrollPhysics? physics) {
  ScrollPhysics? current = physics;
  while (current != null) {
    if (current is BouncingScrollPhysics) {
      return current;
    }
    current = current.parent;
  }
  return null;
}

class ReloadScrollPhysics extends AlwaysScrollableScrollPhysics {
  const ReloadScrollPhysics({super.parent, required this.controller});

  final ReloadMixin controller;

  @override
  ReloadScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ReloadScrollPhysics(
      parent: buildParent(ancestor),
      controller: controller,
    );
  }

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    if (controller.reload) {
      controller.reload = false;
      return 0;
    }
    return super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );
  }
}
