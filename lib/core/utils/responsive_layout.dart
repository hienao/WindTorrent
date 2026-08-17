import 'package:flutter/material.dart';

/// 响应式布局工具类
class ResponsiveLayout {
  ResponsiveLayout._();

  /// 断点定义
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  /// 获取当前设备类型
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= desktopBreakpoint) return DeviceType.desktop;
    if (width >= tabletBreakpoint) return DeviceType.tablet;
    if (width >= mobileBreakpoint) return DeviceType.largePhone;
    return DeviceType.mobile;
  }

  /// 是否是手机（包括大屏手机）
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < tabletBreakpoint;
  }

  /// 是否是平板
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= tabletBreakpoint && width < desktopBreakpoint;
  }

  /// 是否是桌面
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopBreakpoint;
  }

  /// 获取响应式值
  static T getValue<T>({
    required BuildContext context,
    required T mobile,
    T? largePhone,
    T? tablet,
    T? desktop,
  }) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.largePhone:
        return largePhone ?? mobile;
      case DeviceType.tablet:
        return tablet ?? largePhone ?? mobile;
      case DeviceType.desktop:
        return desktop ?? tablet ?? largePhone ?? mobile;
    }
  }

  /// 获取响应式内边距
  static EdgeInsets getPadding(BuildContext context) {
    return getValue(
      context: context,
      mobile: const EdgeInsets.all(16),
      largePhone: const EdgeInsets.all(20),
      tablet: const EdgeInsets.all(24),
      desktop: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
    );
  }

  /// 获取响应式间距
  static double getSpacing(BuildContext context) {
    return getValue(
      context: context,
      mobile: 12,
      largePhone: 16,
      tablet: 20,
      desktop: 24,
    );
  }

  /// 获取网格列数
  static int getGridCrossAxisCount(BuildContext context) {
    return getValue(
      context: context,
      mobile: 1,
      largePhone: 2,
      tablet: 3,
      desktop: 4,
    );
  }

  /// 获取最大内容宽度（桌面端居中显示）
  static double? getMaxContentWidth(BuildContext context) {
    if (isDesktop(context)) return 1200;
    if (isTablet(context)) return 900;
    return null; // 手机端全宽
  }
}

/// 设备类型枚举
enum DeviceType {
  mobile,      // < 600
  largePhone,  // 600 - 900
  tablet,      // 900 - 1200
  desktop,     // >= 1200
}

/// 响应式布局构建器
class ResponsiveBuilder extends StatelessWidget {
  final Widget mobile;
  final Widget? largePhone;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.largePhone,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final deviceType = ResponsiveLayout.getDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.largePhone:
        return largePhone ?? mobile;
      case DeviceType.tablet:
        return tablet ?? largePhone ?? mobile;
      case DeviceType.desktop:
        return desktop ?? tablet ?? largePhone ?? mobile;
    }
  }
}

/// 响应式容器（桌面端限制最大宽度并居中）
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final maxWidth = ResponsiveLayout.getMaxContentWidth(context);
    final defaultPadding = ResponsiveLayout.getPadding(context);

    Widget content = Padding(
      padding: padding ?? defaultPadding,
      child: child,
    );

    if (maxWidth != null) {
      content = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: content,
        ),
      );
    }

    return content;
  }
}

/// 响应式网格
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.childAspectRatio = 1.0,
    this.crossAxisSpacing = 16,
    this.mainAxisSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = ResponsiveLayout.getGridCrossAxisCount(context);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}
