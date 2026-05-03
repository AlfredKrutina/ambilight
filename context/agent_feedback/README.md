# Feedback od paralelních agentů

## Účel

Všichni agenti (A0–A8) běží **paralelně**. Aby koordinátor (ty + hlavní asistent) měl pravdu o stavu **bez čtení celého diffu**, každý agent na **konci své práce** zapíše feedback do souboru podle níže uvedené konvence.

## Povinná konvence

1. **Jeden soubor na běh agenta:** `FEEDBACK_Ax.md` kde `x` je `0`–`8` (např. `FEEDBACK_A3.md`).
2. Pokud agent běží **opakovaně**, přepiš stejný soubor **nebo** přidej sekci `## Běh YYYY-MM-DD HH:mm` nahoře (novější nahoře).
3. Šablona obsahu — použij přesně tyto nadpisy (markdown), ať jdou grepovat:

```markdown
# Feedback — Agent Ax (jméno role)

## Shrnutí (3–6 vět)
## Co se povedlo (bullet)
## Co se nepovedlo / blokery (bullet)
## Konflikty s jinými agenty (soubory + doporučení merge)
## Otevřené TODO pro další běh
## Příkazy ověřené (např. flutter analyze, flutter test)
```

4. **Nemaž** cizí `FEEDBACK_*.md`.

5. Firmware **nereportuj jako změněný** — pokud se ho agent dotkl, je to chyba; napiš to do blokera.

## Index

Po dokončení kola agenti doplní jednu řádkovou položku:

| Agent | Soubor | Poslední aktualizace |
|-------|--------|----------------------|
| A0 | [FEEDBACK_A0.md](./FEEDBACK_A0.md) | 2026-05-03 |
| A1 | [FEEDBACK_A1.md](./FEEDBACK_A1.md) | 2026-05-03 |
| A2 | [FEEDBACK_A2.md](./FEEDBACK_A2.md) | 2026-05-03 |
| A3 | [FEEDBACK_A3.md](./FEEDBACK_A3.md) | 2026-05-03 |
| A4 | [FEEDBACK_A4.md](./FEEDBACK_A4.md) | 2026-05-03 |
| A5 | [FEEDBACK_A5.md](./FEEDBACK_A5.md) | 2026-05-03 |
| A6 | [FEEDBACK_A6.md](./FEEDBACK_A6.md) | 2026-05-03 |
| A7 | [FEEDBACK_A7.md](./FEEDBACK_A7.md) | 2026-05-03 |
| A8 | [FEEDBACK_A8.md](./FEEDBACK_A8.md) | 2026-05-03 |

*(Tabulku může udržovat koordinátor ručně; A0 ji po kole synchronizuje s existujícími FEEDBACK soubory.)*
