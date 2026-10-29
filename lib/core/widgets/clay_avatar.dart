import 'package:dicebear_core/dicebear_core.dart';
import 'package:dicebear_styles/clay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Round DiceBear clay avatar; the same seed always draws the same avatar
class ClayAvatar extends StatelessWidget {
  // Parsed once, since the style definition is a large JSON string
  static final _style = Style.parse(clay);

  final String seed;
  final double radius;

  const ClayAvatar({super.key, required this.seed, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final svg = Avatar(_style, {'seed': seed, 'borderRadius': 50}).svg;

    return SvgPicture.string(svg, width: radius * 2, height: radius * 2);
  }
}
