enum DynamicMapZoomPreset { conservative, balanced, aggressive }

String dynamicMapZoomPresetToStorage(DynamicMapZoomPreset preset) {
  return switch (preset) {
    DynamicMapZoomPreset.conservative => 'conservative',
    DynamicMapZoomPreset.balanced => 'balanced',
    DynamicMapZoomPreset.aggressive => 'aggressive',
  };
}

DynamicMapZoomPreset dynamicMapZoomPresetFromStorage(String? raw) {
  return switch (raw) {
    'conservative' => DynamicMapZoomPreset.conservative,
    'aggressive' => DynamicMapZoomPreset.aggressive,
    _ => DynamicMapZoomPreset.balanced,
  };
}
