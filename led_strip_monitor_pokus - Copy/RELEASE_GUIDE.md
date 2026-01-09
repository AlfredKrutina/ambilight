# Návod na vytvoření release balíčků pro sdílení

## 🎯 Cíl

Vytvořit balíčky pro sdílení aplikace **bez zdrojového kódu Pythonu**. Balíčky obsahují pouze:
- Spustitelné soubory (.exe, .app, executable)
- Dokumentaci (README)
- **ŽÁDNÝ Python source kód**

## 📋 Postup

### 1. Build aplikace

Nejdřív musíte vytvořit distribuční soubory:

```bash
# Na Windows
python build.py

# Na macOS
python build.py

# Na Linux
python build.py
```

Výstup bude v:
- `dist/Windows/AmbiLight_Windows.exe`
- `dist/Mac/AmbiLight_Mac.zip`
- `dist/Linux/AmbiLight_Linux.tar.gz`

### 2. Vytvoření release balíčků

Spusťte skript pro vytvoření release balíčků:

```bash
python create_release.py
```

Tento skript:
- Vezme distribuční soubory z `dist/`
- Přidá README dokumentaci
- Vytvoří ZIP/TAR balíčky v `release/` složce
- **NEPŘIDÁ žádný Python source kód**

### 3. Výstup

V `release/` složce najdete:

- `AmbiLight_Windows_Release.zip`
  - Obsahuje: `AmbiLight_Windows.exe` + README
  - Velikost: ~120-150 MB
  - **Žádný Python kód!**

- `AmbiLight_Mac_Release.zip`
  - Obsahuje: `AmbiLight.app` + README
  - Velikost: ~150-200 MB
  - **Žádný Python kód!**

- `AmbiLight_Linux_Release.tar.gz`
  - Obsahuje: `AmbiLight` executable + resources + config + README
  - Velikost: ~150-200 MB
  - **Žádný Python kód!**

## 📤 Sdílení

Tyto balíčky můžete bezpečně sdílet:
- ✅ Obsahují pouze spustitelné soubory
- ✅ Obsahují dokumentaci
- ✅ **NEobsahují Python source kód**
- ✅ **NEobsahují žádné citlivé informace**

### Kde sdílet:
- Google Drive / OneDrive / Dropbox
- GitHub Releases
- USB flash disk
- Email (pokud je soubor dostatečně malý)

## 🔍 Ověření

Chcete-li ověřit, že balíček neobsahuje source kód:

1. Rozbalte ZIP/TAR soubor
2. Prohledejte obsah - měli byste najít pouze:
   - Spustitelný soubor (.exe, .app, nebo executable)
   - README soubory
   - Resources a config (pokud jsou potřeba)
3. **NEMĚLI byste najít:**
   - Žádné `.py` soubory (kromě těch zabalených v exe)
   - Žádné `src/` složky
   - Žádné `venv/` složky

## ⚠️ Poznámky

- Release balíčky jsou vytvořeny z již zkompilovaných souborů
- Pokud chcete aktualizovat release, musíte znovu spustit `build.py` a pak `create_release.py`
- Každá platforma vyžaduje build na příslušném OS (Windows exe na Windows, Mac app na macOS, atd.)

## 🚀 Rychlý start

```bash
# 1. Build
python build.py

# 2. Vytvořit release balíčky
python create_release.py

# 3. Sdílet soubory z release/ složky
```

Hotovo! 🎉
