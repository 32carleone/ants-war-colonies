#!/usr/bin/env python3
"""Uygulama ikonu üretimi.

Kaynak: assets/ant_lineart.png — referans stok çizimden bir kez türetilmiş
BEYAZ karınca çizgi maskesi (kaligrafik incelik/kalınlık birebir, sağ taraf
sol yarının aynasıyla tamamlanmış, filigran temizlenmiş, eşit kalınlaştırılmış).

Bu betik maskeyi ALTIN/YEŞİL (menüdeki MULTIPLAYER ve SAVAŞ butonlarının
tonları) kıvrımlı bölünmüş zemine basar ve
assets/icon.png yazar. Sonra:
  dart run flutter_launcher_icons   (+ web ikonları sips ile 192/512/32)
"""
import math
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'assets', 'ant_lineart.png')
DST = os.path.join(ROOT, 'assets', 'icon.png')

WHITE = (255, 255, 255)   # karınca çizgisi
ORANGE = (203, 146, 39)   # sol zemin: MULTIPLAYER altını (0xCB9227)
PURPLE = (94, 133, 44)    # sağ zemin: SAVAŞ yeşili (74A038↔4E6B26 arası)

mask = Image.open(SRC).convert('L')
S = mask.size[0]

# Zemin: altın/yeşil, MERKEZDE dengeli kıvrımlı ayrım hattı.
canvas = Image.new('RGB', (S, S), ORANGE)
cpx = canvas.load()
for y in range(S):
    t = y / S * 2 * math.pi
    split = (S / 2
             + 34 * math.sin(t * 2.0 + 1.2)
             + 22 * math.sin(t * 3.0 + 3.9)
             + 12 * math.sin(t * 5.0 + 0.4))
    xi = int(split)
    frac = split - xi
    for x in range(max(0, xi), S):
        cpx[x, y] = PURPLE
    if 0 <= xi < S:
        cpx[xi, y] = tuple(
            int(ORANGE[i] * (1 - frac) + PURPLE[i] * frac) for i in range(3))

white = Image.new('RGB', (S, S), WHITE)
canvas.paste(white, (0, 0), mask)
canvas.save(DST)
print(f'icon yazildi: {DST}')
