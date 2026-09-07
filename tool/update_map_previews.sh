#!/bin/sh
# Harita kartı görselleri = gerçek oyun ekran görüntüleri.
# Haritalar değişince çalıştır:
#   flutter test --update-goldens test/golden_maps_test.dart && sh tool/update_map_previews.sh
set -e
cd "$(dirname "$0")/.."
for f in test/goldens/map_*.png; do
  cp "$f" "assets/images/$(basename "$f")"
done
echo "Harita ön izlemeleri assets/images/ altına kopyalandı."
