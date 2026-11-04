# Struggle of Empires - versione digitale

Adattamento digitale per uso personale di **Struggle of Empires** di Martin Wallace (edizione Deluxe,
Eagle-Gryphon Games), fatto in Godot 4.7 per la ludoteca: https://tannoiser2.github.io/

## Cosa c'è

- **Regole Deluxe complete**: piazzamento iniziale, aste per le Grandi Alleanze, tre guerre di 5 o 6 round,
  costruzione e movimento (con il dado del Viaggio in mare aperto), attacchi con battaglia navale per il
  Supporto navale e battaglia terrestre, perdite per sconfitta, pareggio e 7, Colonizzare e Commercio della
  Costa d'Oro, Alleanze Locali, tutte le tessere (azioni gratuite, miglioramenti, azioni immediate, tattiche,
  compagnie commerciali), Pirati e Rivolta in colonia, Tassazione, Tensione, rendita, punteggio e rivoluzione.
- **Potenze non giocanti** (da 2 a 6 giocatori) con le loro armate sulla mappa, che si schierano nelle
  Grandi Alleanze e aiutano automaticamente i loro alleati; a 2-3 giocatori hanno anche segnalini Controllo.
- **IA che tratta**: valuta le aste in base a chi la minaccia e chi vuole attaccare ("alleati del nemico"),
  offre Oro agli alleati per farli entrare in battaglia, risponde alle offerte con controproposte, ricatta
  ("pagami o ti attacco"), compra la non aggressione, e ricorda chi ha rotto la parola (fiducia).
- **Trattative anche per chi gioca**: prima della chiamata agli alleati si possono offrire Oro agli alleati
  presenti; durante il turno si può chiedere Oro per non attaccare o pagare per non essere attaccati.
- **Online** con gli amici (stanze con codice di 4 lettere su Firebase, ognuno sceglie la sua potenza,
  i posti vuoti li guida l'IA) e **salvataggio** della partita contro l'IA su Firebase e sul dispositivo.
- Plancia originale (dal modulo TTS) con segnalini, unità, tracciati di punti, popolazione, round e alleanze;
  segnalini neutrali e tessere dalle scansioni Deluxe; stemmi dalle plance italiane.
- Interfaccia "carta e ceralacca" con font IM Fell English (titoli) ed EB Garamond (testi).

Scelte di regole: Tensione visibile (variante Open Unrest del regolamento Deluxe); dado del Viaggio in mare
aperto con 4 facce "riuscito", 1 "fermo", 1 "affonda"; numero di tessere ridotto in proporzione con meno di
7 giocatori; le Alleanze Locali "esercito o flotta" si usano in mare solo se il lato non combatte a terra.

## Struttura

- `scripts/motore.gd` - le regole: tutto lo stato in un dizionario, decisioni numerate (stessa sequenza = stessa partita).
- `scripts/ia.gd` - l'intelligenza artificiale (aste, trattative, attacchi, colonie, tessere).
- `scripts/dati.gd` - potenze, regioni, segnalini neutrali, alleanze locali, tessere, coordinate sulla plancia.
- `scripts/plancia.gd` - la mappa disegnata (zoom con rotella o pizzico, trascinamento).
- `scripts/main.gd` - menu e interfaccia; `scripts/rete.gd` - Firebase; `scripts/dado.gd` - dadi disegnati.
- `tools/controlla_glifi.py` - controlla che ogni carattere dei testi esista nei font.
- `firebase/database.rules.json` - regole del database (radice `struggle`, **da unire a quelle del progetto condiviso**).

## Prove

```
godot --headless --path . -s res://tests/sim.gd -- 10 4          # 10 partite tutte IA da 4 giocatori
godot --headless --path . -s res://tests/log1.gd -- 5 3           # diario completo di una partita
xvfb-run godot --path . -s res://tests/foto.gd -- azione 2        # screenshot dell'interfaccia
GODOT=godot tests/prova_online.sh                                  # partita online completa sul finto Firebase
python3 tools/controlla_glifi.py
```

## Pubblicazione

Il workflow `Pubblica` parte a mano (Actions -> Pubblica -> Run workflow) oppure con un commit che contiene
`[pubblica]`. Pubblica su GitHub Pages e, se ci sono i segreti `CLOUDFLARE_API_TOKEN` e `CLOUDFLARE_ACCOUNT_ID`,
anche sulla ludoteca privata (`struggleofempires.ludoteca-digitale.com`).
