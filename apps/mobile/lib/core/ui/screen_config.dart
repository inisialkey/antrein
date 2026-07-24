import 'package:flutter/widgets.dart';

/// The design canvas all `flutter_screenutil` scaling is relative to
/// (iPhone X logical size). Use `.r` for spacing/padding/icons/radii (uniform
/// scale, no aspect distortion) and `.sp` for fonts — not `.w`/`.h` everywhere.
const Size kDesignSize = Size(375, 812);
