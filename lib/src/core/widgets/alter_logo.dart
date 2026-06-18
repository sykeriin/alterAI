import 'package:flutter/material.dart';

/// ALTER brand logo from bundled assets.
class AlterLogo extends StatelessWidget {
  const AlterLogo({
    super.key,
    this.width,
    this.height,
    this.showWordmark = true,
    this.color,
  });

  final double? width;
  final double? height;
  final bool showWordmark;
  final Color? color;

  static const _fullAsset = 'assets/images/alter_logo.png';
  static const _markAsset = 'assets/images/alter_mark.png';

  @override
  Widget build(BuildContext context) {
    final asset = showWordmark ? _fullAsset : _markAsset;
    final image = Image.asset(
      asset,
      width: width,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    if (color == null) return image;

    return ColorFiltered(
      colorFilter: ColorFilter.mode(color!, BlendMode.srcIn),
      child: image,
    );
  }
}
