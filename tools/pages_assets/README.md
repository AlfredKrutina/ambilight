# Média pro veřejnou landing stránku (GitHub Pages)

Soubory z této složky kopíruje CI do `_site/assets/` při deployi (`firmware_pages` workflow).

## Doporučené soubory (volitelné — stránka má fallback bez nich)

| Soubor | Formát | Účel |
|--------|--------|------|
| `hero-poster.png` nebo `.webp` | PNG/WebP 1920×1080 (16∶9) | **Úvodní hero** + první dlaždice v Ukázce; přírodní scéna na panelu, světlo na stěně podle **okrajů** obrazu — viz `context/PAGES_VIDEO_PROMPTS.md` |
| `hero.webm` | VP9 | Volitelné — úvod je statický obrázek; video jen pokud ho znovu zapneš v HTML |
| `hero.mp4` | H.264 | Volitelné — totéž |
| `showcase-ambilight-wildlife.png` | 16∶9 | Koncept v sekci Ukázka — živočichové, pestré okraje → halo na stěně |
| `showcase-ambilight-cycling.png` | 16∶9 | Koncept — kola / sport, kontrast barev vlevo–vpravo → halo |
| `screenshot-main.webp` | šířka 1600–2400 px | Hlavní okno aplikace (přehled) |
| `screenshot-settings.webp` | stejně | Záložka Nastavení / representative UI |
| `screenshot-devices.webp` | stejně | Zařízení / discovery |
| `screenshot-tray.webp` | stejně | Tray / ikona v liště (malý náhled ve třetím řádku mřížky) |
| `og-cover.webp` | 1200×630 | Volitelně pro sdílení odkazu (do budoucna lze doplnit meta tag s absolutní URL) |

## Jak vyexportovat snímky z AmbiLight desktop

1. Spusť aplikaci v **release** nebo **profilovaném** buildu (hezčí výchozí téma).
2. Okno nastav na rozumnou šířku (např. 1280–1440 px logicky).
3. **Windows:** `Win + Shift + S` nebo Snipping Tool — ulož PNG, pak převeď na WebP (např. `cwebp`, Squoosh).
4. **macOS:** `Cmd + Shift + 4` — stejně export do WebP pro menší velikost.
5. Linux: podle desktopu (GNOME screenshot, Flameshot).

Ukládání **do této složky** (`tools/pages_assets/`) pod výše uvedenými názvy. CI zkopíruje jen `*.webp`, `*.png`, `*.jpg`, `*.jpeg`, `*.webm`, `*.mp4`, `*.svg` (ne tento README).

## Video

Prompty pro AI generátory videa jsou v [`context/PAGES_VIDEO_PROMPTS.md`](../../context/PAGES_VIDEO_PROMPTS.md).

Export: krátká smyčka, **bez hudby** v souboru (muted autoplay), rozlišení max 1920×1080, komprimovaný bitrate aby Pages nebyly těžké.
