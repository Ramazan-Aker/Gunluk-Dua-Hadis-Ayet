"""Her Gün İslam mağaza ekran görüntüsü setlerini üretir.

Kaynak emulator ekranlarını değiştirmez; Android sistem çerçevesini kırpar,
marka arka planına orantılı biçimde yerleştirir ve RGB JPEG olarak kaydeder.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[1]
ASSET_ROOT = ROOT / "store_assets" / "screenshots"
SOURCE_ROOT = ASSET_ROOT / "source"
BACKGROUND_PATH = ASSET_ROOT / "brand_background.png"

FONT_REGULAR = Path(r"C:\Windows\Fonts\segoeui.ttf")
FONT_SEMIBOLD = Path(r"C:\Windows\Fonts\seguisb.ttf")
FONT_BOLD = Path(r"C:\Windows\Fonts\segoeuib.ttf")

NAVY = "#002542"
GOLD = "#D5A94E"
IVORY = "#F7F5EF"


@dataclass(frozen=True)
class Screen:
    source: str
    slug: str
    title: str
    alt_text: str


SCREENS = (
    Screen(
        "01_home.png",
        "ana_sayfa",
        "Her güne manevi\nbir başlangıç",
        "Günün duası, namaz ve Kur’an kısayollarının bulunduğu ana sayfa.",
    ),
    Screen(
        "02_quran.png",
        "kuran",
        "Kur’an’ı oku, dinle\nve takip et",
        "Sure arama, sesli hatim, cüzler ve kaldığın yer özellikli Kur’an ekranı.",
    ),
    Screen(
        "03_prayer.png",
        "namaz_vakitleri",
        "Namaz vakitleri\nher şehirde yanında",
        "Birden fazla şehir, sonraki vakit sayacı ve günlük namaz vakitleri ekranı.",
    ),
    Screen(
        "04_messages.png",
        "mesajlar",
        "Anlamlı mesajlar,\nsana özel",
        "Favoriler, son kullanılanlar ve farklı dini mesaj kategorileri ekranı.",
    ),
    Screen(
        "05_religious_days.png",
        "dini_gunler",
        "Dini günleri\nkolayca takip et",
        "Yaklaşan kandil ve dini günleri geri sayımla gösteren takvim ekranı.",
    ),
    Screen(
        "06_share.png",
        "paylasim",
        "Mesajını görselleştir\nve paylaş",
        "Mesaj görseli önizleme, düzenleme ve farklı biçimlerde paylaşma ekranı.",
    ),
)


@dataclass(frozen=True)
class StoreSpec:
    name: str
    size: tuple[int, int]
    screenshot_top: int
    screenshot_bottom: int
    max_screenshot_width: int
    brand_y: int
    brand_size: int
    title_y: int
    title_size: int
    title_spacing: int
    radius: int
    shadow_radius: int
    quality: int
    layout: str = "stacked"
    headline_center_x: int | None = None
    screenshot_center_x: int | None = None


SPECS = (
    StoreSpec(
        name="google_play_phone_1080x1920",
        size=(1080, 1920),
        screenshot_top=300,
        screenshot_bottom=1885,
        max_screenshot_width=820,
        brand_y=52,
        brand_size=25,
        title_y=105,
        title_size=56,
        title_spacing=5,
        radius=46,
        shadow_radius=28,
        quality=95,
    ),
    StoreSpec(
        name="app_store_iphone_65_1242x2688",
        size=(1242, 2688),
        screenshot_top=425,
        screenshot_bottom=2635,
        max_screenshot_width=1070,
        brand_y=75,
        brand_size=30,
        title_y=145,
        title_size=73,
        title_spacing=8,
        radius=56,
        shadow_radius=36,
        quality=95,
    ),
    StoreSpec(
        name="app_store_iphone_69_1320x2868",
        size=(1320, 2868),
        screenshot_top=455,
        screenshot_bottom=2810,
        max_screenshot_width=1140,
        brand_y=80,
        brand_size=32,
        title_y=155,
        title_size=78,
        title_spacing=8,
        radius=60,
        shadow_radius=38,
        quality=95,
    ),
    StoreSpec(
        name="app_store_ipad_13_2064x2752",
        size=(2064, 2752),
        screenshot_top=130,
        screenshot_bottom=2620,
        max_screenshot_width=1210,
        brand_y=260,
        brand_size=34,
        title_y=545,
        title_size=66,
        title_spacing=12,
        radius=64,
        shadow_radius=45,
        quality=95,
        layout="side",
        headline_center_x=410,
        screenshot_center_x=1435,
    ),
)


def font(path: Path, size: int) -> ImageFont.FreeTypeFont:
    candidate = path if path.exists() else FONT_REGULAR
    return ImageFont.truetype(str(candidate), size=size)


def cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    return ImageOps.fit(
        image.convert("RGB"),
        size,
        method=Image.Resampling.LANCZOS,
        centering=(0.5, 0.5),
    )


def crop_android_system_ui(image: Image.Image) -> Image.Image:
    """Emülatör kamera deliği ve alt gezinme çubuğunu kaldırır."""

    top = round(image.height * 0.044)
    bottom = round(image.height * 0.973)
    return image.crop((0, top, image.width, bottom)).convert("RGB")


def draw_centered_multiline(
    draw: ImageDraw.ImageDraw,
    text: str,
    center_x: int,
    y: int,
    text_font: ImageFont.FreeTypeFont,
    fill: str,
    spacing: int,
) -> tuple[int, int, int, int]:
    bbox = draw.multiline_textbbox(
        (0, 0),
        text,
        font=text_font,
        spacing=spacing,
        align="center",
    )
    width = bbox[2] - bbox[0]
    draw.multiline_text(
        (center_x - width / 2, y),
        text,
        font=text_font,
        fill=fill,
        spacing=spacing,
        align="center",
    )
    return (center_x - width // 2, y, center_x + width // 2, y + bbox[3] - bbox[1])


def paste_rounded_screenshot(
    canvas: Image.Image,
    screenshot: Image.Image,
    spec: StoreSpec,
) -> None:
    available_height = spec.screenshot_bottom - spec.screenshot_top
    scale = min(
        spec.max_screenshot_width / screenshot.width,
        available_height / screenshot.height,
    )
    size = (
        round(screenshot.width * scale),
        round(screenshot.height * scale),
    )
    screenshot = screenshot.resize(size, Image.Resampling.LANCZOS)

    screenshot_center_x = spec.screenshot_center_x or spec.size[0] // 2
    x = screenshot_center_x - size[0] // 2
    y = spec.screenshot_top + (available_height - size[1]) // 2

    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size[0] - 1, size[1] - 1),
        radius=spec.radius,
        fill=255,
    )

    shadow = Image.new("RGBA", spec.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(
        (x - 4, y + 14, x + size[0] + 4, y + size[1] + 24),
        radius=spec.radius + 5,
        fill=(0, 37, 66, 105),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(spec.shadow_radius))
    canvas.alpha_composite(shadow)

    screenshot_layer = Image.new("RGBA", spec.size, (0, 0, 0, 0))
    screenshot_layer.paste(screenshot.convert("RGBA"), (x, y), mask)
    canvas.alpha_composite(screenshot_layer)

    border = ImageDraw.Draw(canvas)
    border.rounded_rectangle(
        (x, y, x + size[0] - 1, y + size[1] - 1),
        radius=spec.radius,
        outline=(213, 169, 78, 205),
        width=max(2, round(spec.size[0] / 540)),
    )


def build_store_image(screen: Screen, spec: StoreSpec) -> Image.Image:
    background = cover(Image.open(BACKGROUND_PATH), spec.size).convert("RGBA")

    if spec.layout == "side":
        # iPad'in 4:3 tuvalini verimli kullanan, metni cihazdan ayıran panel.
        panel = Image.new("RGBA", spec.size, (0, 0, 0, 0))
        panel_draw = ImageDraw.Draw(panel)
        panel_bounds = (55, 105, 765, spec.size[1] - 105)
        panel_draw.rounded_rectangle(
            panel_bounds,
            radius=70,
            fill=(0, 37, 66, 224),
            outline=(213, 169, 78, 190),
            width=4,
        )
        background.alpha_composite(panel)
    else:
        # Başlığın okunurluğunu her arka plan varyasyonunda sabit tutar.
        overlay = Image.new("RGBA", spec.size, (0, 0, 0, 0))
        overlay_draw = ImageDraw.Draw(overlay)
        overlay_draw.rectangle(
            (0, 0, spec.size[0], spec.screenshot_top + 35),
            fill=(0, 24, 45, 50),
        )
        background.alpha_composite(overlay)

    draw = ImageDraw.Draw(background)
    brand_font = font(FONT_SEMIBOLD, spec.brand_size)
    title_font = font(FONT_BOLD, spec.title_size)

    brand = "HER GÜN İSLAM"
    brand_bbox = draw.textbbox((0, 0), brand, font=brand_font)
    brand_width = brand_bbox[2] - brand_bbox[0]
    headline_center_x = spec.headline_center_x or spec.size[0] // 2
    draw.text(
        (headline_center_x - brand_width / 2, spec.brand_y),
        brand,
        font=brand_font,
        fill=GOLD,
    )

    title_bbox = draw_centered_multiline(
        draw,
        screen.title,
        headline_center_x,
        spec.title_y,
        title_font,
        IVORY,
        spec.title_spacing,
    )
    line_width = 120 if spec.layout == "side" else round(spec.size[0] * 0.09)
    line_y = (
        title_bbox[3] + round(spec.title_size * 0.65)
        if spec.layout == "side"
        else min(spec.screenshot_top - 24, title_bbox[3] + round(spec.title_size * 0.28))
    )
    draw.rounded_rectangle(
        (
            headline_center_x - line_width // 2,
            line_y,
            headline_center_x + line_width // 2,
            line_y + max(3, spec.size[0] // 300),
        ),
        radius=5,
        fill=GOLD,
    )

    source = crop_android_system_ui(Image.open(SOURCE_ROOT / screen.source))
    paste_rounded_screenshot(background, source, spec)
    return background.convert("RGB")


def build_contact_sheet(play_outputs: list[Path]) -> Path:
    thumb_size = (360, 640)
    gap = 24
    sheet = Image.new("RGB", (3 * thumb_size[0] + 4 * gap, 2 * thumb_size[1] + 3 * gap), NAVY)
    for index, path in enumerate(play_outputs):
        thumb = Image.open(path).convert("RGB").resize(thumb_size, Image.Resampling.LANCZOS)
        column = index % 3
        row = index // 3
        x = gap + column * (thumb_size[0] + gap)
        y = gap + row * (thumb_size[1] + gap)
        sheet.paste(thumb, (x, y))
    output = ASSET_ROOT / "preview_contact_sheet.jpg"
    sheet.save(output, "JPEG", quality=92, subsampling=0, optimize=True)
    return output


def build_ipad_contact_sheet(ipad_outputs: list[Path]) -> Path:
    thumb_size = (516, 688)
    gap = 28
    sheet = Image.new(
        "RGB",
        (3 * thumb_size[0] + 4 * gap, 2 * thumb_size[1] + 3 * gap),
        NAVY,
    )
    for index, path in enumerate(ipad_outputs):
        thumb = Image.open(path).convert("RGB").resize(thumb_size, Image.Resampling.LANCZOS)
        column = index % 3
        row = index // 3
        x = gap + column * (thumb_size[0] + gap)
        y = gap + row * (thumb_size[1] + gap)
        sheet.paste(thumb, (x, y))
    output = ASSET_ROOT / "preview_ipad_contact_sheet.jpg"
    sheet.save(output, "JPEG", quality=92, subsampling=0, optimize=True)
    return output


def build_watch_image(screen: Screen) -> Image.Image:
    """Gerçek uygulama ekranından Apple Watch mağaza boyutunda tanıtım kartı üretir."""

    size = (422, 514)
    background = cover(Image.open(BACKGROUND_PATH), size).convert("RGBA")
    veil = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(veil).rectangle((0, 0, size[0], 126), fill=(0, 24, 45, 96))
    background.alpha_composite(veil)

    draw = ImageDraw.Draw(background)
    brand_font = font(FONT_SEMIBOLD, 10)
    title_font = font(FONT_BOLD, 21)
    brand = "HER GÜN İSLAM"
    brand_bbox = draw.textbbox((0, 0), brand, font=brand_font)
    draw.text(
        ((size[0] - (brand_bbox[2] - brand_bbox[0])) / 2, 18),
        brand,
        font=brand_font,
        fill=GOLD,
    )
    title_bbox = draw_centered_multiline(
        draw,
        screen.title,
        size[0] // 2,
        42,
        title_font,
        IVORY,
        2,
    )
    line_y = min(112, title_bbox[3] + 7)
    draw.rounded_rectangle((191, line_y, 231, line_y + 3), radius=2, fill=GOLD)

    frame = (22, 124, 400, 500)
    frame_size = (frame[2] - frame[0], frame[3] - frame[1])
    source = crop_android_system_ui(Image.open(SOURCE_ROOT / screen.source))
    # Telefon ekranını bozmaz; mağaza kartında ilgili üst bölümü görünür tutar.
    screenshot = ImageOps.fit(
        source,
        frame_size,
        method=Image.Resampling.LANCZOS,
        centering=(0.5, 0.23),
    ).convert("RGBA")

    shadow = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (frame[0] - 2, frame[1] + 5, frame[2] + 2, frame[3] + 8),
        radius=25,
        fill=(0, 20, 38, 125),
    )
    background.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(10)))

    mask = Image.new("L", frame_size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, frame_size[0] - 1, frame_size[1] - 1),
        radius=23,
        fill=255,
    )
    screenshot_layer = Image.new("RGBA", size, (0, 0, 0, 0))
    screenshot_layer.paste(screenshot, (frame[0], frame[1]), mask)
    background.alpha_composite(screenshot_layer)
    draw = ImageDraw.Draw(background)
    draw.rounded_rectangle(frame, radius=23, outline=(213, 169, 78, 220), width=2)
    return background.convert("RGB")


def build_watch_contact_sheet(watch_outputs: list[Path]) -> Path:
    gap = 18
    size = (422, 514)
    sheet = Image.new(
        "RGB",
        (3 * size[0] + 4 * gap, 2 * size[1] + 3 * gap),
        NAVY,
    )
    for index, path in enumerate(watch_outputs):
        image = Image.open(path).convert("RGB")
        column = index % 3
        row = index // 3
        x = gap + column * (size[0] + gap)
        y = gap + row * (size[1] + gap)
        sheet.paste(image, (x, y))
    output = ASSET_ROOT / "preview_watch_contact_sheet.jpg"
    sheet.save(output, "JPEG", quality=92, subsampling=0, optimize=True)
    return output


def main() -> None:
    play_outputs: list[Path] = []
    ipad_outputs: list[Path] = []
    for spec in SPECS:
        output_dir = ASSET_ROOT / spec.name
        output_dir.mkdir(parents=True, exist_ok=True)
        for index, screen in enumerate(SCREENS, start=1):
            output = output_dir / f"{index:02d}_{screen.slug}.jpg"
            image = build_store_image(screen, spec)
            image.save(
                output,
                "JPEG",
                quality=spec.quality,
                subsampling=0,
                optimize=True,
                progressive=True,
            )
            print(f"{output.relative_to(ROOT)}: {image.size} RGB")
            if spec.name.startswith("google_play"):
                play_outputs.append(output)
            if spec.name.startswith("app_store_ipad"):
                ipad_outputs.append(output)

    preview = build_contact_sheet(play_outputs)
    print(f"{preview.relative_to(ROOT)} oluşturuldu")
    ipad_preview = build_ipad_contact_sheet(ipad_outputs)
    print(f"{ipad_preview.relative_to(ROOT)} oluşturuldu")

    watch_outputs: list[Path] = []
    watch_dir = ASSET_ROOT / "app_store_watch_ultra3_422x514"
    watch_dir.mkdir(parents=True, exist_ok=True)
    for index, screen in enumerate(SCREENS, start=1):
        output = watch_dir / f"{index:02d}_{screen.slug}.jpg"
        image = build_watch_image(screen)
        image.save(
            output,
            "JPEG",
            quality=95,
            subsampling=0,
            optimize=True,
            progressive=True,
        )
        watch_outputs.append(output)
        print(f"{output.relative_to(ROOT)}: {image.size} RGB")
    watch_preview = build_watch_contact_sheet(watch_outputs)
    print(f"{watch_preview.relative_to(ROOT)} oluşturuldu")


if __name__ == "__main__":
    main()
