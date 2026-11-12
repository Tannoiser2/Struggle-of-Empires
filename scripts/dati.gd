## Dati fissi di Struggle of Empires (edizione Deluxe, Eagle-Gryphon): potenze, regioni,
## segnalini Regione Neutrale, alleanze locali, tessere. Le coordinate sono frazioni della plancia.
class_name Dati
extends RefCounted

# ------------------------------------------------------------ potenze
const POTENZE := ["gb", "fr", "sp", "up", "au", "pr", "ru"]
const NOME_POT := {"gb": "Inghilterra", "fr": "Francia", "sp": "Spagna", "up": "Province Unite",
	"au": "Austria", "pr": "Prussia", "ru": "Russia"}
const COLORE_POT := {"gb": Color(0.80, 0.16, 0.14), "fr": Color(0.20, 0.45, 0.80), "sp": Color(0.93, 0.80, 0.15),
	"up": Color(0.95, 0.55, 0.15), "au": Color(0.93, 0.92, 0.88), "pr": Color(0.35, 0.36, 0.38), "ru": Color(0.35, 0.68, 0.22)}
const STEMMA := {"gb": "inghilterra", "fr": "francia", "sp": "spagna", "up": "province", "au": "austria",
	"pr": "prussia", "ru": "russia"}
## casa (patria) di ogni potenza
const CASA := {"gb": "casa_gb", "fr": "casa_fr", "sp": "casa_sp", "up": "casa_up", "au": "casa_au", "pr": "casa_pr", "ru": "casa_ru"}

const MAX_ESERCITI := 14
const MAX_FLOTTE := 8
const MAX_FORTI := 2
const MAX_CONTROLLO := 20
const MAX_ALLEANZE_LOCALI := 6

# ------------------------------------------------------------ regioni
## pv: punti vittoria per 1°, 2°, 3° posto. nave: si possono tenere flotte. gruppo: per il Viaggio
## in mare aperto (si tira il dado quando si cambia gruppo, tranne fra Europa e Europa o Americhe e Americhe).
const REGIONI := {
	"nordamerica": {"nome": "Nord America", "pv": [4, 2], "nave": true, "gruppo": "americhe", "col": true, "pos": Vector2(0.3111, 0.2153)},
	"caraibi": {"nome": "Caraibi", "pv": [5, 3], "nave": true, "gruppo": "americhe", "col": true, "pos": Vector2(0.3111, 0.3856)},
	"sudamerica": {"nome": "Sud America", "pv": [5, 3], "nave": true, "gruppo": "americhe", "col": true, "pos": Vector2(0.3333, 0.5609)},
	"africa": {"nome": "Africa", "pv": [3, 2], "nave": true, "gruppo": "africa", "col": true, "pos": Vector2(0.4444, 0.8213)},
	"india": {"nome": "India", "pv": [5, 3], "nave": true, "gruppo": "india", "col": true, "pos": Vector2(0.6278, 0.8514)},
	"indie": {"nome": "Indie Orientali", "pv": [4, 2], "nave": true, "gruppo": "indie", "col": true, "pos": Vector2(0.8667, 0.8313)},
	"baltico": {"nome": "Baltico", "pv": [5, 3], "nave": true, "gruppo": "europa", "col": false, "pos": Vector2(0.8833, 0.2153)},
	"germania": {"nome": "Stati Tedeschi", "pv": [8, 5, 3], "nave": false, "gruppo": "europa", "col": false, "pos": Vector2(0.7083, 0.3456)},
	"centro": {"nome": "Europa Centrale", "pv": [6, 4, 2], "nave": false, "gruppo": "europa", "col": false, "pos": Vector2(0.8667, 0.3706)},
	"mediterraneo": {"nome": "Mediterraneo", "pv": [6, 4, 2], "nave": true, "gruppo": "europa", "col": false, "pos": Vector2(0.7222, 0.5208)},
	"ottomano": {"nome": "Impero Ottomano", "pv": [4, 2], "nave": false, "gruppo": "europa", "col": false, "pos": Vector2(0.8667, 0.5409)},
	"casa_gb": {"nome": "Inghilterra", "casa": "gb", "nave": true, "gruppo": "europa", "pos": Vector2(0.6000, 0.2704)},
	"casa_fr": {"nome": "Francia", "casa": "fr", "nave": true, "gruppo": "europa", "pos": Vector2(0.6278, 0.4207)},
	"casa_sp": {"nome": "Spagna", "casa": "sp", "nave": true, "gruppo": "europa", "pos": Vector2(0.5611, 0.6010)},
	"casa_up": {"nome": "Province Unite", "casa": "up", "nave": true, "gruppo": "europa", "pos": Vector2(0.6806, 0.2754)},
	"casa_au": {"nome": "Austria", "casa": "au", "nave": true, "gruppo": "europa", "pos": Vector2(0.7750, 0.4207)},
	"casa_pr": {"nome": "Prussia", "casa": "pr", "nave": true, "gruppo": "europa", "pos": Vector2(0.7556, 0.2504)},
	"casa_ru": {"nome": "Russia", "casa": "ru", "nave": true, "gruppo": "europa", "pos": Vector2(0.9611, 0.2304)},
}
## le 11 regioni che danno punti vittoria, nell'ordine in cui si contano
const REGIONI_PV := ["germania", "centro", "baltico", "mediterraneo", "ottomano", "nordamerica", "caraibi",
	"sudamerica", "africa", "india", "indie"]
const COLONIE := ["nordamerica", "caraibi", "sudamerica", "africa", "india", "indie"]
const AMERICHE := ["nordamerica", "caraibi", "sudamerica"]
## regioni dove possono stare le flotte (oltre alla propria patria)
const NAVALI := ["nordamerica", "caraibi", "sudamerica", "africa", "india", "indie", "baltico", "mediterraneo"]

## contorni veri delle regioni (estratti dalla plancia con tools/confini.py): liste di poligoni in frazioni
static var _confini: Dictionary = {}
static func confini(reg: String) -> Array:
	if _confini.is_empty():
		var f := FileAccess.open("res://assets/mappa/confini.json", FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				for k in d:
					var lista: Array = []
					for poly in d[k]:
						var pv := PackedVector2Array()
						for q in poly:
							pv.append(Vector2(float(q[0]), float(q[1])))
						lista.append(pv)
					_confini[k] = lista
	return _confini.get(reg, [])

## la regione il cui confine contiene il punto (frazioni della plancia), "" se nessuna
static func regione_in(f: Vector2) -> String:
	for reg in REGIONI:
		for poly in confini(reg):
			if Geometry2D.is_point_in_polygon(f, poly):
				return reg
	return ""

## la regione le cui flotte combattono per una regione (le flotte del Mediterraneo servono anche l'Impero Ottomano)
static func mare_di(reg: String) -> String:
	if reg == "ottomano":
		return "mediterraneo"
	if reg in NAVALI:
		return reg
	return ""

# ------------------------------------------------------------ segnalini Regione Neutrale
## t: "col" = Colonizzare, "gcc" = Commercio Costa d'Oro, "d" = difesa v; bonus: "oro" (+3 Oro) o "pv" (+1 PV)
static func segnalini_neutrali() -> Array:
	var out: Array = []
	var spec := {
		"nordamerica": ["col", "col", "col", "gcc", 1, 1],
		"caraibi": ["col", "col", "gcc", "gcc", "gcc", "gcc", "gcc"],
		"sudamerica": ["col", "col", "gcc", "gcc", "gcc", 1],
		"africa": ["col", "col", 1],
		"india": ["col", "col", 1, 1, 2, "3oro", "3oro"],
		"indie": ["col", "col", "col", 1, 1, 1],
		"baltico": [2, 2, 3, 3, 3],
		"germania": [2, 2, 2, 3, 3, 3, 3, 4, 4],
		"centro": [2, 2, 3, 3, 4, 4],
		"mediterraneo": [2, 2, 2, 3, 3, 3],
		"ottomano": [3, 4, "5pv", "5pv"],
	}
	var n := 0
	for reg in spec:
		for x in spec[reg]:
			var seg := {"id": n, "reg": reg, "t": "d", "v": 0, "bonus": ""}
			if str(x) == "col" or str(x) == "gcc":
				seg["t"] = str(x)
			elif str(x) == "3oro":
				seg["v"] = 3
				seg["bonus"] = "oro"
			elif str(x) == "5pv":
				seg["v"] = 5
				seg["bonus"] = "pv"
			else:
				seg["v"] = int(x)
			out.append(seg)
			n += 1
	return out

static func img_neutrale(seg: Dictionary) -> String:
	var reg: String = seg["reg"]
	if seg["t"] != "d":
		return "res://assets/neutri/%s_%s.png" % [reg, seg["t"]]
	return "res://assets/neutri/%s_%d.png" % [reg, int(seg["v"])]

## segnalini sulla plancia all'inizio di ogni guerra, per numero di giocatori
static func neutrali_per_guerra(np: int) -> int:
	match np:
		2: return 4
		3: return 6
		4: return 8
		5, 6: return 9
	return 10

static func round_per_guerra(np: int) -> int:
	return 6 if np <= 4 else 5

# ------------------------------------------------------------ alleanze locali
## reg: regioni dove vale; tipo: "e" solo esercito, "en" esercito o flotta; costo in Oro
const ALLEANZE := {
	"nativi": {"nome": "Nativi americani", "reg": ["nordamerica"], "tipo": "e", "costo": 0, "pos": Vector2(0.2500, 0.2454)},
	"gauchos": {"nome": "Gauchos", "reg": ["sudamerica"], "tipo": "e", "costo": 1, "pos": Vector2(0.3083, 0.6210)},
	"portogallo": {"nome": "Portogallo", "reg": ["sudamerica", "india", "indie"], "tipo": "en", "costo": 1, "pos": Vector2(0.5111, 0.6010)},
	"nawab": {"nome": "Nawab indiano", "reg": ["india"], "tipo": "e", "costo": 0, "pos": Vector2(0.6778, 0.8213)},
	"svezia": {"nome": "Svezia", "reg": ["baltico"], "tipo": "en", "costo": 0, "pos": Vector2(0.8333, 0.1352)},
	"danimarca": {"nome": "Danimarca", "reg": ["baltico"], "tipo": "en", "costo": 1, "pos": Vector2(0.6944, 0.1452)},
	"sassonia": {"nome": "Sassonia", "reg": ["germania"], "tipo": "e", "costo": 0, "pos": Vector2(0.7722, 0.3456)},
	"baviera": {"nome": "Baviera", "reg": ["germania"], "tipo": "e", "costo": 0, "pos": Vector2(0.7167, 0.4056)},
	"cosacchi": {"nome": "Cosacchi", "reg": ["centro"], "tipo": "e", "costo": 0, "pos": Vector2(0.8111, 0.4056)},
	"napoli": {"nome": "Napoli", "reg": ["mediterraneo"], "tipo": "e", "costo": 0, "pos": Vector2(0.7528, 0.5659)},
	"ottomani": {"nome": "Ottomani", "reg": ["mediterraneo", "ottomano"], "tipo": "en", "costo": 1, "pos": Vector2(0.8111, 0.6460)},
}

# ------------------------------------------------------------ tessere
## cat: "lib" Azione Gratuita (una volta per guerra), "mig" Miglioramento (permanente),
## "imm" Azione Immediata, "tat" Tattica militare, "com" Commercio (azione gratuita, una volta per guerra)
## costo: oro, pop (popolazione), tens (Tensione presa)
const TESSERE := {
	"diplomazia": {"nome": "Servizio diplomatico", "cat": "lib", "oro": 2, "n": 1, "img": "diplomazia",
		"testo": "Azione gratuita, una volta per guerra: stipula un'Alleanza Locale (paghi il suo eventuale costo)."},
	"agricoltura": {"nome": "Agricoltura migliorata", "cat": "lib", "oro": 0, "n": 5, "img": "agricoltura",
		"testo": "+1 Popolazione quando la prendi. Azione gratuita, una volta per guerra: +1 Popolazione."},
	"mercenari": {"nome": "Mercenari", "cat": "lib", "oro": 3, "n": 2, "img": "mercenari",
		"testo": "Azione gratuita, una volta per guerra: costruisci 1 Esercito in patria senza pagare Popolazione."},
	"reclutamento": {"nome": "Reclutamento forzato", "cat": "lib", "oro": 3, "n": 1, "img": "reclutamento",
		"testo": "Azione gratuita, una volta per guerra: costruisci 1 Flotta in patria senza pagare Popolazione."},
	"riserve": {"nome": "Riserve", "cat": "lib", "oro": 2, "n": 4, "img": "riserve",
		"testo": "Una volta per guerra, da attaccante o difensore: dopo il tiro di un combattimento fai ritirare tutti i dadi."},
	"milizia_indigena": {"nome": "Milizia indigena", "cat": "lib", "oro": 4, "n": 1, "img": "milizia_indigena",
		"testo": "Azione gratuita, una volta per guerra: 1 Esercito senza Popolazione direttamente in una colonia dove hai un segnalino Controllo o un'unità."},
	"ministero": {"nome": "Ministero della Guerra", "cat": "lib", "oro": 8, "n": 1, "img": "ministero",
		"testo": "Azione gratuita, una volta per guerra: esegui 1 Attacco senza pagarlo."},
	"riforma": {"nome": "Riforma del governo", "cat": "imm", "oro": 0, "n": 10, "img": "riforma",
		"testo": "Subito: riponi 2 punti Tensione."},
	"industria": {"nome": "Industria", "cat": "imm", "oro": 0, "pop": 2, "tens": 2, "n": 3, "img": "industria",
		"testo": "Costa 2 Popolazione e 2 Tensione: subito 3 PV, più 1 PV per ogni Agricoltura migliorata che possiedi."},
	"addestr_esercito": {"nome": "Addestramento esercito", "cat": "mig", "oro": 6, "n": 6, "img": "addestr_esercito",
		"testo": "+1 nel combattimento terrestre se hai più tessere Addestramento esercito dell'avversario."},
	"addestr_navale": {"nome": "Addestramento navale", "cat": "mig", "oro": 5, "n": 3, "img": "addestr_navale",
		"testo": "+1 nel combattimento navale se hai più tessere Addestramento navale dell'avversario."},
	"banca": {"nome": "Banca", "cat": "mig", "oro": 2, "n": 2, "img": "banca",
		"testo": "Con la Tassazione prendi 3 Oro invece di 2 (sempre 1 Tensione)."},
	"logistica": {"nome": "Logistica", "cat": "mig", "oro": 0, "pop": 1, "n": 3, "img": "logistica",
		"testo": "Costa 1 Popolazione. Quando muovi, muovi 1 unità in più."},
	"milizia": {"nome": "Milizia", "cat": "mig", "oro": 4, "n": 3, "img": "milizia",
		"testo": "Quando costruisci, puoi costruire 1 Esercito in più (paghi la sua Popolazione)."},
	"blocco": {"nome": "Blocco navale", "cat": "tat", "oro": 0, "n": 1, "img": "blocco",
		"testo": "+2 invece di +1 di Supporto navale in un combattimento terrestre, OPPURE blocco di una colonia dove hai una Flotta."},
	"ritirata": {"nome": "Ritirata combattendo", "cat": "tat", "oro": 0, "n": 1, "img": "ritirata",
		"testo": "Da difensore, dopo una sconfitta: tu e i tuoi alleati non perdete unità in quel combattimento."},
	"sorpresa": {"nome": "Attacco a sorpresa", "cat": "tat", "oro": 0, "n": 1, "img": "sorpresa",
		"testo": "Quando attacchi: nessun altro giocatore può unirsi al difensore."},
	"c_baltica": {"nome": "Compagnia del Baltico", "cat": "com", "oro": 0, "n": 1, "img": "baltica", "reg": ["baltico"],
		"testo": "Azione gratuita, una volta per guerra: 1 Oro per ogni tuo segnalino Controllo nel Baltico."},
	"c_indie": {"nome": "Compagnia delle Indie", "cat": "com", "oro": 0, "n": 2, "img": "indie_or", "reg": ["india", "indie"],
		"testo": "Azione gratuita, una volta per guerra: 1 Oro per ogni tuo segnalino Controllo in India o nelle Indie Orientali (una delle due)."},
	"c_costa": {"nome": "Commercio della Costa d'Oro", "cat": "com", "oro": 0, "n": 1, "img": "costa_oro", "reg": ["africa"],
		"testo": "Azione gratuita, una volta per guerra: 1 Oro per ogni tuo segnalino Controllo in Africa."},
	"c_miniere": {"nome": "Miniere d'oro", "cat": "com", "oro": 0, "n": 1, "img": "miniere", "reg": ["sudamerica"],
		"testo": "Azione gratuita, una volta per guerra: 1 Oro per ogni tuo segnalino Controllo in Sud America."},
	"c_levante": {"nome": "Compagnia del Levante", "cat": "com", "oro": 0, "n": 2, "img": "levante", "reg": ["mediterraneo", "ottomano"],
		"testo": "Azione gratuita, una volta per guerra: 1 Oro per ogni tuo segnalino Controllo nel Mediterraneo o nell'Impero Ottomano (uno dei due)."},
	"c_zucchero": {"nome": "Piantagioni di zucchero", "cat": "com", "oro": 0, "n": 1, "img": "zucchero", "reg": ["caraibi"],
		"testo": "Azione gratuita, una volta per guerra: 1 Oro per ogni tuo segnalino Controllo nei Caraibi."},
	"c_tabacco": {"nome": "Piantagioni di tabacco", "cat": "com", "oro": 0, "n": 1, "img": "tabacco", "reg": ["nordamerica"],
		"testo": "Azione gratuita, una volta per guerra: 1 Oro per ogni tuo segnalino Controllo in Nord America."},
}
const ORDINE_TESSERE := ["agricoltura", "riforma", "industria", "diplomazia", "mercenari", "reclutamento", "riserve",
	"milizia_indigena", "ministero", "addestr_esercito", "addestr_navale", "banca", "logistica", "milizia",
	"blocco", "ritirata", "sorpresa", "c_baltica", "c_indie", "c_costa", "c_miniere", "c_levante", "c_zucchero", "c_tabacco"]

## quante tessere di ogni tipo ci sono sul tabellone, secondo il numero di giocatori
static func tessere_per(np: int) -> Dictionary:
	var f: float = {2: 0.5, 3: 0.6, 4: 0.7, 5: 0.85, 6: 0.95}.get(np, 1.0)
	var out := {}
	for k in TESSERE:
		var n: int = TESSERE[k]["n"]
		if TESSERE[k]["cat"] == "com" or TESSERE[k]["cat"] == "tat" or n == 1:
			out[k] = n
		else:
			out[k] = maxi(1, int(round(n * f)))
	return out

const NOME_SEGRETA := {"pirati": "Incitare attacco pirata", "rivolta": "Incitare rivolta in colonia"}
const FORZA_SEGRETA := {"pirati": 1, "rivolta": 3}

# ------------------------------------------------------------ posizioni sulla plancia (frazioni)
## plancia Deluxe (Mappa.png): round in alto, guerre in alto a destra, alleanze e popolazione a sinistra
const POS_ROUND := [Vector2(0.2483, 0.0270), Vector2(0.2722, 0.0270), Vector2(0.2972, 0.0270), Vector2(0.3217, 0.0270), Vector2(0.3450, 0.0270), Vector2(0.3689, 0.0270)]
const POS_GUERRA := [Vector2(0.9000, 0.0631), Vector2(0.9150, 0.0631), Vector2(0.9311, 0.0631)]
const POS_PROPOSTA := [Vector2(0.1917, 0.0821), Vector2(0.1917, 0.1322)]
const POS_ALLEANZE_R := [Vector2(0.0983, 0.0851), Vector2(0.1200, 0.0851), Vector2(0.1411, 0.0851), Vector2(0.1622, 0.0851)]
const POS_ALLEANZE_B := [Vector2(0.0983, 0.1322), Vector2(0.1200, 0.1322), Vector2(0.1411, 0.1322), Vector2(0.1622, 0.1322)]

static func pos_popolazione(v: int) -> Vector2:
	var ys := [510.0, 475.0, 441.0, 409.0, 375.0, 341.0, 305.0, 274.0, 237.0, 205.0]
	return Vector2(205.0 / 1800.0, ys[clampi(v, 0, 9)] / 998.4)

static func pos_pv(v: int) -> Vector2:
	v = clampi(v, 0, 100)
	if v == 0:
		return Vector2(62.0 / 1800.0, 966.0 / 998.4)
	var col := (v - 1) / 25
	var riga := (v - 1) % 25
	var xs := [20.0, 52.0, 86.0, 120.0]
	return Vector2(xs[col] / 1800.0, (918.0 - riga * 37.33) / 998.4)
