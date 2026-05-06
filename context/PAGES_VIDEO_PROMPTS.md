# Prompty pro AI video / poster — AmbiLight landing



Stránka očekává `tools/pages_assets/hero.webm` (+ `hero.mp4`) a poster `hero-poster.png` / `.webp`.  

Vše **bez textu, bez log**, bez vodoznaků. Styl: čistá prémiová produktová estetika (Apple-like), ne „gaming rainbow“.



---



## Koncept (přečti generátoru jako kontext — česky)



**Co má výstup znamenat:** Na monitoru běží **krátké video z přírody** (les, horizont, voda, mraky…), které je **navržené jako seamless loop** — na konci stejného klipu musí být vizuálně kontinuální návrat na začátek (stejná kompozice, podobné světlo, žádný skok střihu).



**Ambilight / bias světlo za monitorem:** Světlo **nesvítí „náhodně“** ani podle abstraktního předelu. Musí vypadat, že **vzniká za panelem** a **na stěnu promítá barvy odvozené od obrazu na displayi** — konkrétně od **okrajů obrazu** (jako když systém bere vzorky pixelů podél levého, horního a pravého okraje — spodek často u stolu neřešíme, ale nahoře a do stran ano).



- **Levá polovina stěny za monitorem vlevo** → dominantní tóny z **levého okraje** videa (např. zeleň kmene, teplý sunlight).  

- **Horní oblouk za horní hranou panelu** → barvy z **horního okraje** videa (obloha, koruny, odlesky).  

- **Pravá strana** → barvy z **pravého okraje** videa (stín, modrá obloha, voda…).



**Důležité:** Jasný obsah je **na samotném videu uvnitř rámu monitoru**; **světlo na stěně je sekundární, měkké, difúzní**, ale **jeho odstíny musí logicky „sedět“** s tím, co je na příslušné straně obrazovky — divák musí **nezávisle pochopit**, že halo **rozšiřuje pole obrazu**, ne že je to nesouvisející RGB výplň.



**Přesnost „jen okraj“ (kritické):** Barvy na stěně za monitorem mají odpovídat **výhradně úzkému pruhu pixelů podél příslušného okraje obrazu** (typicky vnějších ~5–10 % šířky/výšky obrazu u té hrany) — **nesmí** vznikat směsicí barev ze **středu** obrazu ani „obecné“ palety scény. Levá stěna = jen vzorky z **levého** okraje, pravá = jen z **pravého**, horní oblouk = jen z **horního** okraje. Jinak to nevypadá jako reálný Ambilight.



**Interiér a úhel kamery:** Každý výstup může být v **jiném moderním interiéru** (Skandinávsko, loft, Japandi…) a z **jiného úhlu** — důležité je zachovat fyzikální logiku halo vs. okraje obrazovky.



**Na monitoru nesmí být:** operační systém, okna aplikací, kurzor, titulky, vodoznak generátoru, čitelný text.



---



## Master brief — EN (vlož jako systém / style prompt)



```text

TASK: Create a premium 16:9 cinematic clip (8–15s) OR a single hero still for an open-source app called AmbiLight — bias lighting behind a monitor that tracks on-screen colors.



SCENE: Dark minimalist room, slim-bezel monitor on a clean stand, matte textured wall behind. The MONITOR SCREEN shows high-quality NATURE footage only (forest path, ocean horizon, clouds over hills, etc.) — full-frame video fill, no OS chrome, no UI, no text, no logos, no faces.



THE NATURE VIDEO must be designed as a SEAMLESS LOOP: first and last frame must match in composition, lighting, and motion phase so the clip can repeat forever without a visible jump (slow drift, gentle waves, subtle wind in leaves — avoid hard cuts inside the loop).

AMBIENT LIGHT ON THE WALL (behind the monitor): soft wide halo projected onto the wall — clearly originating BEHIND the panel, NOT random RGB. The glow MUST be CHROMATICALLY CONSISTENT with the NATURE VIDEO along each edge:

- wall wash on the LEFT matches colors sampled from the LEFT edge of the on-screen nature frame;

- TOP arc matches the TOP edge colors (sky, foliage highlights);

- RIGHT side matches the RIGHT edge colors (shadows, water, cooler tones).

STRICT PERIMETER SAMPLING: Wall glow must NOT be tinted by colors from the CENTER of the image. Only sample from a thin outer band (~5–10% of frame width/height) along each bezel-aligned edge — left spill ONLY from that left strip, right spill ONLY from right strip, top ONLY from top strip. No unrelated rainbow gradients.

INTERIOR & CAMERA: Each shot may use a different tasteful modern interior (Scandinavian, loft, Japandi, etc.) and a different camera angle — maintain physically plausible bias-light behavior vs. screen edges.

The wall light should feel like it EXTENDS the visual field beyond the bezel while the screen remains the primary subject.



MOOD: Apple product-film cleanliness, photoreal HDR, restrained saturation, shallow depth of field optional.

OUTPUT: no audio track for web delivery.

```



**Negativní prompt (EN):**



```text

operating system UI, desktop, taskbar, window chrome, mouse cursor, subtitles, watermark, logo, readable text,

random unrelated rainbow backlight not matching screen edges, oversaturated neon gamer RGB, harsh strobing,

cartoon, low resolution, crowds, identifiable face, brand logos on bezel

```



---



## Varianta A — doporučený hero prompt (EN, jeden blok pro video)



```text

Photoreal night interior, single ultrawide monitor, nature documentary footage playing fullscreen on the display — slow seamless-loop golden-hour forest with green canopy and warm sun patches drifting slowly (loop-perfect first=last frame). Behind the monitor, soft bias lighting on dark matte wall: left glow pulls yellow-green from trees at left edge of the video frame; top glow warm sky and leaf highlights from top edge; right glow cooler shadow blues from right edge — physically plausible color bleed expanding the image beyond the bezel. No UI on screen. Cinematic HDR, 24fps feel, 16:9, calm premium tech aesthetic.

```



---



## Varianta B — voda / horizont (dobré pro loop)



```text

Same room setup. Monitor shows seamless-loop calm ocean at sunset: gentle waves, horizon stable, warm orange-pink band low, cooler blue above — loop without splash jumps. Wall backlight: bottom-left warm sunset from lower-left screen edge, top cyan-blue from sky strip, right side deeper blue-green from water — strictly derived from screen perimeter colors. No text, no logos, photoreal, 16:9.

```



---



## Varianta C — statický poster (EN pro image model)



```text

Single hero photograph, same Ambilight logic: monitor displays one frame of nature video (forest golden hour), wall behind shows soft halo matching left/top/right edge colors of that exact frame, extending mood beyond bezel. Dark room, minimal stand, no UI, no text, Apple-clean marketing still, 16:9 composition.

```



---



## Post-process (FFmpeg)



- Ořez **16∶9**, export **1920×1080** nebo menší pro výkon.

- **WebM:** `ffmpeg -i hero.mp4 -c:v libvpx-vp9 -b:v 0 -crf 35 -an -vf scale=1920:1080 hero.webm`

- **MP4 (Safari):** `-c:v libx264 -pix_fmt yuv420p -movflags +faststart`

- **Bez audia** (`-an`).

- **Poster:** exportovat jeden frame ve chvíli, kde je loop vizuálně reprezentativní (často prostředek klipu).



---



## Checklist



- [ ] Loop: poslední snímek navazuje na první bez skoku  

- [ ] Barvy na stěně **odpovídají okrajům** obrazu na monitoru (ne náhodný přechod)  

- [ ] Na screenu jen příroda — žádné UI / text  

- [ ] Velikost souboru rozumná pro Pages (~pod 8 MB pro hero video)


