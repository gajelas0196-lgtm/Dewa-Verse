import 'package:flutter/material.dart';

// 🔥 GLOBAL CONTROLLER UNTUK MODE 3D / BASIC 🔥
final ValueNotifier<bool> is3DModeNotifier = ValueNotifier<bool>(false);

// Fungsi helper untuk mempermudah akses
bool get is3DMode => is3DModeNotifier.value;

// Fungsi untuk mengubah mode
void toggle3DMode(bool value) {
  is3DModeNotifier.value = value;
}