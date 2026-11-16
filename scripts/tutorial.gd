## Tutorial guidato: una partita vera a 4 (seme fisso, quindi sempre identica) in cui il tutore
## spiega regole e strategie. Tre tipi di passo:
##   pagina: spiegazione con Avanti/Indietro (le IA aspettano)
##   mossa:  il giocatore deve fare esattamente la decisione indicata (k = tipo di richiesta, id = scelta)
##   gioca:  le IA giocano finché non arriva una richiesta umana del tipo k
## Finito il copione il tutore resta come "consigliere" con un suggerimento a ogni decisione.
class_name Tutorial
extends Node

const F_TITOLO := preload("res://assets/font/IMFellSC.ttf")
const F_CORSIVO := preload("res://assets/font/IMFellCorsivo.ttf")
const F_BASE := preload("res://assets/font/EBGaramond.ttf")
const C_CARTA := Color(0.95, 0.9, 0.77)
const C_INCHIOSTRO := Color(0.2, 0.13, 0.07)
const C_CERALACCA := Color(0.58, 0.1, 0.07)
const C_SPENTO := Color(0.45, 0.36, 0.26)

## la partita del tutorial: Inghilterra (tu) contro tre IA, seme 23
const CONFIG := {"pot": ["gb", "fr", "sp", "ru"], "seat": [0, -1, -1, -1], "seed": 23, "nomi": ["", "", "", ""]}

var main
var passi: Array = []
var idx := 0
var libero := false
var ridotto := false
var box: PanelContainer
var lbl_titolo: Label
var lbl_passo: Label
var testo: RichTextLabel
var scroll: ScrollContainer
var avviso: Label
var b_indietro: Button
var b_avanti: Button
var b_riduci: Button
var corpo: VBoxContainer
var piede: HBoxContainer
var in_attesa_anim := false
var ultima_k_consiglio := ""
var t_avviso := 0.0

func avvia(m_main) -> void:
	main = m_main
	passi = _copione()
	idx = 0
	_costruisci_ui()
	mostra()

# ------------------------------------------------------------------ interfaccia

func _bottone(t: String, f: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_override("font", F_BASE)
	b.add_theme_font_size_override("font_size", 19)
	b.custom_minimum_size = Vector2(120, 40)
	b.pressed.connect(f)
	return b

func _costruisci_ui() -> void:
	box = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(C_CARTA.r, C_CARTA.g, C_CARTA.b, 0.97)
	sb.border_color = C_CERALACCA
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 10
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	box.add_theme_stylebox_override("panel", sb)
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = 12
	box.offset_right = 12 + 690
	box.offset_bottom = -12
	box.offset_top = -12 - 470
	main.schermo.add_child(box)
	corpo = VBoxContainer.new()
	corpo.add_theme_constant_override("separation", 6)
	box.add_child(corpo)
	var testa := HBoxContainer.new()
	corpo.add_child(testa)
	lbl_titolo = Label.new()
	lbl_titolo.add_theme_font_override("font", F_TITOLO)
	lbl_titolo.add_theme_font_size_override("font_size", 26)
	lbl_titolo.add_theme_color_override("font_color", C_CERALACCA)
	lbl_titolo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_titolo.clip_text = true
	lbl_titolo.custom_minimum_size = Vector2(300, 0)
	testa.add_child(lbl_titolo)
	lbl_passo = Label.new()
	lbl_passo.add_theme_font_override("font", F_CORSIVO)
	lbl_passo.add_theme_font_size_override("font_size", 17)
	lbl_passo.add_theme_color_override("font_color", C_SPENTO)
	testa.add_child(lbl_passo)
	b_riduci = _bottone("Riduci", _riduci)
	b_riduci.custom_minimum_size = Vector2(100, 34)
	testa.add_child(b_riduci)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	corpo.add_child(scroll)
	testo = RichTextLabel.new()
	testo.bbcode_enabled = true
	testo.fit_content = true
	testo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	testo.custom_minimum_size = Vector2(640, 0)
	testo.add_theme_font_override("normal_font", F_BASE)
	testo.add_theme_font_override("italics_font", F_CORSIVO)
	testo.add_theme_font_override("bold_font", F_TITOLO)
	testo.add_theme_font_size_override("normal_font_size", 20)
	testo.add_theme_font_size_override("italics_font_size", 20)
	testo.add_theme_font_size_override("bold_font_size", 21)
	testo.add_theme_color_override("default_color", C_INCHIOSTRO)
	scroll.add_child(testo)
	avviso = Label.new()
	avviso.add_theme_font_override("font", F_CORSIVO)
	avviso.add_theme_font_size_override("font_size", 18)
	avviso.add_theme_color_override("font_color", C_CERALACCA)
	avviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	avviso.custom_minimum_size = Vector2(640, 0)
	avviso.visible = false
	corpo.add_child(avviso)
	piede = HBoxContainer.new()
	piede.add_theme_constant_override("separation", 10)
	corpo.add_child(piede)
	b_indietro = _bottone("Indietro", _indietro)
	piede.add_child(b_indietro)
	b_avanti = _bottone("Avanti", _avanti)
	b_avanti.custom_minimum_size = Vector2(160, 40)
	piede.add_child(b_avanti)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	piede.add_child(sp)
	piede.add_child(_bottone("Esci dal tutorial", func(): main.mostra_menu()))

var compatto := false

func _riduci() -> void:
	ridotto = not ridotto
	_dimensiona()

## ridotto (a mano) o compatto (durante le battaglie, per lasciare vedere i dadi): solo la testata
func _dimensiona() -> void:
	var piccolo := ridotto or compatto
	scroll.visible = not piccolo
	piede.visible = not piccolo
	if piccolo:
		avviso.visible = false
	b_riduci.text = "Apri" if ridotto else "Riduci"
	b_riduci.visible = not compatto
	if piccolo:
		box.offset_top = -12 - 62
	else:
		# altezza secondo il testo, fra 230 e 520 pixel (il resto scorre)
		var h := testo.get_content_height() + 150.0 + (avviso.size.y + 6.0 if avviso.visible else 0.0)
		box.offset_top = -12 - clampf(h, 230.0, 520.0)

func _dimensiona_dopo() -> void:
	for k in 2:
		await get_tree().process_frame
	if is_instance_valid(box):
		_dimensiona()

func _passo() -> Dictionary:
	if idx < passi.size():
		return passi[idx]
	return {}

func mostra() -> void:
	if not is_instance_valid(box):
		return
	avviso.visible = false
	if libero or idx >= passi.size():
		libero = true
		ultima_k_consiglio = ""
		_mostra_consiglio()
		return
	var p := _passo()
	lbl_titolo.text = str(p.get("titolo", ""))
	lbl_passo.text = "Passo %d di %d  " % [idx + 1, passi.size()]
	var t: String = p.get("testo", "")
	in_attesa_anim = p.get("anim", false) and _anima()
	if in_attesa_anim:
		t = "[i]Guarda la mappa: il combattimento si svolge lì. Se il riquadro della battaglia mostra il bottone Continua, premilo quando hai letto.[/i]"
	elif p["t"] == "mossa":
		t += "\n\n[i]Fai questa mossa adesso, dal pannello a destra oppure cliccando sulla mappa.[/i]"
	elif p["t"] == "gioca":
		t += "\n\n[i]Le altre potenze stanno giocando: segui le loro mosse sulla mappa e nel diario in basso a destra.[/i]"
	testo.text = t
	scroll.scroll_vertical = 0
	b_avanti.visible = p["t"] == "pagina" and not in_attesa_anim
	b_avanti.text = "Avanti" if idx + 1 < passi.size() else "Gioca da solo"
	b_indietro.visible = p["t"] == "pagina" and idx > 0 and passi[idx - 1]["t"] == "pagina" and not in_attesa_anim
	if ridotto:
		ridotto = false
	_dimensiona()
	_dimensiona_dopo()
	# evidenziazioni (quelle del passo, altrimenti si ridisegna la richiesta in corso) e inquadratura
	if p["t"] == "pagina" or p.has("evid") or p.has("ogg"):
		main._evidenzia([], [])
	else:
		main.richiesta_mostrata = -1
		var r: Dictionary = main.m.richiesta()
		if r.is_empty() or int(r["g"]) != main.mio_posto:
			main._evidenzia([], [])
	if p.has("vola") and main.vista_3d and main.vista != null and not _anima():
		main.vista.inquadra_regione(str(p["vola"]))

func _anima() -> bool:
	return main.animazione_in_corso or not main.animazioni.is_empty()

func _avanti() -> void:
	if idx < passi.size():
		idx += 1
		mostra()

func _indietro() -> void:
	if idx > 0 and passi[idx - 1]["t"] == "pagina":
		idx -= 1
		mostra()

func _mostra_avviso(t: String) -> void:
	if ridotto:
		ridotto = false
		_dimensiona()
	avviso.text = t
	avviso.visible = true
	t_avviso = 6.0
	_dimensiona_dopo()

func _process(delta: float) -> void:
	if main == null or not main.in_partita:
		return
	var anim := _anima()
	if anim != compatto and is_instance_valid(box):
		compatto = anim
		if compatto:
			lbl_passo.text = "guarda la mappa  "
		elif not libero and idx < passi.size():
			lbl_passo.text = "Passo %d di %d  " % [idx + 1, passi.size()]
		_dimensiona()
	if t_avviso > 0.0:
		t_avviso -= delta
		if t_avviso <= 0.0 and is_instance_valid(avviso):
			avviso.visible = false
	if libero:
		_mostra_consiglio()
		return
	var p := _passo()
	if p.is_empty():
		return
	if in_attesa_anim and not _anima():
		in_attesa_anim = false
		mostra()
		return
	if p["t"] == "gioca" and not _anima():
		var r: Dictionary = main.m.richiesta()
		if not r.is_empty() and int(r["g"]) == main.mio_posto and r["k"] == p["k"]:
			_avanti()

# ------------------------------------------------------------------ interfaccia con main

## le IA aspettano mentre si legge una pagina
func pausa_ia() -> bool:
	if libero:
		return false
	var p := _passo()
	return not p.is_empty() and p["t"] == "pagina"

## regioni e pezzi da evidenziare al posto di quelli normali (null = lascia fare a main)
func evidenza():
	if libero:
		return null
	var p := _passo()
	if p.is_empty():
		return null
	if p["t"] == "pagina" or p.has("evid") or p.has("ogg"):
		return [p.get("evid", []), p.get("ogg", [])]
	return null

## si può applicare questa decisione?
func consenti(k: String, id: String) -> bool:
	if libero:
		return true
	var p := _passo()
	if p.is_empty():
		return true
	if p["t"] == "pagina":
		_mostra_avviso("Prima leggi la spiegazione e premi Avanti nel riquadro del tutore.")
		return false
	if p["t"] == "mossa" and k == p["k"] and id == p["id"]:
		return true
	_mostra_avviso(str(p.get("aiuto", "Nel tutorial ora la mossa da fare è un'altra: rileggi le istruzioni qui sopra.")))
	return false

## decisione applicata: se era quella prevista si passa al passo successivo
func fatto(k: String, id: String) -> void:
	if libero:
		return
	var p := _passo()
	if not p.is_empty() and p["t"] == "mossa" and k == p["k"] and id == p["id"]:
		_avanti()

func _mostra_consiglio() -> void:
	var r: Dictionary = main.m.richiesta()
	var k := ""
	if not r.is_empty() and int(r["g"]) == main.mio_posto:
		k = r["k"]
	if k == ultima_k_consiglio and lbl_titolo.text != "":
		return
	ultima_k_consiglio = k
	lbl_titolo.text = "Il consiglio del tutore"
	lbl_passo.text = ""
	b_avanti.visible = false
	b_indietro.visible = false
	if k == "":
		testo.text = "[i]Le altre potenze stanno giocando. Intanto guarda la tabella dei giocatori a destra: la colonna PV tra parentesi mostra i punti che ognuno farebbe se la guerra finisse adesso.[/i]"
	else:
		testo.text = CONSIGLI.get(k, "Scegli con calma: passa il mouse sulle opzioni e sulle regioni della mappa per i dettagli.")
	_dimensiona_dopo()

# ------------------------------------------------------------------ consigli per il gioco libero

const CONSIGLI := {
	"azione": "[b]Il tuo turno.[/b] Hai due azioni: due regolari, oppure una regolare e una speciale. Prima di agire guarda dove sei primo, dove sei a pari merito e dove ti manca un solo segnalino per salire di posto: sono le regioni in cui un'azione vale di più.\n\nRicorda: un attacco costa 2 Oro; Colonizzare costa 1 Popolazione e non richiede unità; Passare ti toglie 1 Tensione se in questo turno non attacchi; le tessere Azione Gratuita non consumano azioni e si usano una volta per guerra. Con le trattative puoi chiedere Oro a chi minacci, o pagarne per non essere attaccato.",
	"piazza": "Metti le unità dove hai già segnalini Controllo da difendere o dove ci sono segnalini neutrali deboli da conquistare. Una Flotta in una colonia è indispensabile per portarci eserciti più avanti e dà il Supporto navale (+1) se il nemico non ha flotte.",
	"asta": "Nell'asta scegli chi sarà tuo alleato e chi nemico. Mettiti contro chi ha segnalini nelle regioni dove sei forte (così puoi attaccarlo) e accanto a chi potrebbe colpirti. Non spendere troppo: passare non costa niente e spesso un altro paga per una sistemazione che ti va bene.",
	"costr_tipo": "Esercito per attaccare e difendere a terra; Flotta per il Supporto navale e per poter portare eserciti nelle colonie; Forte (+2 in difesa, non perde nei pareggi) per proteggere una regione chiave. Ogni unità costa 1 Popolazione e a fine guerra ti fa incassare 1 Oro in meno.",
	"costr_dest": "Puoi spostare subito l'unità appena costruita. Fra Europa e colonie si tira il dado del Viaggio: 4 facce su 6 vanno bene, una blocca (paghi 1 Oro per partire lo stesso) e una affonda (3 Oro per arrivare, 2 per restare a casa).",
	"muovi_da": "Scegli l'unità da muovere. Un'azione Muovere sposta due unità, anche diverse. Gli eserciti possono andare in una colonia solo se lì hai una tua Flotta.",
	"muovi_a": "Scegli la destinazione. Se cambi gruppo di regioni (Europa, Americhe, Africa, India, Indie Orientali) si tira il dado del Viaggio.",
	"dsm": "Il dado del Viaggio è andato male. Pagare costa Oro; lasciar affondare l'unità costa la Popolazione spesa per costruirla e 1 Tensione. Se ti serve davvero là, paga.",
	"colonizza": "Il segnalino Colonizzare diventa un tuo Controllo per 1 Popolazione. Scegli la regione dove quel segnalino ti fa salire di posto: pareggiare il primo posto vale il punteggio pieno.",
	"commercio": "La Costa d'Oro converte un segnalino senza spendere Popolazione, ma ti serve una Flotta in Africa.",
	"att_reg": "Scegli dove attaccare. Ti serve un Esercito nella regione (una Flotta basta solo per i bersagli navali). Conta le forze: eserciti +1, Supporto navale +1, Alleanza Locale +1, e chiedi agli alleati presenti di unirsi.",
	"att_bers": "Puoi attaccare i segnalini Controllo delle potenze dell'altra Grande Alleanza e i segnalini neutrali. Un neutrale ha la forza scritta sopra e non riceve aiuti; se vinci diventa tuo Controllo e può darti un premio.",
	"tratt": "Prima della battaglia puoi offrire Oro agli alleati presenti nella regione perché impegnino le loro unità. La promessa non è vincolante, ma chi non la mantiene perde la fiducia degli altri.",
	"tratt_risp": "Un alleato ti offre Oro per unirti alla battaglia. Se accetti e poi non impegni le unità, gli altri se lo ricorderanno. Le perdite colpiscono prima le unità di chi combatte in prima persona.",
	"impegno": "Impegnare le tue unità aiuta l'alleato. Gli eserciti aggiungono forza ma possono subire perdite (+1 Tensione per ogni unità persa); una Flotta in una battaglia di terra dà solo il Supporto navale e non rischia nulla.",
	"ricatto_quanto": "Chiedere Oro per non attaccare vale solo per questo turno; offrire Oro per non essere attaccato vale per il resto della guerra. Se l'altro rifiuta non paghi niente.",
	"ricatto_risp": "Pagare evita un attacco, ma la promessa non è vincolante. Valuta quanto ti costerebbe perdere il segnalino minacciato.",
	"alleanza": "Un'Alleanza Locale dà +1 in tutti i combattimenti della sua regione per il resto di questa guerra. Le più utili sono quelle dove combatterai presto.",
	"tessera": "Le tessere migliorano la tua nazione. Agricoltura migliorata è gratuita e dà Popolazione; Riforma del governo, gratuita, toglie subito 2 Tensione; Banca, Logistica e gli Addestramenti valgono a lungo; quelle di Commercio rendono Oro se hai segnalini nella loro regione.",
	"segreta": "Le azioni segrete colpiscono qualsiasi segnalino Controllo, anche di un alleato, e nessuno può aiutare il difensore. Pirati: forza 1, in una colonia. Rivolta: forza 3, nelle Americhe.",
	"segreta_bers": "Scegli un segnalino senza unità a difenderlo: è lì che l'azione segreta ha più probabilità di riuscire.",
	"riserve": "Le Riserve fanno ritirare tutti i dadi del combattimento: usale quando il tiro ti ha appena condannato.",
	"ritirata": "Con la Ritirata combattendo, da difensore sconfitto, né tu né i tuoi alleati perdete unità: salva le truppe quando il segnalino è perso comunque.",
	"sorpresa": "Con l'Attacco a sorpresa nessuno può unirsi al difensore: usalo contro un segnalino che gli alleati del nemico difenderebbero.",
	"nav_att": "Battaglia navale: chi vince ottiene il Supporto navale per la battaglia di terra.",
	"nav_def": "Battaglia navale: chi vince ottiene il Supporto navale per la battaglia di terra.",
}

# ------------------------------------------------------------------ il copione

static func _pg(titolo: String, testo: String, extra := {}) -> Dictionary:
	var d := {"t": "pagina", "titolo": titolo, "testo": testo}
	d.merge(extra)
	return d

static func _mv(titolo: String, k: String, id: String, testo: String, aiuto: String, extra := {}) -> Dictionary:
	var d := {"t": "mossa", "titolo": titolo, "k": k, "id": id, "testo": testo, "aiuto": aiuto}
	d.merge(extra)
	return d

static func _gi(titolo: String, k: String, testo: String, extra := {}) -> Dictionary:
	var d := {"t": "gioca", "titolo": titolo, "k": k, "testo": testo}
	d.merge(extra)
	return d

static func _copione() -> Array:
	var pv := ["nordamerica", "caraibi", "sudamerica", "africa", "india", "indie", "baltico", "germania", "centro", "mediterraneo", "ottomano"]
	var colonie := ["nordamerica", "caraibi", "sudamerica", "africa", "india", "indie"]
	var europa := ["baltico", "germania", "centro", "mediterraneo", "ottomano"]
	var patrie := ["casa_gb", "casa_fr", "casa_sp", "casa_up", "casa_au", "casa_pr", "casa_ru"]
	var p: Array = []
	# ---------------------------------------------------------------- 1. le regole di base
	p.append(_pg("Benvenuto nel Settecento",
		"[b]Struggle of Empires[/b] di Martin Wallace racconta le guerre fra le grandi potenze europee per il dominio del mondo, dal 1700 alla Guerra dei Sette Anni.\n\nIn questa partita sei l'[b]Inghilterra[/b]. Contro di te giocano tre intelligenze artificiali: [b]Francia[/b], [b]Spagna[/b] e [b]Russia[/b]. Province Unite, Austria e Prussia non sono giocate da nessuno: i loro pezzi stanno sulla mappa e contano come ostacoli e, a volte, come alleati.\n\nQuesto tutorial è una partita vera. I dadi sono fissati, quindi andrà sempre così: ti farò fare il piazzamento iniziale, l'asta delle alleanze e i tuoi primi [b]tre turni completi[/b], spiegando ogni regola nel momento in cui serve e il perché di ogni scelta. Poi continuerai da solo, con un consiglio a ogni decisione.\n\nCome si usa questo riquadro: premi [b]Avanti[/b] per proseguire e [b]Indietro[/b] per rileggere. Quando ti chiedo una mossa, il gioco accetta solo quella. Con [b]Riduci[/b] lo rimpicciolisci per guardare la mappa. La mappa si sposta trascinando, si ingrandisce con la rotella o con due dita, e in 3D si ruota con il tasto destro o ruotando due dita."))
	p.append(_pg("Come si vince",
		"Si giocano [b]tre guerre[/b]. Alla fine di ognuna si fanno i punti, e dopo la terza vince chi ha più Punti Vittoria (PV).\n\nI punti vengono solo dai [b]segnalini Controllo[/b] (i dischi con lo stemma) nelle [b]11 regioni evidenziate[/b]. In ogni regione si contano i segnalini di ogni potenza: chi ne ha di più prende il primo valore stampato sulla targhetta, il secondo prende il secondo valore e, negli Stati Tedeschi, in Europa Centrale e nel Mediterraneo, c'è anche un terzo posto.\n\nEsempio: Nord America vale 4 e 2. Stati Tedeschi vale 8, 5 e 3, ed è la regione più ricca.\n\n[b]I pari merito prendono tutti il valore pieno del loro posto[/b]: se due potenze hanno un segnalino ciascuno in Nord America, entrambe prendono 4 punti. Questo è il cuore della strategia: spesso basta un solo segnalino per prendere punti pieni.\n\nEserciti e flotte non danno punti: servono per conquistare e difendere i segnalini.",
		{"evid": pv}))
	p.append(_pg("La mappa",
		"La mappa ha tre tipi di zone.\n\n[b]Le colonie[/b] (evidenziate ora), nei cerchi: Nord America, Caraibi, Sud America, Africa, India e Indie Orientali. Ci si arriva via mare. Un Esercito può entrare in una colonia solo se lì c'è già una [b]tua Flotta[/b].\n\n[b]L'Europa[/b]: Baltico, Stati Tedeschi, Europa Centrale, Mediterraneo e Impero Ottomano. Dentro l'Europa gli eserciti si spostano liberamente.\n\n[b]Le patrie[/b] delle sette potenze. Non danno punti, ma è lì che nascono le nuove unità.\n\nLe flotte possono stare nelle colonie, nel Baltico, nel Mediterraneo e nella propria patria. Le flotte del Mediterraneo combattono anche per l'Impero Ottomano, che non ha mare suo.",
		{"evid": colonie}))
	p.append(_pg("La tua situazione",
		"All'inizio ogni potenza riceve [b]10 Oro[/b], [b]5 Popolazione[/b] e [b]5 segnalini Controllo[/b] pescati a caso.\n\nI tuoi sono evidenziati: [b]Caraibi[/b], [b]Indie Orientali[/b], [b]Baltico[/b], [b]Stati Tedeschi[/b] e [b]Mediterraneo[/b]. Un buon inizio: sei presente in regioni ricche, sia in Europa sia nelle colonie.\n\nSulla mappa ci sono anche i [b]segnalini neutrali[/b], le regioni non ancora sottomesse:\n- i segnalini con un numero (la loro forza di difesa): in Nord America ce n'è uno da [b]1[/b], negli Stati Tedeschi uno da 4 e uno da 2, nel Mediterraneo due da 2;\n- i segnalini [b]Colonizzare[/b], in Nord America, Africa e India, che si convertono senza combattere.\n\nClicca sulla tua riga nella colonna di destra per aprire la tua scheda nazionale, con la riserva dei pezzi e le tessere.",
		{"evid": ["caraibi", "indie", "baltico", "germania", "mediterraneo"]}))
	p.append(_pg("Oro, Popolazione e Tensione",
		"Tre risorse governano tutto.\n\n[b]Oro[/b]: paga gli attacchi (2 Oro ciascuno), le tessere, le aste e i viaggi andati male. Se ti manca, scatta la [b]Tassazione[/b]: ricevi 2 Oro ma prendi 1 Tensione, e si ripete finché serve.\n\n[b]Popolazione[/b]: si spende per costruire unità (1 ciascuna) e per Colonizzare (1). Alla fine di ogni guerra ne ricevi 5, fino a un massimo di 9.\n\n[b]Tensione[/b]: è il malcontento interno. Si prende per ogni unità persa in battaglia, per ogni Tassazione e per ogni unità lasciata affondare. Si toglie Passando: se in un turno passi un'azione senza attaccare (o le passi tutte e due) scende di 1. Alla fine della partita chi ha più Tensione perde 7 PV e il secondo 4 PV; chi arriva a 20 subisce una rivoluzione ed è fuori dalla vittoria.\n\nA fine guerra c'è la [b]rendita[/b]: incassi 1 Oro per ogni Popolazione e per ogni segnalino Controllo, e paghi 1 Oro per ogni unità sulla mappa. Un esercito grande costa caro."))
	# ---------------------------------------------------------------- 2. piazzamento
	p.append(_pg("Il piazzamento iniziale",
		"Prima della prima guerra ogni giocatore piazza [b]5 unità[/b], una alla volta e a turno. Tu cominci per primo.\n\nGli Eserciti e i Forti vanno in una regione che dà punti o nella tua patria; le Flotte in una regione con il mare o nella tua patria. Solo in questo momento puoi mettere eserciti direttamente nelle colonie senza avere già una flotta lì. Hai al massimo 14 eserciti, 8 flotte e 2 forti.\n\nIl nostro piano:\n1. Flotta in Nord America\n2. Esercito in Nord America, per attaccare subito il neutrale da 1\n3. Flotta nei Caraibi, a difesa del tuo Controllo\n4. Esercito negli Stati Tedeschi, la regione più ricca\n5. Forte negli Stati Tedeschi, per difenderla a lungo",
		{"evid": ["nordamerica", "caraibi", "germania"]}))
	p.append(_mv("Prima unità: Flotta in Nord America", "piazza", "f|nordamerica",
		"Le flotte sono la chiave delle colonie. Senza una tua Flotta in una colonia non puoi portarci eserciti. Inoltre, in una battaglia di terra, se solo tu hai flotte nella regione ricevi il [b]Supporto navale[/b]: +1 alla tua forza. Contro i segnalini neutrali vale sempre, perché i neutrali non hanno navi.\n\nScegli [b]Flotta in Nord America[/b] nel pannello a destra, oppure clicca sul Nord America e poi su Flotta.",
		"Ora piazza una Flotta in Nord America.", {"evid": ["nordamerica"], "vola": "nordamerica"}))
	p.append(_mv("Seconda unità: Esercito in Nord America", "piazza", "e|nordamerica",
		"Per attaccare un bersaglio a terra serve almeno un tuo [b]Esercito nella regione[/b]. Con un Esercito (forza 1) e il Supporto navale della flotta (+1) avrai forza 2 contro il neutrale da 1: un attacco favorevole già al primo turno.\n\nScegli [b]Esercito in Nord America[/b].",
		"Ora piazza un Esercito in Nord America.", {"evid": ["nordamerica"]}))
	p.append(_mv("Terza unità: Flotta nei Caraibi", "piazza", "f|caraibi",
		"I Caraibi valgono 5 e 3 e lì hai già un segnalino. Una Flotta lì darà il Supporto navale a chi difende quel segnalino, e in futuro ti permetterà di portarci eserciti.\n\nGuarda intanto cosa fanno le IA: dopo ogni tuo pezzo piazzano il loro.",
		"Ora piazza una Flotta nei Caraibi.", {"evid": ["caraibi"], "vola": "caraibi"}))
	p.append(_mv("Quarta unità: Esercito negli Stati Tedeschi", "piazza", "e|germania",
		"Gli Stati Tedeschi valgono 8, 5 e 3: tutti vorranno esserci, e infatti le IA stanno già ammassando eserciti lì. In difesa la forza di un segnalino è il numero di eserciti del difensore nella regione (più 2 per ogni forte). Un tuo Esercito rende il tuo segnalino meno appetibile.",
		"Ora piazza un Esercito negli Stati Tedeschi.", {"evid": ["germania"], "vola": "germania"}))
	p.append(_mv("Quinta unità: Forte negli Stati Tedeschi", "piazza", "fo|germania",
		"Il [b]Forte[/b] dà +2 alla difesa dei tuoi segnalini nella regione e non viene mai eliminato nei pareggi. Non può lasciare la regione in cui si trova (solo dalla patria si può spostare). Ne hai solo 2: mettili dove conta.\n\nCon Esercito e Forte il tuo segnalino negli Stati Tedeschi si difende con forza 3, più i dadi.",
		"Ora piazza un Forte negli Stati Tedeschi.", {"evid": ["germania"]}))
	# ---------------------------------------------------------------- 3. l'asta
	p.append(_pg("Le Grandi Alleanze",
		"Il piazzamento è finito. Comincia la [b]Prima Guerra[/b] con l'asta delle alleanze.\n\nLe potenze si dividono in due Grandi Alleanze, la [b]Rossa[/b] e la [b]Blu[/b]. Conta moltissimo:\n- puoi attaccare [b]solo i segnalini Controllo dell'altra alleanza[/b], più i neutrali;\n- gli alleati possono unirsi alle tue battaglie;\n- [b]l'ordine di ingresso è l'ordine di gioco[/b] di questa guerra: primo Rosso, primo Blu, secondo Rosso, secondo Blu.\n\nChi ha il martelletto propone una coppia, una potenza per la Rossa e una per la Blu, e un'offerta in Oro. Gli altri, a turno, passano o rilanciano con una coppia qualsiasi. Quando tutti gli altri hanno passato, chi ha fatto l'offerta più alta paga e la sua coppia entra nelle alleanze. Si ripete finché tutti sono schierati. Il martelletto gira a ogni guerra."))
	p.append(_mv("Proponi la prima coppia", "asta", "gb|fr|1",
		"Proviamo a metterci [b]contro la Francia[/b]: ha segnalini in Nord America, nei Caraibi e nelle Indie Orientali, dove noi abbiamo flotte. Da nemici potremmo attaccarli.\n\nNel pannello a destra scegli [b]Alleanza Rossa: Inghilterra[/b], [b]Alleanza Blu: Francia[/b], offerta [b]1[/b] Oro, poi premi [b]Proponi[/b]. Paghi solo se nessuno rilancia.",
		"Scegli Rossa: Inghilterra, Blu: Francia, offerta 1, poi Proponi."))
	p.append(_gi("Le IA rispondono", "asta",
		"Ora le altre potenze, una alla volta, decidono se passare o rilanciare."))
	p.append(_pg("La Spagna rilancia",
		"La Francia ha passato. La [b]Spagna[/b] ha rilanciato con 2 Oro e ha proposto un'altra coppia: [b]Spagna nella Rossa, Inghilterra nella Blu[/b]. La Russia ha passato.\n\nChe cosa significa? La Spagna ci vuole come nemici: ha segnalini in India e nelle Indie Orientali, vicino ai nostri, e vuole poterci attaccare.\n\nPossiamo rilanciare (almeno 3 Oro) o passare. Lezione importante: [b]passare non costa nulla[/b], e la sistemazione proposta non ci danneggia molto. Lasciamo che sia la Spagna a pagare 2 Oro."))
	p.append(_mv("Passa", "asta", "passa",
		"Premi [b]Passo[/b] nel pannello a destra.",
		"Premi Passo."))
	p.append(_gi("La seconda asta", "asta",
		"La Spagna ha vinto l'asta e paga 2 Oro: Spagna nella Rossa, Inghilterra nella Blu. Restano da sistemare Francia e Russia, e si ricomincia con una nuova proposta."))
	p.append(_pg("Francia o Russia?",
		"La Francia ha proposto Francia nella Rossa e Russia nella Blu per 1 Oro; la Spagna ha passato; la Russia ha rilanciato con [b]Russia nella Rossa, Francia nella Blu[/b] per 2 Oro. Chi sta nella Rossa giocherà prima del suo avversario nella Blu, per questo se lo contendono. In ogni caso:\n- [b]Alleanza Rossa[/b]: Spagna, Russia\n- [b]Alleanza Blu[/b]: Inghilterra, Francia\n\nPer noi va bene in entrambi i casi: la Francia sarà alleata e la Russia, che ha un segnalino in Nord America accanto al nostro esercito, sarà un bersaglio. Passiamo."))
	p.append(_mv("Passa ancora", "asta", "passa",
		"Premi [b]Passo[/b].",
		"Premi Passo."))
	p.append(_mv("Francia e Russia si contendono il posto", "asta", "passa",
		"La Francia ha rilanciato a 3 Oro e la Russia a 4: si contendono il primo posto nell'ordine di gioco. Non ci riguarda: passa ancora, e saranno loro a spendere Oro.",
		"Premi Passo."))
	p.append(_gi("Si combatte!", "tratt_risp",
		"La Russia ha vinto la seconda asta per 4 Oro. Le alleanze sono fatte. Ordine di gioco: [b]Spagna, Inghilterra, Russia, Francia[/b]. Comincia il Round 1 e tocca alla Spagna."))
	# ---------------------------------------------------------------- 4. round 1, la Spagna attacca
	p.append(_pg("Turni e round",
		"Con 4 giocatori ogni guerra dura [b]6 round[/b]. In ogni round ciascuno fa un turno, nell'ordine delle alleanze.\n\nIn un turno hai [b]due azioni[/b]: due azioni regolari, oppure una regolare e una speciale (al massimo una speciale per turno).\n- [b]Regolari[/b]: Costruire 1 unità, Muovere 2 unità, Attaccare (2 Oro), Colonizzare, Costa d'Oro, Passare.\n- [b]Speciali[/b]: stipulare un'Alleanza Locale, Reclamare una tessera, usare un'Azione segreta.\n- [b]Gratuite[/b], in qualsiasi momento del turno: le azioni delle tessere e le trattative con le altre potenze.\n\nLa Spagna ha appena dichiarato un attacco al segnalino della [b]Francia, nostra alleata, negli Stati Tedeschi[/b]."))
	p.append(_pg("Come si svolge un attacco",
		"Un attacco segue sempre lo stesso ordine:\n1. L'attaccante paga 2 Oro e sceglie il bersaglio.\n2. [b]Trattative informali[/b]: attaccante e difensore possono offrire Oro agli alleati che hanno unità nella regione, perché si uniscano. La promessa non è vincolante.\n3. [b]Chiamata agli alleati[/b]: ogni alleato presente decide se impegnare le sue unità.\n4. [b]Battaglia navale[/b], se entrambi i lati hanno flotte: chi vince prende il Supporto navale. Se le flotte ce le ha un solo lato, il Supporto navale va a lui senza combattere.\n5. [b]Battaglia terrestre[/b], che decide il segnalino.\n\nLa Spagna ha pagato 2 Oro alla Russia, che ha promesso di unirsi. La Francia ci offre [b]1 Oro[/b] perché impegniamo il nostro esercito negli Stati Tedeschi."))
	p.append(_mv("Accetta l'offerta della Francia", "tratt_risp", "accetta",
		"Accettiamo: 1 Oro gratis e aiutiamo un alleato in una regione da 8 punti. Se ora non mantenessimo la promessa le IA se ne ricorderebbero, e in futuro i nostri alleati ci aiuterebbero meno volentieri.\n\nScegli [b]Accetta[/b].",
		"Scegli Accetta."))
	p.append(_mv("Impegna l'esercito", "impegno", "e",
		"Manteniamo la parola: impegna l'[b]Esercito[/b].\n\nNota: il nostro Forte non aiuta la Francia. I forti contano solo nella difesa dei segnalini del loro proprietario. In battaglia le perdite toccano prima alle unità di chi combatte in prima persona, e solo dopo agli alleati.",
		"Scegli Impegna 1 Esercito.", {"evid": ["germania"], "vola": "germania"}))
	p.append(_gi("La battaglia negli Stati Tedeschi", "tratt",
		"Guarda la battaglia sulla mappa: i pezzi coinvolti sono cerchiati, rossi per chi attacca e blu per chi difende."))
	p.append(_pg("Come si legge una battaglia",
		"La [b]forza[/b] di ogni lato è: +1 per ogni Esercito, +2 per ogni Forte del difensore, +1 di Supporto navale, +1 per un'Alleanza Locale nella regione, più alcune tessere.\n\nOgni lato tira [b]due dadi[/b] e aggiunge la [b]differenza[/b] fra i due. Vince il totale più alto.\n\nNegli Stati Tedeschi: Spagna e Russia avevano forza 3, con dadi 3 e 5 (differenza 2): totale 5. Francia e noi forza 2, dadi 2 e 3 (differenza 1): totale 3. Ha vinto la Spagna.\n- [b]Chi perde[/b] elimina un'unità, e ogni unità persa dà 1 Tensione. Ha perso l'esercito la Francia, non noi.\n- [b]Se vince l'attaccante[/b] strappa un segnalino: la Spagna ha preso il posto della Francia negli Stati Tedeschi.\n- [b]In caso di pareggio[/b] perdono un'unità entrambi e l'attacco fallisce.\n- Chi tira [b]un 7 con i due dadi[/b] perde un'unità in più, anche se vince.\n\nOra la Spagna attacca [b]il nostro segnalino nel Mediterraneo[/b]!",
		{"evid": ["mediterraneo"]}))
	p.append(_mv("Chiedi aiuto alla Francia", "tratt", "offri|1|2",
		"Nel Mediterraneo non abbiamo unità: da soli difenderemmo con forza 0. Ma la [b]Francia[/b], nostra alleata, ha un esercito lì. Come difensori possiamo offrirle Oro perché si unisca.\n\nOffriamo [b]2 Oro[/b]: un'offerta generosa ha più probabilità di essere accettata, e perdere un segnalino in una regione da 6 punti costa molto di più.\n\nScegli [b]Offri 2 Oro a Francia[/b].",
		"Scegli l'offerta di 2 Oro alla Francia.", {"evid": ["mediterraneo"], "vola": "mediterraneo"}))
	p.append(_gi("La battaglia del Mediterraneo", "azione",
		"La Francia decide se accettare, poi si combatte."))
	p.append(_pg("Una sconfitta istruttiva",
		"La Francia ha accettato i 2 Oro e ha impegnato il suo esercito, ma i dadi sono stati crudeli: la Spagna ha fatto 1 + 3 = 4, noi 1 + 1 = 2. La Francia ha perso il suo esercito (le perdite toccano a chi ha unità in campo) e noi il segnalino del Mediterraneo.\n\nDue lezioni:\n- un segnalino [b]senza truppe[/b] è un invito per i nemici;\n- la Spagna ha tirato 5 e 2, cioè [b]7[/b]: pur vincendo ha perso il suo esercito. Il 7 è il rischio di ogni battaglia.\n\nNon abbiamo perso unità, quindi niente Tensione per noi. Abbiamo dato 2 Oro alla Francia, ma prima ne avevamo ricevuto 1 da lei. Ci restano [b]9 Oro[/b].\n\nE ora [b]tocca a noi[/b]!"))
	# ---------------------------------------------------------------- 5. il nostro Round 1
	p.append(_pg("Il tuo primo turno",
		"Il pannello a destra elenca tutte le azioni possibili. Il nostro piano per questo turno:\n1. [b]Attaccare il neutrale da 1 in Nord America[/b]. Forza: 1 Esercito + 1 Supporto navale = 2, contro 1. Costo: 2 Oro. Se vinciamo il neutrale diventa un nostro segnalino Controllo, senza farci nemici.\n2. [b]Colonizzare[/b] una regione.\n\nPrima di attaccare guarda le probabilità: con 2 contro 1 vinci più di metà delle volte. I dadi aggiungono da 0 a 5, quindi anche un attacco favorevole può fallire.",
		{"evid": ["nordamerica"], "ogg": ["n:nordamerica:1"], "vola": "nordamerica"}))
	p.append(_mv("Attacca", "azione", "attacca",
		"Scegli [b]Eseguire 1 attacco (2 Oro)[/b], oppure clicca direttamente sul segnalino neutrale con il numero 1 in Nord America: la mappa farà le scelte giuste in un colpo solo.",
		"Scegli Eseguire 1 attacco, oppure clicca sul neutrale da 1 in Nord America.", {"ogg": ["n:nordamerica:1"], "evid": ["nordamerica"]}))
	p.append(_mv("Dove attacchi", "att_reg", "nordamerica",
		"Scegli la regione: [b]Nord America[/b].",
		"Scegli Nord America.", {"evid": ["nordamerica"]}))
	p.append(_mv("Che cosa attacchi", "att_bers", "n|4",
		"Scegli il [b]segnalino neutrale con forza 1[/b]. I neutrali non ricevono aiuti e cedono il Supporto navale a chi attacca con le flotte.",
		"Scegli il segnalino neutrale con forza 1.", {"ogg": ["n:nordamerica:1"]}))
	p.append(_pg("Vittoria in Nord America",
		"Abbiamo fatto 2 + 1 = 3 contro 1 + 0 = 1: il neutrale è sconfitto e diventa un [b]nostro segnalino Controllo[/b].\n\nOra in Nord America hanno un segnalino a testa Inghilterra, Francia e Russia: tutti a pari merito al primo posto, quindi [b]4 punti ciascuno[/b]. I segnalini neutrali a volte nascondono un premio (3 Oro o 1 PV) per chi li conquista.\n\nIl Nord America si vede anche nella colonna di destra: la cifra fra parentesi accanto ai PV è il punteggio che faresti se la guerra finisse adesso.",
		{"anim": true, "evid": ["nordamerica"]}))
	p.append(_pg("Colonizzare",
		"Seconda azione. I segnalini [b]Colonizzare[/b] diventano tuoi pagando [b]1 Popolazione[/b], senza combattere e senza bisogno di unità. Ce ne sono in Nord America, Africa e India. Per turno puoi fare una sola fra Colonizzare e Costa d'Oro.\n\nDove conviene? Ragioniamo sui punti:\n- [b]Nord America[/b]: siamo già primi a pari merito. Un secondo segnalino non ci darebbe punti in più ora: farebbe solo scendere gli altri.\n- [b]Africa[/b] (3 e 2): c'è solo la Spagna. Pareggiando prenderemmo 3.\n- [b]India[/b] (5 e 3): c'è solo la Spagna. Pareggiando il primo posto prenderemmo [b]5 punti con una sola azione[/b].\n\nScegliamo l'India.",
		{"evid": ["india", "africa", "nordamerica"]}))
	p.append(_mv("Colonizzare", "azione", "colonizza",
		"Scegli [b]Colonizzare (1 Popolazione)[/b], oppure clicca il segnalino Colonizzare in India.",
		"Scegli Colonizzare, oppure clicca il segnalino Colonizzare in India.", {"ogg": ["n:india:col"], "evid": ["india"], "vola": "india"}))
	p.append(_mv("In India", "colonizza", "22",
		"Scegli [b]Colonizzare: India[/b].",
		"Scegli Colonizzare: India.", {"ogg": ["n:india:col"], "evid": ["india"]}))
	p.append(_pg("Diplomazia: trattare",
		"Le azioni sono finite, ma puoi ancora [b]trattare[/b]: è gratuito, e puoi farlo una volta per turno con ciascuna potenza.\n- [b]Chiedere Oro[/b] a qualcuno per non attaccarlo in questo turno (se hai ancora azioni).\n- [b]Offrire Oro[/b] a qualcuno perché non ti attacchi per il resto della guerra.\n\nNessun accordo è vincolante, ma chi tradisce perde la fiducia degli altri: le IA tengono il conto.\n\nLa Spagna ci ha già attaccato una volta. Proviamo a comprarci la pace: offriamo 2 Oro."))
	p.append(_mv("Tratta con la Spagna", "azione", "ricatto|2",
		"Premi [b]Trattare con Spagna[/b].",
		"Premi Trattare con Spagna."))
	p.append(_mv("Offri 2 Oro", "ricatto_quanto", "dai|2",
		"Scegli [b]Offri 2 Oro in cambio di non essere attaccato[/b].",
		"Scegli l'offerta di 2 Oro."))
	p.append(_pg("La Spagna rifiuta",
		"La Spagna ha rifiutato: per lei i nostri segnalini valgono più di 2 Oro. Quando una proposta viene rifiutata [b]non si paga nulla[/b]: tentare non costa niente.\n\nOra chiudi il turno. Nota sulla Tensione: se in un turno [b]passi un'azione senza attaccare[/b] la Tensione scende di 1. Noi abbiamo attaccato, ma siamo ancora a Tensione 0."))
	p.append(_mv("Fine del turno", "azione", "fine",
		"Premi [b]Fine del turno[/b].",
		"Premi Fine del turno."))
	p.append(_gi("Tocca alla Russia", "impegno",
		"Ora giocano la Russia e poi la Francia."))
	p.append(_pg("Una flotta che non rischia",
		"La [b]Russia attacca la Francia nei Caraibi[/b] e la Spagna si unisce con un esercito. La Francia ci chiama: noi nei Caraibi abbiamo una [b]Flotta[/b].\n\nIn una battaglia di terra una Flotta impegnata non combatte: se solo il nostro lato ha flotte, dà al difensore il [b]Supporto navale (+1)[/b]. E siccome le perdite di una battaglia di terra sono sempre eserciti, la nostra flotta [b]non rischia nulla[/b]. Aiutare così è sempre conveniente.",
		{"evid": ["caraibi"], "vola": "caraibi"}))
	p.append(_mv("Impegna la Flotta", "impegno", "f",
		"Scegli [b]Impegna 1 Flotta[/b].",
		"Scegli Impegna 1 Flotta.", {"evid": ["caraibi"]}))
	p.append(_gi("Fine del Round 1", "azione",
		"Guarda la battaglia, poi i turni di Russia e Francia e l'inizio del Round 2."))
	p.append(_pg("Cosa è successo",
		"[b]Caraibi[/b]: la Russia ha fatto 2 + 5 = 7, la Francia 1 + 3 = 4 (il suo 1 era il nostro Supporto navale). La Russia ha vinto e preso il segnalino, ma ha tirato 1 e 6, cioè 7, e ha perso un esercito.\n\n[b]Turno francese[/b]: la Francia ha strappato alla Spagna il segnalino dell'Europa Centrale e ha fallito nel Baltico con un [b]pareggio[/b] (6 contro 6): in parità perdono entrambi e il segnalino resta al difensore.\n\n[b]Round 2[/b]: la Spagna ha colonizzato il Nord America e ha mandato un esercito nel Baltico.\n\nOgni round ripete lo stesso ordine. Ora tocca di nuovo a noi."))
	# ---------------------------------------------------------------- 6. il nostro Round 2
	p.append(_pg("Le tessere",
		"Le [b]tessere[/b] stanno a destra del tabellone (e nel bottone Tessere in alto). Reclamarne una è un'azione speciale. Hanno un costo in Oro e cinque tipi, che corrispondono alle fasce colorate della tua scheda nazionale:\n- [b]Azione gratuita[/b] (fascia bianca): un'azione extra da usare una volta per guerra;\n- [b]Miglioramento[/b] (fascia verde): un vantaggio permanente;\n- [b]Commercio[/b] (fascia verde anch'esse): una volta per guerra, 1 Oro per ogni tuo segnalino in una certa regione;\n- [b]Tattica[/b] (fascia arancio): un colpo decisivo in battaglia, una volta sola, poi torna sul tabellone;\n- [b]Azione immediata[/b]: ha effetto subito e poi si scarta.\n\nAll'inizio la migliore è [b]Agricoltura migliorata[/b]: costa 0, dà subito +1 Popolazione e, come azione gratuita, +1 Popolazione una volta per guerra.",
		{"ogg": ["tessera:agricoltura"]}))
	p.append(_mv("Reclama l'Agricoltura migliorata", "azione", "tessera",
		"Scegli [b]Reclamare 1 tessera[/b], oppure clicca la pila di tessere Agricoltura sul tabellone.",
		"Scegli Reclamare 1 tessera, oppure clicca la tessera Agricoltura migliorata sul tabellone.", {"ogg": ["tessera:agricoltura"]}))
	p.append(_mv("Agricoltura migliorata", "tessera", "agricoltura",
		"Scegli la tessera [b]Agricoltura migliorata[/b].",
		"Scegli Agricoltura migliorata.", {"ogg": ["tessera:agricoltura"]}))
	p.append(_pg("Un'azione gratuita",
		"Ora nel pannello compare la sezione [b]Azioni gratuite (tessere)[/b]. Le azioni gratuite non consumano le tue due azioni, e ognuna si usa una volta per guerra: alla guerra successiva torna disponibile.\n\nUsiamola subito: +1 Popolazione. La Popolazione ci serve per costruire."))
	p.append(_mv("Usa l'Agricoltura", "azione", "lib|0",
		"Premi il bottone dell'[b]Agricoltura migliorata[/b] nelle azioni gratuite.",
		"Premi l'azione gratuita dell'Agricoltura migliorata."))
	p.append(_pg("Costruire e viaggiare",
		"Seconda azione: [b]Costruire[/b]. Costa 1 Popolazione. La nuova unità appare nella tua patria e, nella stessa azione, puoi subito spostarla.\n\nCostruiamo un [b]Esercito[/b] e mandiamolo in [b]Nord America[/b], accanto all'altro: là c'è un segnalino russo che il prossimo turno vogliamo attaccare. Possiamo mandarlo perché lì abbiamo una Flotta.\n\nDall'Europa alle Americhe si attraversa il [b]mare aperto[/b] e si tira il [b]dado del Viaggio[/b]: su 6 facce, 4 vanno bene, una blocca la nave in porto (si paga 1 Oro per partire comunque) e una la mette in pericolo di affondare."))
	p.append(_mv("Costruisci", "azione", "costruisci",
		"Scegli [b]Costruire 1 unità[/b].",
		"Scegli Costruire 1 unità."))
	p.append(_mv("Un Esercito", "costr_tipo", "e",
		"Scegli [b]Esercito[/b].",
		"Scegli Esercito."))
	p.append(_mv("Verso il Nord America", "costr_dest", "nordamerica",
		"Scegli [b]Nord America (mare aperto)[/b] e guarda rotolare il dado.",
		"Scegli Nord America.", {"evid": ["nordamerica"]}))
	p.append(_pg("Tempesta!",
		"Il dado dice [b]AFFONDA[/b]: la nave è nella tempesta. Tre possibilità:\n- [b]pagare 3 Oro[/b] e completare il viaggio;\n- [b]pagare 2 Oro[/b] e restare in patria;\n- [b]lasciar affondare[/b] l'unità: perdi l'esercito, la Popolazione che hai speso e prendi 1 Tensione.\n\nVogliamo l'esercito in Nord America per il prossimo attacco, e abbiamo 7 Oro: paghiamo 3. Se non avessimo abbastanza Oro scatterebbe la Tassazione.",
		{"anim": true}))
	p.append(_mv("Paga 3 Oro", "dsm", "paga3",
		"Scegli [b]Paga 3 Oro e completa il viaggio[/b].",
		"Scegli Paga 3 Oro e completa il viaggio."))
	p.append(_mv("Fine del secondo turno", "azione", "fine",
		"Abbiamo usato un'azione speciale (la tessera) e una regolare (Costruire), più un'azione gratuita. Premi [b]Fine del turno[/b].",
		"Premi Fine del turno."))
	p.append(_gi("Le IA giocano", "azione",
		"Russia e Francia finiscono il Round 2, poi la Spagna apre il Round 3."))
	p.append(_pg("Il pareggio protegge chi difende",
		"La Russia ha colonizzato l'Africa e preso alla Francia il segnalino dell'Impero Ottomano. La Francia ha fallito un attacco in Sud America.\n\nPoi la [b]Spagna ha attaccato il nostro segnalino nel Baltico[/b]: lei 1 + 0 = 1, noi 0 + 1 = 1. [b]Pareggio[/b]: la Spagna ha perso l'esercito e noi abbiamo tenuto il segnalino. Non avevamo truppe lì, quindi non abbiamo perso nulla.\n\nIn caso di parità l'attacco fallisce sempre. Per questo un segnalino con anche solo un'unità a difenderlo è molto più sicuro.",
		{"evid": ["baltico"]}))
	# ---------------------------------------------------------------- 7. il nostro Round 3
	p.append(_pg("Le Alleanze Locali",
		"Sulla mappa ci sono 11 [b]Alleanze Locali[/b], i piccoli alleati del luogo: Nativi americani, Gauchos, Portogallo, Nawab, Svezia, Danimarca, Sassonia, Baviera, Cosacchi, Napoli e Ottomani.\n\nStipularne una è un'azione speciale. Alcune costano 1 Oro, altre nulla. Per il resto della guerra danno [b]+1 in tutti i tuoi combattimenti nella loro regione[/b], in attacco e in difesa. Alcune valgono anche per le battaglie navali. A fine guerra tornano disponibili per tutti. Puoi averne al massimo 6.\n\nI [b]Nativi americani[/b] sono gratis e valgono in Nord America: proprio dove vogliamo attaccare la Russia.",
		{"ogg": ["la:nativi"], "evid": ["nordamerica"], "vola": "nordamerica"}))
	p.append(_mv("Stipula l'alleanza", "azione", "alleanza",
		"Scegli [b]Stipulare un'Alleanza Locale[/b], oppure clicca il segnalino dei Nativi americani sulla mappa.",
		"Scegli Stipulare un'Alleanza Locale, oppure clicca i Nativi americani.", {"ogg": ["la:nativi"]}))
	p.append(_mv("Nativi americani", "alleanza", "nativi",
		"Scegli i [b]Nativi americani[/b].",
		"Scegli i Nativi americani.", {"ogg": ["la:nativi"]}))
	p.append(_pg("Attaccare un nemico",
		"La Russia è nell'alleanza nemica e ha un segnalino in Nord America [b]senza truppe[/b] a difenderlo. La nostra forza:\n- 2 Eserciti: +2\n- Nativi americani: +1\n- Supporto navale (la Russia non ha flotte lì): +1\n\nTotale [b]4 contro 0[/b], più i dadi. Il rischio residuo è solo il 7, che ci farebbe perdere un esercito anche vincendo.\n\nSe vinciamo avremo 2 segnalini in Nord America contro 1 di Francia e Spagna: [b]primi da soli[/b]. Prenderemo 4 punti e gli altri ne avranno 2.",
		{"ogg": ["c:nordamerica:ru"], "evid": ["nordamerica"]}))
	p.append(_mv("Attacca la Russia", "azione", "attacca",
		"Scegli [b]Eseguire 1 attacco[/b], oppure clicca il segnalino Controllo russo in Nord America.",
		"Scegli Eseguire 1 attacco, oppure clicca il segnalino russo in Nord America.", {"ogg": ["c:nordamerica:ru"]}))
	p.append(_mv("In Nord America", "att_reg", "nordamerica",
		"Scegli [b]Nord America[/b].",
		"Scegli Nord America.", {"evid": ["nordamerica"]}))
	p.append(_mv("Il Controllo russo", "att_bers", "c|ru",
		"Scegli [b]Controllo di Russia[/b].",
		"Scegli Controllo di Russia.", {"ogg": ["c:nordamerica:ru"]}))
	p.append(_pg("Primi in Nord America",
		"Abbiamo fatto 4 + 3 = 7 contro 0 + 3 = 3: il segnalino russo è nostro. Ora in Nord America abbiamo 2 segnalini e Francia e Spagna uno ciascuna.\n\nIn tre turni abbiamo:\n- conquistato un neutrale e un segnalino nemico;\n- colonizzato l'India;\n- preso una tessera e un'Alleanza Locale;\n- tutto senza perdere unità: la nostra [b]Tensione è ancora 0[/b].\n\nCi restano 2 Oro e 5 Popolazione.",
		{"anim": true, "evid": ["nordamerica"]}))
	p.append(_pg("La fine della guerra",
		"Dopo il sesto round la guerra finisce, e succede questo:\n1. [b]Rendita[/b]: Oro pari a Popolazione più segnalini Controllo, meno 1 per ogni tua unità sulla mappa. Se il conto è negativo paghi, e se non puoi scatta la Tassazione.\n2. [b]Popolazione[/b]: +5, fino a 9.\n3. [b]Punteggio[/b] delle 11 regioni.\n4. Le Alleanze Locali tornano al loro posto; le tessere Azione gratuita tornano disponibili.\n5. Nuovi segnalini neutrali e nuova asta. Il martelletto passa al giocatore successivo.\n\nDopo la terza guerra si applicano le penalità della Tensione e vince chi ha più PV."))
	p.append(_mv("Chiudi il terzo turno", "azione", "fine",
		"Premi [b]Fine del turno[/b].",
		"Premi Fine del turno."))
	p.append(_gi("Le azioni segrete", "azione",
		"Russia e Francia chiudono il Round 3, poi la Spagna apre il Round 4."))
	p.append(_pg("Le azioni segrete",
		"Nel suo turno la [b]Russia ha incitato una rivolta in Sud America[/b] contro la Spagna, che è sua alleata! È un'[b]azione segreta[/b], un'azione speciale con regole proprie:\n- [b]Pirati[/b]: forza 1, colpisce un segnalino in una colonia, come battaglia navale;\n- [b]Rivolta[/b]: forza 3, colpisce un segnalino nelle Americhe.\n\nColpiscono [b]chiunque, anche gli alleati[/b], e nessuno può aiutare il difensore. Se riescono, il segnalino colpito viene coperto e non conta più finché qualcuno non sconfigge pirati o ribelli. Questa volta la rivolta è fallita.\n\nSono il modo di colpire un rivale che sta nella tua stessa alleanza."))
	# ---------------------------------------------------------------- 8. strategia
	p.append(_pg("Strategia 1: punti e posizioni",
		"- [b]I pari merito prendono punti pieni[/b]. Un segnalino solo, in una regione dove il primo ne ha uno, vale come esserci da soli. Spesso conviene essere presenti in tante regioni piuttosto che ammassare segnalini in poche.\n- Negli [b]Stati Tedeschi[/b], in [b]Europa Centrale[/b] e nel [b]Mediterraneo[/b] paga anche il terzo posto: sono regioni dove tutti segnano qualcosa, e dove serve difendersi bene.\n- I segnalini [b]neutrali e Colonizzare[/b] sono i Controlli più economici: niente nemici, niente rischi diplomatici. Prendili presto, prima degli altri.\n- Guarda la [b]proiezione[/b] tra parentesi nella colonna dei giocatori: ti dice chi sta vincendo questa guerra.\n- I segnalini [b]senza truppe[/b] sono i bersagli preferiti. Un Esercito o un Forte nelle regioni ricche scoraggia gli attacchi."))
	p.append(_pg("Strategia 2: economia e Tensione",
		"- [b]Ogni unità costa 1 Oro di rendita[/b] a fine guerra. Un'armata grande ti impoverisce: costruisci quello che userai.\n- La [b]Popolazione[/b] torna a +5 ogni guerra, fino a 9: quella che avanzi rende 1 Oro ciascuna, ma non accumularne troppa.\n- La [b]Tensione[/b] decide molte partite: -7 PV a chi ne ha di più, -4 al secondo. Evita battaglie a rischio di 7, evita la Tassazione, e [b]passa[/b] quando non hai niente di utile da fare: passare un'azione in un turno senza attacchi toglie 1 Tensione.\n- [b]Riforma del governo[/b] (gratuita) toglie subito 2 Tensione; la [b]Banca[/b] rende la Tassazione meno dolorosa.\n- Le flotte impegnate nelle battaglie di terra degli alleati danno +1 senza rischi: è aiuto gratuito che gli alleati ricambiano."))
	p.append(_pg("Strategia 3: alleanze e diplomazia",
		"- Nell'asta pensa a [b]chi vuoi poter attaccare[/b] (i nemici) e a [b]chi ti minaccia[/b] (meglio averlo alleato). Anche l'[b]ordine di gioco[/b] conta: chi gioca prima può colpire per primo.\n- [b]Passare non costa nulla[/b]: spesso qualcun altro paga per un'alleanza che va bene anche a te.\n- Pagare [b]1 o 2 Oro[/b] a un alleato presente nella regione può ribaltare una battaglia. E [b]mantenere le promesse[/b] rende gli alleati più disponibili.\n- [b]Chiedere Oro[/b] a una potenza che puoi attaccare è un modo per incassare senza combattere.\n- Le alleanze cambiano a ogni guerra: il nemico di oggi può essere l'alleato di domani."))
	p.append(_pg("Strategia 4: tessere e azioni speciali",
		"Le tessere che rendono di più nel tempo:\n- [b]Agricoltura migliorata[/b]: gratuita, +1 Popolazione subito e una volta per guerra. Con più copie anche l'Industria rende di più.\n- [b]Riforma del governo[/b]: gratuita, toglie subito 2 Tensione. Prendila quando la Tensione sale.\n- [b]Banca[/b] (2 Oro): la Tassazione dà 3 Oro invece di 2.\n- [b]Logistica[/b] (1 Popolazione): muovi un'unità in più. [b]Ministero della Guerra[/b] (8 Oro): un attacco gratis per guerra.\n- [b]Mercenari[/b] e [b]Milizia[/b]: più eserciti con meno Popolazione.\n- [b]Addestramento dell'esercito[/b] e [b]navale[/b]: +1 in battaglia se ne hai più dell'avversario.\n- Le tessere di [b]Commercio[/b] rendono Oro a ogni guerra se hai segnalini nella loro regione.\n- Le [b]Riserve[/b] fanno ritirare i dadi una volta per guerra. Le [b]Tattiche[/b] (Blocco navale, Ritirata combattendo, Attacco a sorpresa) decidono una battaglia importante.\n\nUn'[b]Alleanza Locale[/b] presa un turno prima di un attacco vale come un esercito in più, senza costi di rendita."))
	p.append(_pg("Ora tocca a te",
		"La parte guidata è finita: siamo al [b]Round 4 della Prima Guerra[/b]. Hai 2 Oro, 5 Popolazione e Tensione 0. Hai segnalini in Nord America (2), Caraibi, India, Indie Orientali, Baltico e Stati Tedeschi: secondo la proiezione faresti circa [b]31 PV[/b], appena dietro Spagna e Russia.\n\nDa qui in poi giochi liberamente. Il riquadro resta come [b]consigliere[/b]: a ogni decisione ti ricorda le regole che servono e qualche idea strategica. Puoi ridurlo con Riduci.\n\nUn suggerimento per questo turno: con soli 2 Oro conviene un'azione che non costi Oro. Per esempio una seconda Agricoltura migliorata (gratuita), un esercito costruito e mandato a difendere un segnalino scoperto, oppure Passare.\n\nLa partita del tutorial non viene salvata: quando vuoi, comincia una partita vera dal menu. Buona guerra!"))
	return p
