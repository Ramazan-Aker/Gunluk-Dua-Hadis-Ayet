"""Her Gün İslam için mağazaya yüklenebilir tanıtım görselleri üretir.

Kaynak emülatör görüntülerindeki Android sistem çubuklarını kırpar, uygulama
arayüzünü bozmadan marka arka planına yerleştirir ve her mağaza için ayrı ZIP
ile önizleme sayfası oluşturur.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[1]
ASSET_ROOT = ROOT / "store_assets" / "screenshots"
SOURCE_ROOT = ASSET_ROOT / "source"
BACKGROUND_PATH = ASSET_ROOT / "brand_background.png"
ICON_PATH = ROOT / "store_assets" / "play_store_icon_512.png"

FONT_REGULAR = Path(r"C:\Windows\Fonts\segoeui.ttf")
FONT_SEMIBOLD = Path(r"C:\Windows\Fonts\seguisb.ttf")
FONT_BOLD = Path(r"C:\Windows\Fonts\segoeuib.ttf")

NAVY = "#002542"
DEEP_NAVY = "#00192F"
GOLD = "#D5A94E"
IVORY = "#F7F5EF"
MINT = "#A9E8D8"
MAX_FILE_SIZE = 8 * 1024 * 1024


@dataclass(frozen=True)
class Screen:
    source: str
    slug: str
    title: str
    watch_focus_y: float


SCREENS = (
    Screen("01_home.png", "ana_sayfa", "Her güne manevi\nbir başlangıç", 0.20),
    Screen("02_prayer.png", "namaz_vakitleri", "Namaz vakitleri\nher şehirde yanında", 0.23),
    Screen("03_quran.png", "kuran", "Kur’an’ı oku, dinle\nve takip et", 0.24),
    Screen("04_daily_plan.png", "gunluk_plan", "Hedeflerini tamamla,\nserini büyüt", 0.24),
    Screen("05_share.png", "mesaj_paylasimi", "Mesajını tasarla\nve paylaş", 0.36),
    Screen("06_religious_days.png", "dini_gunler", "Dini günleri\nkolayca takip et", 0.24),
    Screen("07_widgets.png", "widgetlar", "Widget’larla\nher an yanında", 0.78),
)


@dataclass(frozen=True)
class StoreSpec:
    name: str
    size: tuple[int, int]
    layout: str
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
    quality: int = 95
    headline_center_x: int | None = None
    screenshot_center_x: int | None = None


SPECS = (
    StoreSpec(
        name="google_play_phone_1080x1920",
        size=(1080, 1920),
        layout="stacked",
        screenshot_top=315,
        screenshot_bottom=1892,
        max_screenshot_width=775,
        brand_y=43,
        brand_size=25,
        title_y=102,
        title_size=56,
        title_spacing=4,
        radius=48,
        shadow_radius=28,
    ),
    StoreSpec(
        name="app_store_iphone_65_1242x2688",
        size=(1242, 2688),
        layout="stacked",
        screenshot_top=425,
        screenshot_bottom=2648,
        max_screenshot_width=1045,
        brand_y=66,
        brand_size=31,
        title_y=145,
        title_size=73,
        title_spacing=7,
        radius=58,
        shadow_radius=38,
    ),
    StoreSpec(
        name="app_store_ipad_13_2064x2752",
        size=(2064, 2752),
        layout="side",
        screenshot_top=235,
        screenshot_bottom=2550,
        max_screenshot_width=1120,
        brand_y=315,
        brand_size=35,
        title_y=610,
        title_size=68,
        title_spacing=11,
        radius=66,
        shadow_radius=46,
        headline_center_x=410,
        screenshot_center_x=1435,
    ),
)

ZIP_NAMES = {
    "google_play_phone_1080x1920": "Her_Gun_Islam_Google_Play_1080x1920.zip",
    "app_store_iphone_65_1242x2688": "Her_Gun_Islam_App_Store_iPhone_65_1242x2688.zip",
    "app_store_ipad_13_2064x2752": "Her_Gun_Islam_App_Store_iPad_13_2064x2752.zip",
    "app_store_watch_ultra3_422x514": "Her_Gun_Islam_App_Store_Watch_422x514.zip",
}


def font(path: Path, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(path if path.exists() else FONT_REGULAR), size=size)


def cover(image: Image.Image, size: tuple[int, int], centering=(0.5, 0.5)) -> Image.Image:
    return ImageOps.fit(
        image.convert("RGB"),
        size,
        method=Image.Resampling.LANCZOS,
        centering=centering,
    )


def crop_android_system_ui(image: Image.Image) -> Image.Image:
    """1080×2400 emülatörün durum ve hareket çubuklarını kaldırır."""

    top = round(image.height * 0.045)
    bottom = round(image.height * 0.971)
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
    bbox = draw.multiline_textbbox((0, 0), text, font=text_font, spacing=spacing, align="center")
    width = bbox[2] - bbox[0]
    height = bbox[3] - bbox[1]
    x = center_x - width / 2
    draw.multiline_text((x, y), text, font=text_font, fill=fill, spacing=spacing, align="center")
    return (round(x), y, round(x + width), y + height)


def paste_logo(canvas: Image.Image, center: tuple[int, int], size: int) -> None:
    icon = Image.open(ICON_PATH).convert("RGB").resize((size, size), Image.Resampling.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
    x = center[0] - size // 2
    y = center[1] - size // 2
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    layer.paste(icon.convert("RGBA"), (x, y), mask)
    canvas.alpha_composite(layer)
    ImageDraw.Draw(canvas).ellipse(
        (x - 2, y - 2, x + size + 1, y + size + 1),
        outline=(213, 169, 78, 225),
        width=max(2, size // 35),
    )


def add_header_veil(canvas: Image.Image, bottom: int, alpha: int) -> None:
    veil = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(veil)
    draw.rectangle((0, 0, canvas.width, bottom), fill=(0, 18, 35, alpha))
    canvas.alpha_composite(veil)


def paste_rounded_screenshot(canvas: Image.Image, screenshot: Image.Image, spec: StoreSpec) -> None:
    available_height = spec.screenshot_bottom - spec.screenshot_top
    scale = min(spec.max_screenshot_width / screenshot.width, available_height / screenshot.height)
    size = (round(screenshot.width * scale), round(screenshot.height * scale))
    screenshot = screenshot.resize(size, Image.Resampling.LANCZOS)

    center_x = spec.screenshot_center_x or spec.size[0] // 2
    x = center_x - size[0] // 2
    y = spec.screenshot_top + (available_height - size[1]) // 2

    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=spec.radius, fill=255)

    shadow = Image.new("RGBA", spec.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (x - 8, y + 18, x + size[0] + 8, y + size[1] + 30),
        radius=spec.radius + 7,
        fill=(0, 10, 24, 170),
    )
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(spec.shadow_radius)))

    layer = Image.new("RGBA", spec.size, (0, 0, 0, 0))
    layer.paste(screenshot.convert("RGBA"), (x, y), mask)
    canvas.alpha_composite(layer)
    ImageDraw.Draw(canvas).rounded_rectangle(
        (x, y, x + size[0] - 1, y + size[1] - 1),
        radius=spec.radius,
        outline=(213, 169, 78, 225),
        width=max(3, spec.size[0] // 430),
    )


def build_store_image(screen: Screen, spec: StoreSpec) -> Image.Image:
    background = cover(Image.open(BACKGROUND_PATH), spec.size, centering=(0.5, 0.52)).convert("RGBA")
    draw = ImageDraw.Draw(background)
    headline_center_x = spec.headline_center_x or spec.size[0] // 2

    if spec.layout == "side":
        panel = Image.new("RGBA", spec.size, (0, 0, 0, 0))
        ImageDraw.Draw(panel).rounded_rectangle(
            (55, 105, 775, spec.size[1] - 105),
            radius=72,
            fill=(0, 25, 47, 226),
            outline=(213, 169, 78, 205),
            width=4,
        )
        background.alpha_composite(panel)
        paste_logo(background, (headline_center_x, 235), 126)
    else:
        add_header_veil(background, spec.screenshot_top + 22, 82)
        paste_logo(background, (headline_center_x - 115, spec.brand_y + 16), 50 if spec.size[0] < 1200 else 60)

    draw = ImageDraw.Draw(background)
    brand_font = font(FONT_SEMIBOLD, spec.brand_size)
    title_font = font(FONT_BOLD, spec.title_size)
    brand = "HER GÜN İSLAM"
    brand_bbox = draw.textbbox((0, 0), brand, font=brand_font)
    brand_width = brand_bbox[2] - brand_bbox[0]
    brand_center_x = headline_center_x + (22 if spec.layout != "side" else 0)
    draw.text((brand_center_x - brand_width / 2, spec.brand_y), brand, font=brand_font, fill=GOLD)

    title_bbox = draw_centered_multiline(
        draw,
        screen.title,
        headline_center_x,
        spec.title_y,
        title_font,
        IVORY,
        spec.title_spacing,
    )
    line_width = 126 if spec.layout == "side" else round(spec.size[0] * 0.095)
    line_y = title_bbox[3] + round(spec.title_size * (0.62 if spec.layout == "side" else 0.28))
    if spec.layout != "side":
        line_y = min(spec.screenshot_top - 24, line_y)
    draw.rounded_rectangle(
        (headline_center_x - line_width // 2, line_y, headline_center_x + line_width // 2, line_y + max(4, spec.size[0] // 300)),
        radius=5,
        fill=GOLD,
    )

    source = crop_android_system_ui(Image.open(SOURCE_ROOT / screen.source))
    paste_rounded_screenshot(background, source, spec)
    return background.convert("RGB")


def build_watch_image(screen: Screen) -> Image.Image:
    size = (422, 514)
    background = cover(Image.open(BACKGROUND_PATH), size, centering=(0.5, 0.48)).convert("RGBA")
    add_header_veil(background, 126, 112)
    paste_logo(background, (31, 30), 34)

    draw = ImageDraw.Draw(background)
    brand_font = font(FONT_SEMIBOLD, 10)
    title_font = font(FONT_BOLD, 22)
    draw.text((55, 18), "HER GÜN İSLAM", font=brand_font, fill=GOLD)
    title_bbox = draw_centered_multiline(draw, screen.title, size[0] // 2, 45, title_font, IVORY, 2)
    line_y = min(116, title_bbox[3] + 7)
    draw.rounded_rectangle((190, line_y, 232, line_y + 3), radius=2, fill=GOLD)

    frame = (20, 126, 402, 500)
    frame_size = (frame[2] - frame[0], frame[3] - frame[1])
    source = crop_android_system_ui(Image.open(SOURCE_ROOT / screen.source))
    screenshot = ImageOps.fit(
        source,
        frame_size,
        method=Image.Resampling.LANCZOS,
        centering=(0.5, screen.watch_focus_y),
    ).convert("RGBA")

    shadow = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (frame[0] - 3, frame[1] + 6, frame[2] + 3, frame[3] + 9),
        radius=25,
        fill=(0, 12, 25, 170),
    )
    background.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(11)))

    mask = Image.new("L", frame_size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, frame_size[0] - 1, frame_size[1] - 1), radius=23, fill=255)
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    layer.paste(screenshot, (frame[0], frame[1]), mask)
    background.alpha_composite(layer)
    ImageDraw.Draw(background).rounded_rectangle(frame, radius=23, outline=(213, 169, 78, 230), width=2)
    return background.convert("RGB")


def clean_jpegs(directory: Path) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    for path in directory.glob("*.jpg"):
        path.unlink()


def save_jpeg(image: Image.Image, output: Path, quality: int = 95) -> None:
    image.convert("RGB").save(
        output,
        "JPEG",
        quality=quality,
        subsampling=0,
        optimize=True,
        progressive=True,
    )


def build_contact_sheet(name: str, outputs: list[Path], thumb_size: tuple[int, int]) -> Path:
    columns = 4
    rows = 2
    gap = 24
    sheet_size = (columns * thumb_size[0] + (columns + 1) * gap, rows * thumb_size[1] + (rows + 1) * gap)
    sheet = Image.new("RGB", sheet_size, DEEP_NAVY)
    for index, path in enumerate(outputs):
        thumb = Image.open(path).convert("RGB").resize(thumb_size, Image.Resampling.LANCZOS)
        x = gap + (index % columns) * (thumb_size[0] + gap)
        y = gap + (index // columns) * (thumb_size[1] + gap)
        sheet.paste(thumb, (x, y))
    output = ASSET_ROOT / f"preview_{name}.jpg"
    save_jpeg(sheet, output, 92)
    return output


def make_zip(name: str, outputs: list[Path]) -> Path:
    output = ASSET_ROOT / ZIP_NAMES[name]
    with ZipFile(output, "w", ZIP_DEFLATED, compresslevel=9) as archive:
        for path in outputs:
            archive.write(path, arcname=path.name)
    return output


def validate_set(name: str, size: tuple[int, int], outputs: list[Path]) -> None:
    if len(outputs) != len(SCREENS):
        raise RuntimeError(f"{name}: {len(SCREENS)} yerine {len(outputs)} görsel üretildi")
    for path in outputs:
        with Image.open(path) as image:
            if image.size != size:
                raise RuntimeError(f"{path.name}: {image.size}, beklenen {size}")
            if image.mode != "RGB":
                raise RuntimeError(f"{path.name}: RGB değil ({image.mode})")
        if path.stat().st_size > MAX_FILE_SIZE:
            raise RuntimeError(f"{path.name}: 8 MB sınırını aşıyor")


def write_readme() -> None:
    content = """# Her Gün İslam mağaza görselleri

Bu klasörde yedi güncel uygulama ekranından üretilen yüklemeye hazır setler bulunur.

- `google_play_phone_1080x1920`: Google Play telefon görselleri
- `app_store_iphone_65_1242x2688`: App Store iPhone 6.5 inç görselleri
- `app_store_ipad_13_2064x2752`: App Store iPad 13 inç görselleri
- `app_store_watch_ultra3_422x514`: 422×514 Apple Watch tanıtım kartları

Her klasör yedi RGB JPEG içerir. Klasörlerin ZIP karşılıkları doğrudan mağaza
yüklemesi için hazırlanmıştır. Watch seti gerçek Watch uygulama arayüzü değil,
telefon ekranlarından oluşturulan tanıtım kartlarıdır.
"""
    (ASSET_ROOT / "README.md").write_text(content, encoding="utf-8")


def main() -> None:
    for required in [BACKGROUND_PATH, ICON_PATH, *[SOURCE_ROOT / screen.source for screen in SCREENS]]:
        if not required.exists():
            raise FileNotFoundError(required)

    all_outputs: dict[str, list[Path]] = {}
    for spec in SPECS:
        output_dir = ASSET_ROOT / spec.name
        clean_jpegs(output_dir)
        outputs: list[Path] = []
        for index, screen in enumerate(SCREENS, start=1):
            output = output_dir / f"{index:02d}_{screen.slug}.jpg"
            save_jpeg(build_store_image(screen, spec), output, spec.quality)
            outputs.append(output)
            print(f"{output.relative_to(ROOT)}: {spec.size} RGB")
        validate_set(spec.name, spec.size, outputs)
        all_outputs[spec.name] = outputs

    watch_name = "app_store_watch_ultra3_422x514"
    watch_dir = ASSET_ROOT / watch_name
    clean_jpegs(watch_dir)
    watch_outputs: list[Path] = []
    for index, screen in enumerate(SCREENS, start=1):
        output = watch_dir / f"{index:02d}_{screen.slug}.jpg"
        save_jpeg(build_watch_image(screen), output)
        watch_outputs.append(output)
        print(f"{output.relative_to(ROOT)}: (422, 514) RGB")
    validate_set(watch_name, (422, 514), watch_outputs)
    all_outputs[watch_name] = watch_outputs

    preview_sizes = {
        "google_play_phone_1080x1920": (270, 480),
        "app_store_iphone_65_1242x2688": (231, 500),
        "app_store_ipad_13_2064x2752": (375, 500),
        watch_name: (211, 257),
    }
    for name, outputs in all_outputs.items():
        preview = build_contact_sheet(name, outputs, preview_sizes[name])
        archive = make_zip(name, outputs)
        print(f"{preview.relative_to(ROOT)} oluşturuldu")
        print(f"{archive.relative_to(ROOT)} oluşturuldu")

    write_readme()
    print("Tüm mağaza setleri doğrulandı.")


if __name__ == "__main__":
    main()
