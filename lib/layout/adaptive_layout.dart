import 'package:flutter/material.dart';

const kTabletBreakpoint = 600.0;
const kPhoneLayoutWidth = 375.0;
const kPhoneContentWidth = 339.0;
const kPostCarouselAspectRatio = kPhoneLayoutWidth / 400.0;
const kShareCardCoverAspectRatio = kPhoneContentWidth / 88.0;
const kChatImagePhoneSize = 200.0;
const kChatImageMaxSize = 360.0;

bool isTabletLayout(BuildContext context) {
  return MediaQuery.sizeOf(context).shortestSide >= kTabletBreakpoint;
}

Widget adaptiveAspectFrame({
  required BuildContext context,
  required double phoneHeight,
  required Widget child,
  double? widthOverHeight,
}) {
  if (!isTabletLayout(context)) {
    return SizedBox(height: phoneHeight, child: child);
  }
  final ratio = widthOverHeight ?? (kPhoneContentWidth / phoneHeight);
  return AspectRatio(aspectRatio: ratio, child: child);
}

double adaptiveSquareSize(
  BuildContext context, {
  double phoneSize = 200,
  double maxSize = 360,
}) {
  if (!isTabletLayout(context)) return phoneSize;
  final w = MediaQuery.sizeOf(context).width;
  final scaled = phoneSize * (w / kPhoneLayoutWidth);
  return scaled.clamp(phoneSize, maxSize);
}
