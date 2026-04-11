# kCPU16 Assembler — VS Code Extension

Tämä hakemisto sisältää VS Code -extension kCPU16-assemblerin syntaksivärikoodaukselle.

## Ominaisuudet

- **Syntaksiväritys** kaikille kCPU16-assemblerin rakenteille:
  - Kommentit (`;`)
  - Labelit (`START:`, `loop:`)
  - Direktiivit (`.origin`, `.macro`, `.db`, `.dstr`, jne.)
  - Käskyt — normaalit, ohjausrakenteet, etuoikeutetut (kernel)
  - Rekisterit (`R0`–`R15`, `FP`, `SP`, `PC`, `SR`)
  - Arkkitehtuurivakiot (`VRAM_START`, `KBD_DATA`, `INT_CLOCK`, jne.)
  - Numeroliteraalit: desimaali, hex (`0xFF`), binary (`0b1010`), okta (`0o52`)
  - Merkkijonot (`.dstr "teksti"`) ja escape-sekvenssit
  - Muistiviittaukset (`[addr]`)
- **Kommenttituki**: `Ctrl+/` lisää/poistaa `;`-kommentin
- **Automaattisulkeet**: `[`, `"`, `'`
- **Sanakäsittely**: kaksoisnapsautus valitsee kokonaiset identifikaattorit

## Asennus

### Nopea asennus (PowerShell)

```powershell
cd vsc
.\install.ps1
```

Skripti kopioi extensionin `~/.vscode/extensions/`-hakemistoon.  
**Käynnistä VS Code uudelleen** asennuksen jälkeen.

### Manuaalinen asennus

Kopioi `vsc/kcpu16-asm/`-kansio VS Coden extensions-hakemistoon:

```
%USERPROFILE%\.vscode\extensions\kcpu16-asm-0.1.0\
```

### Kehitystila (ilman asennusta)

Avaa `vsc/kcpu16-asm/` VS Codesssa ja paina `F5` — avaa Extension Development Host -ikkunan, jossa extension on aktiivinen.

## Tiedostopäätteet

Extension tunnistaa automaattisesti `.k16`-tiedostot.

Workspace-asetukset (`.vscode/settings.json`) pakottavat myös `.asm`-tiedostot käyttämään kCPU16-kielimäärittelyä tässä projektissa.

---

## Suositus tiedostopäätteestä

### Nykyinen: `.asm`

**Ongelma:** `.asm` on täysin geneerinen assembly-päätite, jota käyttävät kymmenet eri assemblerit (x86 NASM/MASM, ARM, AVR, RISC-V jne.). VS Codessa se voidaan tunnistaa muiden kielikielioppisääntöjen kanssa, mikä aiheuttaa vääriä värikoodauksia ilman workspace-override'ia.

### Suositus: Jatka `.asm`-päätteellä

Koska `.asm` on jo syvästi koodissa kiinni (`tui.py`, CLI-dokumentaatio, 50+ tiedosto-nimeä), **ei ole perusteltua vaihtaa** päätettä. Tämän projektin `.vscode/settings.json` ylikirjoittaa aina oikean kielimäärityksen kaikille `.asm`-tiedostoille tässä workspacessa.

### Vaihtoehto: Lisää `.k16`-tuki

Jos haluaa erottua selkeämmin muista assemblereista, voi **lisätä** `.k16`-tuen säilyttäen `.asm`:

Muutos `kcpu16/tui.py` rivillä ~1316:
```python
# Ennen:
files = sorted(p.name for p in self.code_dir.iterdir() if p.suffix == ".asm")
# Jälkeen:
files = sorted(p.name for p in self.code_dir.iterdir() if p.suffix in {".asm", ".k16"})
```

Assembler itse hyväksyy jo minkä tahansa tiedostopolun — ei muutoksia tarvita.  
`.k16` on lyhyt, muistettava ja yksiselitteinen kCPU16:lle.

---

## Värikoodauksen rakenne

| Elementti          | Esimerkki                | TextMate-scope                 |
| ------------------ | ------------------------ | ------------------------------ |
| Kommentti          | `; teksti`               | `comment.line.semicolon`       |
| Label              | `START:`                 | `entity.name.function.label`   |
| Direktiivi         | `.origin`, `.macro`      | `keyword.other.directive`      |
| Kernelkäsky        | `HALT`, `IRET`, `SMPR`   | `keyword.other.privileged`     |
| Ohjausrakenne      | `JUMP`, `CALL`, `JZ`     | `keyword.control.flow`         |
| Käsky              | `LOAD`, `ADD`, `PUSH`    | `support.function.instruction` |
| Rekisteri          | `R0`, `FP`, `SP`         | `variable.language.register`   |
| Arkkitehtuurivakio | `VRAM_START`, `KBD_DATA` | `support.constant.arch`        |
| Hex-numero         | `0xFF`, `#0xF800`        | `constant.numeric.hex`         |
| Binääri            | `0b1010`                 | `constant.numeric.binary`      |
| Desimaali          | `42`, `-50`              | `constant.numeric.decimal`     |
| Merkkijono         | `"Hello!"`               | `string.quoted.double`         |
| Escape             | `\n`, `\0`               | `constant.character.escape`    |
| Hakasulke          | `[addr]`                 | `punctuation.section.brackets` |
