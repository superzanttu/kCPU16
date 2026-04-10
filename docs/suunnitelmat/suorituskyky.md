# kCPU16 suorituskykysuunnitelma (käskyä/s)

Tämä analyysi perustuu koko Python-koodipohjan läpikäyntiin. Suurin vaikutus käskyä/s-arvoon tulee CPU:n kuumasta suorituspolusta (`cpu.py`, `registers.py`, `memory.py`), joten muutokset on kohdistettu siihen.

## 1) Poista per-käsky dataclass + merkkijonopohjainen dispatch

**Mitä muuttaa**
- Korvaa `DecodedInstruction`-olion luonti jokaisessa askeleessa kevyemmällä rakenteella (esim. kiinteä tuple/paikalliset muuttujat).
- Korvaa `if/elif ins.mnemonic == ...` -ketju opcode-pohjaisella handler-taululla (funktioviitteet/opcode -> handler + metadata).
- Yhdistä privilege- ja muistitarkistus handler-metadataan, jotta samoja mnemonic-vertailuja ei tehdä kolmessa eri vaiheessa.

**Miksi tämä nostaa käskyä/s**
- Nykyinen polku tekee jokaiselle käskylle olion luonnin, listan luonnin ja paljon merkkijonovastaavuuksia.
- Pythonissa haarautuva merkkijonodispätsi on selvästi kalliimpi kuin suora indeksihaku + funktiokutsu.
- Tämä vähentää tulkin overheadia jokaisella syklillä, eli vaikutus kertautuu suoraan IPS-lukemaan.

## 2) Harvenna ajanotto- ja keskeytyskellojen tarkistuksia

**Mitä muuttaa**
- Älä kutsu `time.monotonic()` jokaisella käskyllä.
- Tarkista uptime/CTMR vain harvennetusti (esim. joka N:s käsky) tai deadline-pohjaisesti.
- Vaihda timer-keskeytyksen modulovertailu (`instruction_counter % tmr == 0`) seuraavaan laukaisusyklin vertailuun (`next_timer_cycle`).

**Miksi tämä nostaa käskyä/s**
- `time.monotonic()` + modulo-operaatio jokaisella kierroksella on kallista verrattuna itse emuloitavaan käskyyn.
- Kun nämä tarkistukset tehdään harvemmin tai O(1)-vertailuina ilman moduloa, hot loop kevenee merkittävästi.

## 3) Tee rekistereistä taulukkopohjaiset CPU:n sisäkäytössä

**Mitä muuttaa**
- Korvaa `_get_reg/_set_reg` pitkät `if/elif`-ketjut taulukkoindeksoinnilla CPU:n suorituspolussa.
- Säilytä nykyinen julkinen rajapinta (r0…r15, fp, sp) esim. propertyjen kautta, mutta anna execute-polun käyttää suoraa lista/array-rakennetta.

**Miksi tämä nostaa käskyä/s**
- Nykyinen toteutus tekee paljon haaroja ja attribuuttihakuja lähes jokaisessa käskyssä.
- Suora indeksihaku vähentää branch-overheadia ja nopeuttaa erityisesti aritmetiikka-, logiikka- ja muistikäskyjä.

## 4) Optimoi `Memory.write` kirjoitussuojauksen tarkistus O(1)-muotoon

**Mitä muuttaa**
- Korvaa `read_only_regions`-listan läpikäynti jokaisella kirjoituksella maskitaulukolla (`bytearray`/bool-taulukko) tai erittäin kevyellä fast-path-haaralla.
- Päivitä suojausmaski vain silloin, kun suojattuja alueita muutetaan.

**Miksi tämä nostaa käskyä/s**
- Jokainen STORE/FILL/pinokirjoitus käy nyt läpi alue-listan.
- O(1)-tarkistus vähentää muistikirjoitusten kustannusta huomattavasti, mikä näkyy suoraan RAM-intensiivisissä benchmarkeissa.

## 5) Lisää erillinen “fast run” -suorituspolku jatkuvaan ajoon

**Mitä muuttaa**
- Pidä nykyinen `step()` debuggausta varten, mutta lisää `run()`-metodiin optimoitu hot loop:
  - paikalliset viittaukset usein käytettyihin metodeihin/muuttujiin
  - vähemmän funktiokutsuja per käsky
  - poikkeuspolku erotettuna normaalista nopeasta polusta

**Miksi tämä nostaa käskyä/s**
- Nykyinen malli kutsuu `step()` joka kierroksella ja maksaa yleiskäyttöisen debug-polun overheadin myös benchmark-ajossa.
- Fast-path pienentää Python-kutsuketjua per emuloitu käsky ja parantaa erityisesti pitkiä run-silmukoita.

---

## Priorisointi (suurin vaikutus ensin)
1. Opcode-pohjainen dispatch + decode-kevennys  
2. Ajanotto/keskeytystarkistusten harvennus  
3. Rekisterien taulukkopohjainen hot path  
4. `Memory.write` O(1)-suojaustarkistus  
5. `run()` fast-path

