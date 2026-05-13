"""
extract_sprites.py — нарезает спрайты из spritesheet и сохраняет с alpha-каналом.
Запуск: python3 extract_sprites.py
"""

from PIL import Image, ImageFilter
import os

SRC  = "ChatGPT Image May 12, 2026, 11_10_27 AM.png"
OUT  = "."   # папка вывода

# ──────────────────────────────────────────────────────────────────
# Координаты спрайтов (x1,y1,x2,y2) — найдены авто-детектором
# ──────────────────────────────────────────────────────────────────
SPRITES = {
    # Главная панель (полная) — используется как panel_bg
    "panel_bg":          (27,  39, 1512, 389),

    # Кольцо здоровья (левое, розовое)
    "health_ring":       (27,  39,  419, 366),

    # Кольцо патронов (правое, голубое)
    "ammo_ring":         (620, 45,  959, 388),

    # Радар (большой круг, бирюзовый)
    "radar":             (25,  402, 289, 725),

    # Objective box (прямоугольник с розовым бордером)
    "objective_panel":   (490, 540, 899, 659),

    # Угловые скобки (декоративные L-уголки, розово-cyan)
    "corner_brackets":   (960, 40, 1199, 279),

    # Винтовка (голубой 3D-рендер)
    "weapon_panel":      (1128, 601, 1519, 874),

    # Маленький круг внизу слева (второй радар / ammo inner)
    "circle_small":      (27,  760,  289, 999),

    # Три hex-слота — каждый отдельно
    "slot_hex_1":        (320, 734,  479, 894),  # нормальный
    "slot_hex_2":        (499, 730,  659, 886),  # нормальный
    "slot_hex_active":   (660, 730,  849, 885),  # активный (ярче)

    # Декоративные горизонтальные полоски (правая колонка)
    "deco_bars_top":     (1157, 402, 1486, 438),
    "deco_bars_mid":     (1124, 477, 1529, 578),
    "deco_bars_bot":     (1124, 882, 1529, 979),
}

# ──────────────────────────────────────────────────────────────────
# Конвертация чёрного фона → прозрачность
# Для каждого пикселя: alpha = clamp(яркость / порог * 255)
# Это сохраняет полутона glow-эффектов
# ──────────────────────────────────────────────────────────────────
def black_to_alpha(img_rgb, soft_threshold=18, hard_threshold=6):
    """
    soft_threshold: пиксели суммой RGB < этого — полностью прозрачные
    hard_threshold: нижний порог (шум)
    Плавный переход между порогами сохраняет glow-gradient.
    """
    img_rgb = img_rgb.convert("RGB")
    w, h = img_rgb.size
    rgba = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    src_px  = img_rgb.load()
    dst_px  = rgba.load()

    for y in range(h):
        for x in range(w):
            r, g, b = src_px[x, y]
            brightness = r + g + b   # 0..765

            if brightness <= hard_threshold * 3:
                alpha = 0
            elif brightness <= soft_threshold * 3:
                # плавный переход
                t = (brightness - hard_threshold * 3) / ((soft_threshold - hard_threshold) * 3)
                alpha = int(t * 255)
            else:
                alpha = 255

            dst_px[x, y] = (r, g, b, alpha)

    return rgba


def extract(src_path):
    img = Image.open(src_path).convert("RGB")
    print(f"Исходник: {img.size}")
    print()

    for name, (x1, y1, x2, y2) in SPRITES.items():
        crop  = img.crop((x1, y1, x2, y2))
        rgba  = black_to_alpha(crop)

        out_path = os.path.join(OUT, f"{name}.png")
        rgba.save(out_path)

        # Проверяем что есть непрозрачные пиксели
        px = rgba.load()
        max_a = max(px[x,y][3] for y in range(rgba.height) for x in range(rgba.width))
        print(f"  {name:<20} {x2-x1}x{y2-y1}px  →  {name}.png  max_alpha={max_a}")

    print()
    print("Готово.")


if __name__ == "__main__":
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    extract(SRC)
