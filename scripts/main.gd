## Struggle of Empires - versione digitale (uso personale).
## Menu, partita contro l'IA, partita online (Firebase), salvataggi, plancia e interfaccia.
extends Node

const F_TITOLO := preload("res://assets/font/IMFellSC.ttf")
const F_SOTTO := preload("res://assets/font/IMFell.ttf")
const F_CORSIVO := preload("res://assets/font/IMFellCorsivo.ttf")
const F_BASE := preload("res://assets/font/EBGaramond.ttf")

const C_CARTA := Color(0.93, 0.87, 0.73)
const C_CARTA_SCURA := Color(0.84, 0.76, 0.6)
const C_INCHIOSTRO := Color(0.2, 0.13, 0.07)
const C_LEGNO := Color(0.13, 0.09, 0.06)
const C_LEGNO2 := Color(0.22, 0.15, 0.09)
const C_CERALACCA := Color(0.58, 0.1, 0.07)
const C_ORO := Color(0.86, 0.69, 0.32)
const C_SPENTO := Color(0.45, 0.36, 0.26)
const C_ROSSA := Color(0.72, 0.13, 0.1)
const C_BLU := Color(0.16, 0.3, 0.62)
const SALVA_LOCALE := "user://partita_struggle.json"

var F_TESTO: FontVariation
var F_GRASSETTO: FontVariation

var ui: CanvasLayer
var schermo: Control
var net: Rete
var m: Motore
var ia: IA
var plancia: Plancia

# partita
var in_partita := false
var online := false
var codice := ""
var mio_posto := 0
var attesa := 0.0
var velocita := 1.0
var richiesta_mostrata := -1
var aspetto_rete := false
var salvataggio_in_corso := false
var ultimo_salvataggio := 0.0
var ultimo_cb_visto := -1
var ultimo_evento_visto := -1
var popup_aperto := false

# scelte del menu
var scelta_np := 4
var scelta_pot := "gb"
var scelta_nome := ""

# nodi dell'interfaccia di gioco
var top_info: Label
var top_turno: Label
var colonna_giocatori: VBoxContainer
var diario: RichTextLabel
var pannello_dec: VBoxContainer
var titolo_dec: Label
var testo_dec: Label
var scroll_dec: ScrollContainer
var info_regione: PanelContainer
var info_regione_lbl: RichTextLabel
var popup: Control
var notifica: PanelContainer
var bottoni_vel: Array = []
var opz_filtrate_reg := ""

# online
var on_nome: LineEdit
var on_codice: LineEdit
var on_stato: Label
var lobby_box: VBoxContainer
var on_pot: OptionButton

func _ready() -> void:
	F_TESTO = FontVariation.new()
	F_TESTO.base_font = F_BASE
	F_TESTO.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 480}
	F_GRASSETTO = FontVariation.new()
	F_GRASSETTO.base_font = F_BASE
	F_GRASSETTO.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
	ui = CanvasLayer.new()
	add_child(ui)
	schermo = Control.new()
	schermo.set_anchors_preset(Control.PRESET_FULL_RECT)
	schermo.theme = _tema()
	ui.add_child(schermo)
	net = Rete.new()
	add_child(net)
	scelta_nome = str(net.load_session().get("name", ""))
	mostra_menu()

# ============================================================ stile

func _tema() -> Theme:
	var t := Theme.new()
	t.default_font = F_TESTO
	t.default_font_size = 21
	var bn := stile(C_CARTA, C_INCHIOSTRO, 2, 5)
	var bh := stile(Color(1.0, 0.95, 0.82), C_CERALACCA, 2, 5)
	var bp := stile(C_CARTA_SCURA, C_CERALACCA, 3, 5)
	var bd := stile(Color(0.7, 0.65, 0.55, 0.6), Color(0.4, 0.35, 0.3), 1, 5)
	for k in [["normal", bn], ["hover", bh], ["pressed", bp], ["disabled", bd], ["focus", stile(Color(0, 0, 0, 0), C_CERALACCA, 2, 5)]]:
		t.set_stylebox(k[0], "Button", k[1])
	t.set_color("font_color", "Button", C_INCHIOSTRO)
	t.set_color("font_hover_color", "Button", C_CERALACCA)
	t.set_color("font_pressed_color", "Button", C_INCHIOSTRO)
	t.set_color("font_disabled_color", "Button", Color(0.35, 0.3, 0.25))
	t.set_color("font_color", "Label", C_INCHIOSTRO)
	t.set_stylebox("normal", "LineEdit", stile(Color(1, 0.97, 0.88), C_INCHIOSTRO, 2, 4))
	t.set_color("font_color", "LineEdit", C_INCHIOSTRO)
	t.set_stylebox("panel", "PanelContainer", stile(C_CARTA, C_INCHIOSTRO, 2, 6))
	t.set_color("default_color", "RichTextLabel", C_INCHIOSTRO)
	t.set_stylebox("normal", "OptionButton", bn)
	t.set_stylebox("hover", "OptionButton", bh)
	t.set_color("font_color", "OptionButton", C_INCHIOSTRO)
	t.set_stylebox("panel", "PopupMenu", stile(C_CARTA, C_INCHIOSTRO, 2, 4))
	t.set_color("font_color", "PopupMenu", C_INCHIOSTRO)
	t.set_color("font_hover_color", "PopupMenu", C_CERALACCA)
	t.set_stylebox("hover", "PopupMenu", stile(Color(1.0, 0.95, 0.82), Color(0, 0, 0, 0), 0, 3))
	return t

func stile(bg: Color, bordo := Color(0, 0, 0, 0), spessore := 0, raggio := 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = bordo
	s.set_border_width_all(spessore)
	s.set_corner_radius_all(raggio)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

func riga_lbl(testo: String, font: Font = null, size := 21, col := C_INCHIOSTRO) -> Label:
	var l := etichetta(testo, font, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l

func etichetta(testo: String, font: Font = null, size := 21, col := C_INCHIOSTRO) -> Label:
	var l := Label.new()
	l.text = testo
	l.add_theme_font_override("font", font if font != null else F_TESTO)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func bottone(testo: String, cb: Callable, size := 21, larg := 0.0, a_capo := false) -> Button:
	var b := Button.new()
	b.text = testo
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(cb)
	if a_capo:
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if larg > 0:
		b.custom_minimum_size.x = larg
	return b

func pannello(bg := C_CARTA, bordo := C_INCHIOSTRO) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", stile(bg, bordo, 2, 8))
	return p

func immagine(path: String, w: float, h: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(w, h)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

func pulisci() -> void:
	for c in schermo.get_children():
		c.queue_free()
	in_partita = false
	plancia = null
	popup = null
	popup_aperto = false

func _sfondo() -> void:
	var bg := ColorRect.new()
	bg.color = C_LEGNO
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	schermo.add_child(bg)
	var img := TextureRect.new()
	img.texture = load("res://assets/mappa/plancia.jpg")
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img.modulate = Color(0.45, 0.38, 0.3)
	schermo.add_child(img)

func _scheda_centrale(w: float, h: float) -> VBoxContainer:
	var box := pannello()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(w, h)
	box.position = Vector2(-w / 2.0, -h / 2.0)
	box.add_theme_stylebox_override("panel", stile(C_CARTA, C_INCHIOSTRO, 3, 10))
	schermo.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	box.add_child(v)
	return v

# ============================================================ menu

func mostra_menu() -> void:
	pulisci()
	_sfondo()
	var v := _scheda_centrale(760, 600)
	var tit := etichetta("Struggle of Empires", F_TITOLO, 66, C_CERALACCA)
	tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tit)
	var sot := etichetta("La lotta degli imperi nel secolo coloniale", F_CORSIVO, 28, C_INCHIOSTRO)
	sot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sot)
	var stemmi := HBoxContainer.new()
	stemmi.alignment = BoxContainer.ALIGNMENT_CENTER
	stemmi.add_theme_constant_override("separation", 8)
	for p in Dati.POTENZE:
		stemmi.add_child(immagine("res://assets/stemmi/%s.png" % Dati.STEMMA[p], 64, 80))
	v.add_child(stemmi)
	var aut := etichetta("un gioco di Martin Wallace - edizione Deluxe", F_SOTTO, 20, C_SPENTO)
	aut.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(aut)
	v.add_child(HSeparator.new())
	v.add_child(bottone("Nuova partita contro l'IA", _menu_nuova, 26))
	if FileAccess.file_exists(SALVA_LOCALE):
		v.add_child(bottone("Continua la partita salvata", _menu_continua, 26))
	v.add_child(bottone("Gioca online con gli amici", _menu_online, 26))
	v.add_child(bottone("Riprendi la partita salvata su Firebase", _continua_firebase, 22))
	v.add_child(bottone("Le regole in breve", _menu_regole, 22))
	var nota := etichetta("Versione digitale per uso personale.", F_CORSIVO, 17, C_SPENTO)
	nota.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nota)

func _menu_nuova() -> void:
	pulisci()
	_sfondo()
	var v := _scheda_centrale(980, 760)
	v.add_child(etichetta("Nuova partita", F_TITOLO, 48, C_CERALACCA))
	v.add_child(etichetta("Quante potenze guidate da giocatori? Le altre restano neutrali sulla mappa (con le loro armate) e si schierano nelle Grandi Alleanze.", F_TESTO, 20))
	var rn := HBoxContainer.new()
	rn.add_theme_constant_override("separation", 8)
	v.add_child(rn)
	var bn: Array = []
	for n in range(2, 8):
		var b := bottone("%d giocatori" % n, func(): pass, 20)
		b.toggle_mode = true
		b.button_pressed = n == scelta_np
		bn.append(b)
		rn.add_child(b)
	for k in bn.size():
		var b: Button = bn[k]
		b.pressed.connect(func():
			scelta_np = k + 2
			for x in bn.size():
				bn[x].button_pressed = x == k)
	v.add_child(etichetta("La tua potenza:", F_GRASSETTO, 22))
	var rp := HBoxContainer.new()
	rp.add_theme_constant_override("separation", 6)
	v.add_child(rp)
	var bp: Array = []
	for p in Dati.POTENZE:
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = p == scelta_pot
		b.custom_minimum_size = Vector2(126, 150)
		var vb := VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_child(immagine("res://assets/stemmi/%s.png" % Dati.STEMMA[p], 110, 100))
		var l := etichetta(Dati.NOME_POT[p], F_SOTTO, 17)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(l)
		b.add_child(vb)
		bp.append(b)
		rp.add_child(b)
	for k in bp.size():
		bp[k].pressed.connect(func():
			scelta_pot = Dati.POTENZE[k]
			for x in bp.size():
				bp[x].button_pressed = x == k)
	var rnome := HBoxContainer.new()
	v.add_child(rnome)
	rnome.add_child(riga_lbl("Il tuo nome:", F_GRASSETTO, 21))
	var le := LineEdit.new()
	le.text = scelta_nome
	le.placeholder_text = "facoltativo"
	le.max_length = 20
	le.custom_minimum_size.x = 300
	le.text_changed.connect(func(t): scelta_nome = t)
	rnome.add_child(le)
	v.add_child(etichetta("Si gioca con le regole Deluxe: Tensione visibile, Viaggio in mare aperto con il dado (4 riuscito, 1 fermo, 1 affonda). Le IA trattano, offrono Oro, fanno promesse e qualche volta le rompono.", F_CORSIVO, 18, C_SPENTO))
	var rb := HBoxContainer.new()
	rb.add_theme_constant_override("separation", 12)
	v.add_child(rb)
	rb.add_child(bottone("Inizia la partita", _avvia_locale, 26, 360))
	rb.add_child(bottone("Indietro", mostra_menu, 22, 200))

func _ordine_potenze(mia: String, n: int, seed: int) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var altre: Array = Dati.POTENZE.duplicate()
	altre.erase(mia)
	for k in range(altre.size() - 1, 0, -1):
		var j := r.randi_range(0, k)
		var t = altre[k]
		altre[k] = altre[j]
		altre[j] = t
	var out: Array = [mia]
	out.append_array(altre.slice(0, n - 1))
	return out

func _avvia_locale() -> void:
	var seed := int(Time.get_unix_time_from_system()) % 1000000 + randi() % 1000
	var pots := _ordine_potenze(scelta_pot, scelta_np, seed)
	var seats: Array = [0]
	var nomi: Array = [scelta_nome.strip_edges()]
	for k in range(1, pots.size()):
		seats.append(-1)
		nomi.append("")
	if scelta_nome.strip_edges() != "":
		net._save({"name": scelta_nome.strip_edges()})
	m = Motore.new()
	m.nuova({"pot": pots, "seat": seats, "seed": seed, "nomi": nomi})
	ia = IA.new(m)
	online = false
	mio_posto = 0
	_apri_partita()

func _menu_continua() -> void:
	var f := FileAccess.open(SALVA_LOCALE, FileAccess.READ)
	if f == null:
		return
	var st = JSON.parse_string(f.get_as_text())
	f.close()
	if not (st is Dictionary) or not st.has("giocatori"):
		_avviso("Il salvataggio non è leggibile.")
		return
	_carica_stato(st)

func _continua_firebase() -> void:
	_avviso("Cerco la partita salvata su Firebase...")
	var st := await net.carica_partita()
	if st.is_empty() or not st.has("giocatori"):
		_avviso("Nessuna partita salvata su Firebase per questo dispositivo. " + net.last_error)
		return
	_carica_stato(st)

func _carica_stato(st: Dictionary) -> void:
	m = Motore.new()
	m.ripristina(_normalizza(st))
	ia = IA.new(m)
	online = false
	mio_posto = 0
	_apri_partita()

## il JSON trasforma gli interi in decimali: si rimettono a posto quelli che servono interi
func _normalizza(v):
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = _normalizza(v[k])
		return out
	if v is Array:
		var a: Array = []
		for x in v:
			a.append(_normalizza(x))
		return a
	if v is float and v == floor(v) and absf(v) < 1e12:
		return int(v)
	return v

func _avviso(t: String) -> void:
	var p := pannello(Color(1.0, 0.96, 0.85), C_CERALACCA)
	p.set_anchors_preset(Control.PRESET_CENTER_TOP)
	p.position = Vector2(-380, 24)
	p.custom_minimum_size = Vector2(760, 0)
	var l := etichetta(t, F_TESTO, 21)
	p.add_child(l)
	schermo.add_child(p)
	await get_tree().create_timer(4.0).timeout
	if is_instance_valid(p):
		p.queue_free()

func _menu_regole() -> void:
	pulisci()
	_sfondo()
	var box := pannello()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 120
	box.offset_right = -120
	box.offset_top = 40
	box.offset_bottom = -40
	schermo.add_child(box)
	var v := VBoxContainer.new()
	box.add_child(v)
	v.add_child(etichetta("Le regole in breve", F_TITOLO, 44, C_CERALACCA))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	var vv := VBoxContainer.new()
	vv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vv.add_theme_constant_override("separation", 10)
	sc.add_child(vv)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.add_theme_font_override("normal_font", F_TESTO)
	rt.add_theme_font_override("bold_font", F_GRASSETTO)
	rt.add_theme_font_override("italics_font", F_CORSIVO)
	rt.add_theme_font_size_override("normal_font_size", 21)
	rt.add_theme_font_size_override("bold_font_size", 21)
	rt.text = REGOLE
	vv.add_child(rt)
	vv.add_child(etichetta("La plancia di riferimento (Inghilterra):", F_GRASSETTO, 21))
	vv.add_child(immagine("res://assets/ui/riepilogo.jpg", 1500, 620))
	v.add_child(bottone("Indietro", mostra_menu if not in_partita else _chiudi_popup, 22))

const REGOLE := """[b]Scopo.[/b] Tre guerre; alla fine di ognuna le 11 regioni con punti vittoria (5 in Europa, 6 coloniali) danno punti a chi ha più segnalini Controllo (primo, secondo, terzo posto: valori scritti sulla mappa; i pari ricevono il valore pieno). Contano solo i segnalini Controllo, non gli eserciti.

[b]Grandi Alleanze.[/b] All'inizio di ogni guerra si fanno aste: chi ha il martelletto propone due potenze non ancora schierate, una nell'Alleanza Rossa e una nella Blu, con un'offerta in Oro. Gli altri passano o rilanciano cambiando proposta. Chi vince paga e le due potenze entrano nelle alleanze; l'ordine di entrata è l'ordine di gioco della guerra. Si possono attaccare solo i segnalini della Grande Alleanza avversaria. Conviene essere alleati di chi ti minaccia e nemici di chi vuoi attaccare.

[b]Turno.[/b] 2 azioni regolari, oppure 1 regolare e 1 speciale, più le azioni gratuite.
- Costruire 1 unità in patria (1 Popolazione) e poi muoverla.
- Muovere 2 unità (3 con la Logistica). Le flotte vanno nelle regioni con la nave; gli eserciti in Europa liberamente, nelle colonie solo dove hai una flotta. Fra Europa, Americhe, Africa, India e Indie Orientali si tira il dado del Viaggio in mare aperto: fermo (paghi 1 Oro per partire) o affonda (paghi 2 per restare, 3 per arrivare).
- Attaccare (2 Oro): prima eventuale battaglia navale per il Supporto navale (+1), poi quella terrestre. Forza: +1 per Esercito, +2 per Forte in difesa, +1 Alleanza Locale, +1 Addestramento se ne hai più dell'avversario. Ognuno tira 2 dadi e aggiunge la differenza. Chi perde (o pareggia) perde un'unità; chi tira 7 perde un'unità in più. Ogni unità persa dà 1 Tensione.
- Colonizzare (1 Popolazione) o Commercio della Costa d'Oro (serve una flotta in Africa): una sola delle due per turno.
- Passare: se passi e non attacchi, togli 1 Tensione.
- Speciali: stipulare un'Alleanza Locale, reclamare una tessera, usare un'azione segreta (Pirati nelle colonie, Rivolta nelle Americhe).

[b]Trattative.[/b] Prima della chiamata agli alleati attaccante e difensore possono offrire Oro agli alleati presenti; le promesse non sono vincolanti. Durante il turno puoi trattare con gli altri: chiedere Oro per non attaccare, oppure pagare per non essere attaccato. Chi rompe la parola perde fiducia e le IA se ne ricordano.

[b]Oro e Tensione.[/b] Se non hai Oro per una spesa usi la Tassazione: 2 Oro (3 con la Banca) e 1 Tensione. Alla fine di ogni guerra: Oro pari a Popolazione più segnalini Controllo, meno 1 per ogni unità; poi +5 Popolazione (massimo 9).

[b]Fine.[/b] Dopo la terza guerra chi ha 20 o più Tensione va in rivoluzione (0 punti); chi ha la Tensione più alta perde 7 punti, il secondo 4. Vince chi ha più Punti Vittoria (a pari merito, meno Tensione).

[i]Nella mappa: clicca una regione per vederne i dettagli; con la rotella o il pizzico ingrandisci, trascinando sposti.[/i]"""

# ============================================================ online

func _menu_online() -> void:
	pulisci()
	_sfondo()
	var v := _scheda_centrale(820, 700)
	v.add_child(etichetta("Gioca online", F_TITOLO, 48, C_CERALACCA))
	v.add_child(etichetta("Chi crea la stanza sceglie quante potenze sono in gioco; gli amici entrano con il codice di 4 lettere. Ognuno sceglie la sua potenza, i posti vuoti li guida l'IA.", F_TESTO, 20))
	var r1 := HBoxContainer.new()
	v.add_child(r1)
	r1.add_child(riga_lbl("Il tuo nome:", F_GRASSETTO, 21))
	on_nome = LineEdit.new()
	on_nome.custom_minimum_size = Vector2(300, 0)
	on_nome.text = str(net.load_session().get("name", "Sovrano"))
	on_nome.max_length = 20
	r1.add_child(on_nome)
	var r0 := HBoxContainer.new()
	v.add_child(r0)
	r0.add_child(riga_lbl("La tua potenza:", F_GRASSETTO, 21))
	on_pot = OptionButton.new()
	for p in Dati.POTENZE:
		on_pot.add_item(Dati.NOME_POT[p])
	on_pot.selected = Dati.POTENZE.find(scelta_pot)
	r0.add_child(on_pot)
	v.add_child(etichetta("La stanza si crea con %d potenze in gioco (le cambi in Nuova partita)." % scelta_np, F_CORSIVO, 19, C_SPENTO))
	v.add_child(bottone("Crea una stanza", _online_crea, 24))
	var r2 := HBoxContainer.new()
	v.add_child(r2)
	on_codice = LineEdit.new()
	on_codice.placeholder_text = "CODICE"
	on_codice.max_length = 4
	on_codice.custom_minimum_size = Vector2(150, 0)
	r2.add_child(on_codice)
	r2.add_child(bottone("Entra", _online_entra, 24))
	var sess := net.load_session()
	if str(sess.get("room", "")) != "":
		r2.add_child(bottone("Rientra in %s" % sess["room"], func():
			on_codice.text = str(sess["room"])
			_online_entra(), 20))
	on_stato = etichetta("", F_TESTO, 20, C_CERALACCA)
	v.add_child(on_stato)
	lobby_box = VBoxContainer.new()
	v.add_child(lobby_box)
	v.add_child(bottone("Indietro", mostra_menu, 20))

func _pot_scelta() -> String:
	return Dati.POTENZE[clampi(on_pot.selected, 0, 6)] if on_pot != null else scelta_pot

func _online_crea() -> void:
	on_stato.text = "Creo la stanza..."
	net._save({"name": on_nome.text})
	var c := await net.create_room(on_nome.text, {"np": scelta_np})
	if c == "":
		on_stato.text = "Non riesco a creare la stanza: " + net.last_error
		return
	codice = c
	mio_posto = 0
	await net.db_patch(Rete.ROOT + "/%s/seats/0" % c, {"pot": _pot_scelta()})
	net.remember_room(c, 0)
	on_stato.text = "Stanza %s creata. Dai il codice agli amici, poi premi Inizia." % c
	_lobby(true)

func _online_entra() -> void:
	var c := on_codice.text.strip_edges().to_upper()
	if c.length() != 4:
		on_stato.text = "Il codice ha 4 lettere."
		return
	on_stato.text = "Entro nella stanza %s..." % c
	net._save({"name": on_nome.text})
	var p := await net.join_room(c, on_nome.text, 7)
	if p < 0:
		on_stato.text = "Non riesco a entrare (stanza piena, inesistente o già iniziata). " + net.last_error
		return
	codice = c
	mio_posto = p
	net.remember_room(c, p)
	var room := await net.room(c)
	if room.get("status", "") == "playing":
		_avvia_da_stanza(room)
		return
	await net.db_patch(Rete.ROOT + "/%s/seats/%d" % [c, p], {"pot": _pot_scelta()})
	on_stato.text = "Sei nella stanza %s, posto %d. Aspetta che chi l'ha creata inizi." % [c, p + 1]
	_lobby(false)

func _lobby(host: bool) -> void:
	for ch in lobby_box.get_children():
		ch.queue_free()
	var lista := etichetta("", F_TESTO, 20)
	lobby_box.add_child(lista)
	if host:
		lobby_box.add_child(bottone("Inizia la partita", _online_inizia, 24))
	while is_instance_valid(lista) and not in_partita:
		var room := await net.room(codice)
		if not is_instance_valid(lista):
			return
		var seats := Rete._as_dict(room.get("seats", {}))
		var t := "Nella stanza:\n"
		for k in seats:
			var pp := str(seats[k].get("pot", ""))
			t += "  %d. %s%s\n" % [int(k) + 1, seats[k].get("name", "?"), (" - " + Dati.NOME_POT[pp]) if Dati.NOME_POT.has(pp) else ""]
		lista.text = t
		if not host and room.get("status", "") == "playing":
			_avvia_da_stanza(room)
			return
		await get_tree().create_timer(1.5).timeout

func _online_inizia() -> void:
	var room := await net.room(codice)
	var seats := Rete._as_dict(room.get("seats", {}))
	var cfg = JSON.parse_string(str(room.get("cfg", "{}")))
	var n: int = clampi(maxi(int(cfg.get("np", 4)) if cfg is Dictionary else 4, seats.size()), 2, 7)
	var seed := int(Time.get_unix_time_from_system()) % 1000000
	var posti := seats.keys()
	posti.sort_custom(func(a, b): return int(a) < int(b))
	var pots: Array = []
	var seat_arr: Array = []
	var nomi: Array = []
	# ognuno la potenza che ha chiesto (se due scelgono la stessa, il secondo ne prende una libera)
	for k in posti:
		var pp := str(seats[k].get("pot", ""))
		if not Dati.NOME_POT.has(pp) or pp in pots:
			pp = ""
			for q in Dati.POTENZE:
				if not (q in pots):
					var chiesta := false
					for k2 in posti:
						if str(seats[k2].get("pot", "")) == q:
							chiesta = true
					if not chiesta:
						pp = q
						break
		pots.append(pp)
		seat_arr.append(int(k))
		nomi.append(str(seats[k].get("name", "?")))
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var libere: Array = []
	for q in Dati.POTENZE:
		if not (q in pots):
			libere.append(q)
	while pots.size() < n and not libere.is_empty():
		var q: String = libere.pop_at(r.randi_range(0, libere.size() - 1))
		pots.append(q)
		seat_arr.append(-1)
		nomi.append("")
	var game := {"pot": pots, "seat": seat_arr, "seed": seed, "nomi": nomi}
	if not await net.start_room(codice, game):
		on_stato.text = "Non riesco a iniziare: " + net.last_error
		return
	room["game"] = JSON.stringify(game)
	_avvia_da_stanza(room)

func _avvia_da_stanza(room: Dictionary) -> void:
	var game = JSON.parse_string(str(room.get("game", "{}")))
	if not (game is Dictionary):
		on_stato.text = "Dati della partita illeggibili."
		return
	online = true
	var cfg := {"pot": game["pot"], "seat": [], "seed": int(game["seed"]), "nomi": game.get("nomi", [])}
	for x in game["seat"]:
		cfg["seat"].append(int(x))
	m = Motore.new()
	m.nuova(cfg)
	ia = IA.new(m)
	# si rigiocano le decisioni già prese (chi rientra ritrova la partita al punto giusto)
	var log := await net.get_decisions(codice, 0)
	var guard := 0
	while not m.finita() and guard < 40000:
		guard += 1
		var r := m.richiesta()
		if r.is_empty():
			break
		var seat: int = m.g(r["g"])["seat"]
		var id := ""
		if seat < 0:
			id = ia.decidi(r)
		elif log.has(int(m.s["passo"])):
			id = str(log[int(m.s["passo"])].get("id", ""))
		else:
			break
		m.applica({"id": id})
	_apri_partita()

# ============================================================ la partita

func io(i: int) -> bool:
	return i >= 0 and int(m.g(i)["seat"]) == mio_posto

func mio() -> int:
	for i in m.np():
		if io(i):
			return i
	return -1

func _apri_partita() -> void:
	pulisci()
	in_partita = true
	richiesta_mostrata = -1
	ultimo_cb_visto = int(m.s.get("ultimo_cb", {}).get("passo", -1))
	ultimo_evento_visto = int(m.s["passo"])
	var bg := ColorRect.new()
	bg.color = C_LEGNO
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	schermo.add_child(bg)
	plancia = Plancia.new()
	plancia.m = m
	plancia.set_anchors_preset(Control.PRESET_FULL_RECT)
	plancia.offset_top = 58
	plancia.offset_right = -600
	schermo.add_child(plancia)
	plancia.regione_cliccata.connect(_regione_cliccata)
	plancia.regione_sopra.connect(_regione_sopra)
	_costruisci_hud()
	_aggiorna_tutto()

func _costruisci_hud() -> void:
	# barra in alto
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", stile(C_LEGNO2, C_ORO, 0, 0))
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.custom_minimum_size.y = 58
	schermo.add_child(top)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	top.add_child(hb)
	var tit := etichetta("Struggle of Empires", F_TITOLO, 32, C_ORO)
	tit.autowrap_mode = TextServer.AUTOWRAP_OFF
	hb.add_child(tit)
	top_info = etichetta("", F_SOTTO, 25, C_CARTA)
	top_info.autowrap_mode = TextServer.AUTOWRAP_OFF
	hb.add_child(top_info)
	top_turno = etichetta("", F_CORSIVO, 23, C_ORO)
	top_turno.autowrap_mode = TextServer.AUTOWRAP_OFF
	top_turno.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(top_turno)
	if not online:
		hb.add_child(riga_lbl("IA:", F_SOTTO, 20, C_CARTA))
		bottoni_vel = []
		for x in [["Lenta", 0.5], ["Normale", 1.0], ["Veloce", 3.0]]:
			var b := bottone(x[0], func(): pass, 17)
			b.toggle_mode = true
			b.button_pressed = absf(velocita - float(x[1])) < 0.01
			var vv: float = x[1]
			b.pressed.connect(func():
				velocita = vv
				for bb in bottoni_vel:
					bb.button_pressed = bb == b)
			bottoni_vel.append(b)
			hb.add_child(b)
	hb.add_child(bottone("Tessere", _mostra_banco, 18))
	hb.add_child(bottone("Regole", _regole_popup, 18))
	hb.add_child(bottone("Menu", _menu_partita, 18))
	# colonna di destra
	var dx := PanelContainer.new()
	dx.add_theme_stylebox_override("panel", stile(C_LEGNO, C_ORO, 0, 0))
	dx.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	dx.offset_left = -600
	dx.offset_top = 58
	schermo.add_child(dx)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	dx.add_child(col)
	colonna_giocatori = VBoxContainer.new()
	colonna_giocatori.add_theme_constant_override("separation", 3)
	col.add_child(colonna_giocatori)
	var pd := pannello(C_CARTA, C_CERALACCA)
	pd.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(pd)
	var vd := VBoxContainer.new()
	vd.add_theme_constant_override("separation", 6)
	pd.add_child(vd)
	titolo_dec = etichetta("", F_TITOLO, 26, C_CERALACCA)
	vd.add_child(titolo_dec)
	testo_dec = etichetta("", F_TESTO, 20)
	vd.add_child(testo_dec)
	scroll_dec = ScrollContainer.new()
	scroll_dec.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_dec.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vd.add_child(scroll_dec)
	pannello_dec = VBoxContainer.new()
	pannello_dec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pannello_dec.add_theme_constant_override("separation", 5)
	scroll_dec.add_child(pannello_dec)
	var pdia := pannello(C_CARTA_SCURA, C_INCHIOSTRO)
	pdia.custom_minimum_size.y = 210
	col.add_child(pdia)
	diario = RichTextLabel.new()
	diario.bbcode_enabled = true
	diario.scroll_following = true
	diario.add_theme_font_override("normal_font", F_TESTO)
	diario.add_theme_font_override("bold_font", F_GRASSETTO)
	diario.add_theme_font_size_override("normal_font_size", 17)
	diario.add_theme_font_size_override("bold_font_size", 17)
	pdia.add_child(diario)
	# riquadro con i dettagli della regione sotto il mouse
	info_regione = pannello(Color(0.98, 0.94, 0.84, 0.97), C_INCHIOSTRO)
	info_regione.visible = false
	info_regione.custom_minimum_size = Vector2(380, 0)
	info_regione.mouse_filter = Control.MOUSE_FILTER_IGNORE
	schermo.add_child(info_regione)
	info_regione_lbl = RichTextLabel.new()
	info_regione_lbl.bbcode_enabled = true
	info_regione_lbl.fit_content = true
	info_regione_lbl.custom_minimum_size.x = 360
	info_regione_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_regione_lbl.add_theme_font_override("normal_font", F_TESTO)
	info_regione_lbl.add_theme_font_override("bold_font", F_GRASSETTO)
	info_regione_lbl.add_theme_font_size_override("normal_font_size", 18)
	info_regione_lbl.add_theme_font_size_override("bold_font_size", 19)
	info_regione.add_child(info_regione_lbl)

func _menu_partita() -> void:
	var v := _apri_popup("Menu", 640)
	if not online:
		v.add_child(bottone("Salva e torna al menu principale", func():
			_salva(true)
			mostra_menu(), 22))
		v.add_child(bottone("Nuova partita (abbandona questa)", func():
			_menu_nuova(), 20))
	else:
		v.add_child(etichetta("Stanza online %s. Puoi uscire e rientrare quando vuoi con il codice." % codice, F_TESTO, 20))
		v.add_child(bottone("Esci dalla stanza (la partita continua)", mostra_menu, 22))
	v.add_child(bottone("Torna alla partita", _chiudi_popup, 22))

# ---------- popup

func _apri_popup(titolo: String, larg := 900, alto := 0) -> VBoxContainer:
	_chiudi_popup()
	popup_aperto = true
	var velo := ColorRect.new()
	velo.color = Color(0, 0, 0, 0.45)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	schermo.add_child(velo)
	popup = velo
	var p := pannello(C_CARTA, C_CERALACCA)
	p.add_theme_stylebox_override("panel", stile(C_CARTA, C_CERALACCA, 3, 10))
	p.custom_minimum_size = Vector2(larg, alto)
	p.set_anchors_preset(Control.PRESET_CENTER)
	velo.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(etichetta(titolo, F_TITOLO, 34, C_CERALACCA))
	p.resized.connect(func(): p.position = (velo.size - p.size) / 2.0)
	velo.resized.connect(func(): p.position = (velo.size - p.size) / 2.0)
	_adatta_popup.call_deferred(p, velo)
	return v

## le etichette a capo all'inizio misurano altezze enormi: dopo un paio di frame si riporta il riquadro alla misura giusta
func _adatta_popup(p: Control, velo: Control) -> void:
	for k in 3:
		await get_tree().process_frame
		if not is_instance_valid(p):
			return
		p.reset_size()
		p.size.y = minf(p.size.y, velo.size.y - 20)
		p.position = (velo.size - p.size) / 2.0

func _chiudi_popup() -> void:
	if is_instance_valid(popup):
		popup.queue_free()
	popup = null
	popup_aperto = false

func _regole_popup() -> void:
	var v := _apri_popup("Le regole in breve", 1300, 900)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(1260, 760)
	v.add_child(sc)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.add_theme_font_override("normal_font", F_TESTO)
	rt.add_theme_font_override("bold_font", F_GRASSETTO)
	rt.add_theme_font_override("italics_font", F_CORSIVO)
	rt.add_theme_font_size_override("normal_font_size", 20)
	rt.add_theme_font_size_override("bold_font_size", 20)
	rt.text = REGOLE
	sc.add_child(rt)
	v.add_child(bottone("Chiudi", _chiudi_popup, 22))

func _carta_tessera(t: String, w := 150.0, testo_extra := "") -> VBoxContainer:
	var d: Dictionary = Dati.TESSERE[t]
	var v := VBoxContainer.new()
	v.custom_minimum_size.x = w
	v.add_child(immagine("res://assets/tessere/%s.jpg" % d["img"], w, w * 0.72))
	var l := etichetta(d["nome"], F_GRASSETTO, 17)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = w
	v.add_child(l)
	if testo_extra != "":
		var l2 := etichetta(testo_extra, F_TESTO, 15, C_SPENTO)
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l2.custom_minimum_size.x = w
		v.add_child(l2)
	v.tooltip_text = d["testo"]
	return v

func _mostra_banco() -> void:
	var v := _apri_popup("Le tessere sul tabellone", 1500, 0)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(1460, 720)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var g := GridContainer.new()
	g.columns = 8
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 8)
	sc.add_child(g)
	for t in Dati.ORDINE_TESSERE:
		var n := int(m.s["banco"].get(t, 0))
		var c := _carta_tessera(t, 160, "%s - ne restano %d" % [m.costo_testo(t), n])
		if n <= 0:
			c.modulate = Color(1, 1, 1, 0.35)
		g.add_child(c)
	v.add_child(etichetta("Passa il mouse su una tessera per leggerne l'effetto.", F_CORSIVO, 18, C_SPENTO))
	v.add_child(bottone("Chiudi", _chiudi_popup, 22))

func _mostra_giocatore(i: int) -> void:
	var gg := m.g(i)
	var p: String = gg["pot"]
	var v := _apri_popup("%s - %s" % [m.nome(i), Dati.NOME_POT[p]], 1100)
	var h := HBoxContainer.new()
	v.add_child(h)
	h.add_child(immagine("res://assets/stemmi/%s.png" % Dati.STEMMA[p], 100, 120))
	var inf := etichetta("Oro %d, Popolazione %d, Tensione %d, Punti Vittoria %d.\nSegnalini Controllo sulla mappa: %d. Unità: %d Eserciti, %d Flotte, %d Forti.\nAlleanze Locali: %d. Fiducia degli altri: %d su 100." % [
		int(gg["oro"]), int(gg["pop"]), int(gg["tens"]), int(gg["pv"]), m.tot_c(p), m.tot_u(p, 0), m.tot_u(p, 1), m.tot_u(p, 2),
		m.locali_di(p), int(float(m.s["rep"][i]) * 100)], F_TESTO, 20)
	inf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(inf)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(1060, 480)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var g := GridContainer.new()
	g.columns = 6
	sc.add_child(g)
	if gg["tessere"].is_empty():
		v.add_child(etichetta("Nessuna tessera.", F_CORSIVO, 19, C_SPENTO))
	for x in gg["tessere"]:
		var c := _carta_tessera(x["t"], 160, "usata in questa guerra" if x["usata"] else "")
		if x["usata"]:
			c.modulate = Color(1, 1, 1, 0.55)
		g.add_child(c)
	v.add_child(bottone("Chiudi", _chiudi_popup, 22))

# ---------- aggiornamento

func _aggiorna_tutto() -> void:
	if m == null or not in_partita:
		return
	var gu := int(m.s["guerra"])
	var st: String = m.s["stadio"]
	var fase := ""
	match st:
		"piazzamento": fase = "Piazzamento iniziale"
		"asta": fase = "Grandi Alleanze"
		"turno", "combattimento", "fine_turno": fase = "Round %d di %d" % [int(m.s["round"]), Dati.round_per_guerra(m.np())]
		"fine": fase = "Partita finita"
		_: fase = ""
	top_info.text = "%s Guerra  -  %s" % [["Prima", "Seconda", "Terza"][clampi(gu, 1, 3) - 1], fase]
	var r := m.richiesta()
	if r.is_empty():
		top_turno.text = ""
	else:
		top_turno.text = "Decide: %s" % m.nome(int(r["g"]))
	_aggiorna_giocatori()
	_aggiorna_diario()
	plancia.evidenzia = []
	plancia.queue_redraw()
	if r.is_empty() or not io(int(r["g"])):
		_mostra_attesa(r)
	_controlla_eventi()

func _aggiorna_giocatori() -> void:
	for c in colonna_giocatori.get_children():
		c.queue_free()
	var r := m.richiesta()
	var ordine: Array = m.s["ordine"] if not m.s["ordine"].is_empty() else range(m.np())
	var proj := m.punti_proiezione()
	for i in ordine:
		var gg := m.g(i)
		var p: String = gg["pot"]
		var all_ := m.alleanza(p)
		var attivo: bool = not r.is_empty() and int(r["g"]) == i
		var bg := Color(1.0, 0.95, 0.8) if attivo else C_CARTA
		var bordo := C_CERALACCA if attivo else (C_ROSSA if all_ == "R" else (C_BLU if all_ == "B" else C_INCHIOSTRO))
		var riga := Button.new()
		riga.add_theme_stylebox_override("normal", stile(bg, bordo, 3 if attivo or all_ != "" else 1, 6))
		riga.add_theme_stylebox_override("hover", stile(Color(1, 0.97, 0.88), C_CERALACCA, 3, 6))
		riga.add_theme_stylebox_override("pressed", stile(bg, bordo, 3, 6))
		riga.custom_minimum_size.y = 62
		var ii: int = i
		riga.pressed.connect(func(): _mostra_giocatore(ii))
		colonna_giocatori.add_child(riga)
		var h := HBoxContainer.new()
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 6
		h.offset_right = -6
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_theme_constant_override("separation", 8)
		riga.add_child(h)
		h.add_child(immagine("res://assets/stemmi/%s.png" % Dati.STEMMA[p], 44, 56))
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", -4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		var nome_l := etichetta("%s%s" % [m.nome(i), "" if m.nome(i) == Dati.NOME_POT[p] else " (" + Dati.NOME_POT[p] + ")"], F_GRASSETTO, 19)
		nome_l.autowrap_mode = TextServer.AUTOWRAP_OFF
		nome_l.clip_text = true
		nome_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(nome_l)
		var extra := ""
		if all_ != "":
			extra = "Alleanza %s  " % ("Rossa" if all_ == "R" else "Blu")
		if io(i):
			extra += "(tu)"
		elif int(gg["seat"]) < 0:
			extra += "(IA)"
		var l2 := etichetta(extra, F_CORSIVO, 16, C_ROSSA if all_ == "R" else (C_BLU if all_ == "B" else C_SPENTO))
		l2.autowrap_mode = TextServer.AUTOWRAP_OFF
		l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l2)
		var stat := etichetta("Oro %d   Pop %d   Tens %d   PV %d (+%d)   Tessere %d" % [int(gg["oro"]), int(gg["pop"]), int(gg["tens"]),
			int(gg["pv"]), int(proj.get(p, 0)), gg["tessere"].size()], F_TESTO, 17)
		stat.autowrap_mode = TextServer.AUTOWRAP_OFF
		stat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(stat)

func _aggiorna_diario() -> void:
	var righe: Array = m.s["log"].slice(maxi(0, m.s["log"].size() - 90))
	var t := ""
	for l in righe:
		var s := str(l).replace("[", "(").replace("]", ")")
		if s.begins_with("==="):
			t += "[b][color=#7a1a0e]%s[/color][/b]\n" % s
		elif s.begins_with("--"):
			t += "[b]%s[/b]\n" % s
		else:
			t += s + "\n"
	diario.text = t

func _controlla_eventi() -> void:
	# rapporto dell'ultimo combattimento
	var cb: Dictionary = m.s.get("ultimo_cb", {})
	if not cb.is_empty() and int(cb.get("passo", -1)) != ultimo_cb_visto:
		ultimo_cb_visto = int(cb["passo"])
		_mostra_combattimento(cb)
	# trattative e viaggi
	for e in m.s["eventi"]:
		if int(e["n"]) <= ultimo_evento_visto:
			continue
		match e["tipo"]:
			"trattativa":
				if io(int(e["da"])):
					_notifica("%s %s la tua proposta." % [m.nome(int(e["g"])), "accetta" if e["esito"] == "si" else "rifiuta"])
			"viaggio":
				if io(int(e["g"])) and e["esito"] == "ok":
					_notifica("Viaggio in mare aperto riuscito.")
			"punteggio":
				_mostra_punteggio(e)
	ultimo_evento_visto = int(m.s["passo"])

func _notifica(t: String) -> void:
	if is_instance_valid(notifica):
		notifica.queue_free()
	notifica = pannello(Color(1.0, 0.96, 0.85), C_CERALACCA)
	notifica.position = Vector2(380, 70)
	notifica.custom_minimum_size = Vector2(620, 0)
	notifica.add_child(etichetta(t, F_GRASSETTO, 21))
	schermo.add_child(notifica)
	var n := notifica
	await get_tree().create_timer(3.5).timeout
	if is_instance_valid(n):
		n.queue_free()

func _mostra_combattimento(cb: Dictionary) -> void:
	var v := _apri_popup("Combattimento", 900)
	v.add_child(etichetta(str(cb.get("titolo", "")), F_SOTTO, 25))
	for riga in cb.get("rapporto", []):
		var box := pannello(Color(0.97, 0.92, 0.8), C_INCHIOSTRO)
		v.add_child(box)
		var vv := VBoxContainer.new()
		box.add_child(vv)
		vv.add_child(etichetta("Battaglia navale" if riga["dom"] == "n" else "Battaglia terrestre", F_GRASSETTO, 22, C_CERALACCA))
		for lato in ["a", "d"]:
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 10)
			vv.add_child(h)
			var lbl := etichetta("%s: forza %d" % ["Attaccante" if lato == "a" else "Difensore", int(riga["f" + lato])], F_TESTO, 21)
			lbl.custom_minimum_size.x = 300
			h.add_child(lbl)
			var dadi: Array = riga[lato]
			h.add_child(Dado.new(int(dadi[0]), lato == "a", 38))
			h.add_child(Dado.new(int(dadi[1]), lato == "a", 38))
			var sette := int(dadi[0]) + int(dadi[1]) == 7
			h.add_child(riga_lbl("totale %d%s" % [int(riga["t" + lato]), "  (7: un'unità in più persa)" if sette else ""], F_GRASSETTO, 21))
		var esito := "Vince l'attaccante" if riga["vince"] == "a" else ("Vince il difensore" if riga["vince"] == "d" else "Pareggio")
		var perdite: Array = []
		for pz in riga.get("perdite", []):
			perdite.append("%s %s" % [m.nome_pot(pz[0]), Motore.NOMI_U[int(pz[1])].to_lower()])
		vv.add_child(etichetta(esito + (". Perdite: " + ", ".join(perdite) + "." if not perdite.is_empty() else ". Nessuna perdita."), F_TESTO, 20))
	v.add_child(etichetta(str(cb.get("esito", "")), F_GRASSETTO, 23, C_CERALACCA))
	v.add_child(bottone("Continua", _chiudi_popup, 22))
	# i combattimenti fra altre potenze si chiudono da soli dopo qualche secondo
	var dg := m.gioc_di(str(cb.get("dpot", "")))
	if not io(int(cb.get("att", -1))) and not io(dg):
		var mio_popup := popup
		await get_tree().create_timer(5.0 / maxf(velocita, 0.5)).timeout
		if is_instance_valid(mio_popup) and popup == mio_popup:
			_chiudi_popup()

func _mostra_punteggio(e: Dictionary) -> void:
	var gu := int(e["guerra"])
	var v := _apri_popup("Fine della %s guerra" % ["prima", "seconda", "terza"][clampi(gu, 1, 3) - 1], 820)
	v.add_child(etichetta("Punti vittoria assegnati per il controllo delle regioni:", F_TESTO, 21))
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 24)
	v.add_child(g)
	for i in m.np():
		var p := m.pot(i)
		g.add_child(immagine("res://assets/stemmi/%s.png" % Dati.STEMMA[p], 36, 44))
		g.add_child(riga_lbl(m.nome(i), F_GRASSETTO, 21))
		g.add_child(riga_lbl("+%d" % int(e["pv"].get(p, 0)), F_TESTO, 21))
		g.add_child(riga_lbl("totale %d" % int(m.g(i)["pv"]), F_TESTO, 21))
	v.add_child(bottone("Continua", _chiudi_popup, 22))

# ---------- dettagli di una regione

func _regione_sopra(reg: String) -> void:
	if reg == "" or m == null:
		info_regione.visible = false
		return
	info_regione_lbl.text = _testo_regione(reg)
	info_regione.visible = true
	var pos := plancia.get_global_mouse_position() + Vector2(24, 16)
	pos.x = minf(pos.x, 1320 - 400)
	pos.y = minf(pos.y, schermo.size.y - 300)
	info_regione.position = pos
	info_regione.reset_size()

func _testo_regione(reg: String) -> String:
	var d: Dictionary = Dati.REGIONI[reg]
	var st: Dictionary = m.s["reg"][reg]
	var t := "[b]%s[/b]" % d["nome"]
	if d.has("pv"):
		var pv: Array = d["pv"]
		t += "   punti " + "/".join(pv.map(func(x): return str(x)))
		var navi := "flotte ammesse" if reg in Dati.NAVALI else ("servita dalle flotte del Mediterraneo" if reg == "ottomano" else "niente flotte")
		t += "\n[i]%s, %s[/i]" % ["colonia" if d.get("col", false) else "Europa", navi]
	else:
		t += "\n[i]patria di %s[/i]" % Dati.NOME_POT[d["casa"]]
	if not st["n"].is_empty():
		var parti: Array = []
		for seg in st["n"]:
			match seg["t"]:
				"col": parti.append("Colonizzare")
				"gcc": parti.append("Costa d'Oro")
				_: parti.append("difesa %d%s" % [int(seg["v"]), " +3 Oro" if seg["bonus"] == "oro" else (" +1 PV" if seg["bonus"] == "pv" else "")])
		t += "\nNeutrali: " + ", ".join(parti)
	if not st["c"].is_empty():
		var pc: Array = []
		for p in st["c"]:
			pc.append("%s %d" % [m.nome_pot(p), int(st["c"][p])])
		t += "\nControllo: " + ", ".join(pc)
		if d.has("pv"):
			var pr := m.punti_regione(reg)
			var pp: Array = []
			for p in pr:
				if int(pr[p]) > 0:
					pp.append("%s %d" % [m.nome_pot(p), int(pr[p])])
			if not pp.is_empty():
				t += "\nOggi varrebbe: " + ", ".join(pp)
	if not st["u"].is_empty():
		for p in st["u"]:
			var u: Array = st["u"][p]
			var pz: Array = []
			for k in 3:
				if int(u[k]) > 0:
					pz.append("%d %s" % [int(u[k]), (Motore.NOMI_U_PL[k] if int(u[k]) > 1 else Motore.NOMI_U[k]).to_lower()])
			var npl := "" if m.gioc_di(p) >= 0 else " (non giocante)"
			t += "\n%s%s: %s" % [m.nome_pot(p), npl, ", ".join(pz)]
	for la in Dati.ALLEANZE:
		if reg in Dati.ALLEANZE[la]["reg"]:
			var chi: String = m.s["locali"][la]
			t += "\nAlleanza locale %s: %s" % [Dati.ALLEANZE[la]["nome"], "libera" if chi == "" else m.nome_pot(chi)]
	return t

func _regione_cliccata(reg: String) -> void:
	var r := m.richiesta()
	if r.is_empty() or not io(int(r["g"])):
		return
	var trovate: Array = []
	for o in r["opz"]:
		if o.get("reg", "") == reg:
			trovate.append(o)
	if trovate.is_empty():
		return
	if trovate.size() == 1 and r["k"] != "azione":
		_decidi(str(trovate[0]["id"]))
		return
	opz_filtrate_reg = reg
	plancia.selezionata = reg
	_mostra_richiesta(r)

# ---------- ciclo

func _process(delta: float) -> void:
	if not in_partita or m == null:
		return
	if m.finita():
		if richiesta_mostrata != -2:
			richiesta_mostrata = -2
			_aggiorna_tutto()
			_mostra_fine()
		return
	var r := m.richiesta()
	if r.is_empty():
		return
	var seat: int = m.g(r["g"])["seat"]
	if seat < 0:
		if popup_aperto and not online:
			return
		attesa += delta * velocita
		var pausa := 0.55 if r["k"] in ["azione", "asta", "piazza"] else 0.3
		if attesa >= pausa:
			attesa = 0.0
			var id := ia.decidi(r)
			m.applica({"id": id})
			_aggiorna_tutto()
			if not online and m.np() > 0:
				_salva(false)
	elif seat == mio_posto:
		if richiesta_mostrata != int(m.s["passo"]):
			richiesta_mostrata = int(m.s["passo"])
			opz_filtrate_reg = ""
			plancia.selezionata = ""
			_mostra_richiesta(r)
	elif online and not aspetto_rete:
		_aspetta_remoto()

func _aspetta_remoto() -> void:
	aspetto_rete = true
	var n: int = m.s["passo"]
	var d = await net.get_decision(codice, n)
	if d is Dictionary and d.has("id") and int(m.s["passo"]) == n:
		m.applica({"id": str(d["id"])})
		_aggiorna_tutto()
	else:
		await get_tree().create_timer(1.0).timeout
	aspetto_rete = false

func _decidi(id: String) -> void:
	if online:
		var n: int = m.s["passo"]
		var ok := await net.post_decision(codice, n, {"id": id})
		if not ok:
			_avviso("Rete: non riesco a inviare la mossa (" + net.last_error + "). Riprova.")
			richiesta_mostrata = -1
			return
	if not m.applica({"id": id}):
		richiesta_mostrata = -1
		return
	opz_filtrate_reg = ""
	plancia.selezionata = ""
	_aggiorna_tutto()
	if not online:
		_salva(false)

func _salva(subito: bool) -> void:
	if online or m == null:
		return
	var testo := JSON.stringify(m.s)
	var f := FileAccess.open(SALVA_LOCALE, FileAccess.WRITE)
	if f:
		f.store_string(testo)
		f.close()
	var ora := Time.get_unix_time_from_system()
	if (subito or ora - ultimo_salvataggio > 30.0) and not salvataggio_in_corso:
		ultimo_salvataggio = ora
		salvataggio_in_corso = true
		await net.salva_partita(m.s)
		salvataggio_in_corso = false

# ---------- pannello delle decisioni

func _svuota_dec() -> void:
	for c in pannello_dec.get_children():
		c.queue_free()

func _mostra_attesa(r: Dictionary) -> void:
	_svuota_dec()
	if r.is_empty():
		titolo_dec.text = ""
		testo_dec.text = ""
		return
	var i: int = r["g"]
	titolo_dec.text = m.nome(i)
	var chi := "l'IA" if int(m.g(i)["seat"]) < 0 else "un altro giocatore"
	testo_dec.text = "Sta decidendo %s (%s)..." % [m.nome(i), chi]
	if int(m.g(i)["seat"]) >= 0 and online:
		testo_dec.text += "\nLa partita va avanti appena arriva la sua mossa."

const TITOLI := {"piazza": "Piazzamento", "asta": "Asta per le alleanze", "azione": "Il tuo turno", "costr_tipo": "Costruire",
	"costr_dest": "Costruire", "milizia": "Milizia", "muovi_da": "Movimento", "muovi_a": "Movimento", "dsm": "Mare aperto",
	"colonizza": "Colonizzare", "commercio": "Costa d'Oro", "alleanza": "Alleanza Locale", "tessera": "Tessere",
	"milind": "Milizia indigena", "blocco_reg": "Blocco navale", "ricatto_quanto": "Trattativa", "ricatto_risp": "Trattativa",
	"att_reg": "Attacco", "att_bers": "Attacco", "sorpresa": "Attacco a sorpresa", "tratt": "Trattative",
	"tratt_risp": "Un'offerta", "tratt_contro": "Controproposta", "impegno": "Chiamata agli alleati", "nav_att": "Battaglia navale",
	"nav_def": "Battaglia navale", "blocco_uso": "Blocco navale", "riserve": "Riserve", "ritirata": "Ritirata combattendo",
	"segreta": "Azione segreta", "segreta_bers": "Azione segreta"}

func _mostra_richiesta(r: Dictionary) -> void:
	_svuota_dec()
	titolo_dec.text = TITOLI.get(r["k"], "Decisione")
	testo_dec.text = str(r["testo"])
	var regs: Array = []
	for o in r["opz"]:
		if o.has("reg") and not (o["reg"] in regs):
			regs.append(o["reg"])
	plancia.evidenzia = regs
	if not regs.is_empty() and r["k"] != "azione":
		pannello_dec.add_child(etichetta("Puoi anche cliccare la regione sulla mappa.", F_CORSIVO, 17, C_SPENTO))
	match r["k"]:
		"asta":
			_widget_asta(r)
			return
		"azione":
			_widget_azione(r)
			return
		"tessera":
			_widget_tessere(r)
			return
	if opz_filtrate_reg != "":
		pannello_dec.add_child(etichetta("In %s:" % Dati.REGIONI[opz_filtrate_reg]["nome"], F_GRASSETTO, 20, C_CERALACCA))
	for o in r["opz"]:
		if opz_filtrate_reg != "" and o.get("reg", "") != opz_filtrate_reg and o.has("reg"):
			continue
		var id: String = str(o["id"])
		var b := bottone(str(o.get("testo", id)), func(): _decidi(id), 19, 0.0, true)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		pannello_dec.add_child(b)
	if opz_filtrate_reg != "":
		pannello_dec.add_child(bottone("Mostra tutte le scelte", func():
			opz_filtrate_reg = ""
			plancia.selezionata = ""
			_mostra_richiesta(r), 18))

func _sezione(t: String) -> void:
	var l := etichetta(t, F_SOTTO, 21, C_CERALACCA)
	pannello_dec.add_child(l)

func _widget_azione(r: Dictionary) -> void:
	var cats := {"reg": "Azioni regolari", "spec": "Azioni speciali (una per turno)", "lib": "Azioni gratuite (tessere)", "tratt": "Trattative", "fine": ""}
	for cat in ["reg", "spec", "lib", "tratt", "fine"]:
		var opz: Array = []
		for o in r["opz"]:
			if o.get("cat", "") == cat:
				opz.append(o)
		if opz.is_empty():
			continue
		if cats[cat] != "":
			_sezione(cats[cat])
		if cat == "tratt":
			var hb := HFlowContainer.new()
			pannello_dec.add_child(hb)
			for o in opz:
				var id: String = str(o["id"])
				hb.add_child(bottone(str(o["testo"]), func(): _decidi(id), 17))
			continue
		var g := GridContainer.new()
		g.columns = 2
		g.add_theme_constant_override("h_separation", 6)
		g.add_theme_constant_override("v_separation", 6)
		pannello_dec.add_child(g)
		for o in opz:
			var id2: String = str(o["id"])
			var b := bottone(str(o["testo"]), func(): _decidi(id2), 19, 0.0, true)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.custom_minimum_size.x = 260
			if o.has("tessera"):
				b.tooltip_text = Dati.TESSERE[o["tessera"]]["testo"]
			if id2 == "fine" and int(m.s["t"]["az"]) > 0:
				b.add_theme_color_override("font_color", C_SPENTO)
			g.add_child(b)

func _widget_tessere(r: Dictionary) -> void:
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	pannello_dec.add_child(g)
	for o in r["opz"]:
		var id: String = str(o["id"])
		if id == "annulla":
			continue
		var b := Button.new()
		b.custom_minimum_size = Vector2(176, 210)
		var c := _carta_tessera(id, 164, m.costo_testo(id))
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.offset_left = 6
		c.offset_top = 4
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for ch in c.get_children():
			ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(c)
		b.tooltip_text = Dati.TESSERE[id]["testo"] + ("\n" + str(o["testo"]).get_slice(" - ", 1) if " - " in str(o["testo"]) else "")
		b.pressed.connect(func(): _decidi(id))
		g.add_child(b)
	pannello_dec.add_child(etichetta("Passa il mouse su una tessera per leggerne l'effetto.", F_CORSIVO, 17, C_SPENTO))
	pannello_dec.add_child(bottone("Annulla", func(): _decidi("annulla"), 19))

func _widget_asta(r: Dictionary) -> void:
	var a: Dictionary = m.s["asta"]
	var coppie := m.coppie_asta()
	var rosse: Array = []
	var blu: Array = []
	for cp in coppie:
		if not (cp[0] in rosse):
			rosse.append(cp[0])
		if not (cp[1] in blu):
			blu.append(cp[1])
	var g := GridContainer.new()
	g.columns = 2
	pannello_dec.add_child(g)
	g.add_child(riga_lbl("Alleanza Rossa:", F_GRASSETTO, 20, C_ROSSA))
	var ob_r := OptionButton.new()
	for p in rosse:
		ob_r.add_item("nessuno" if p == "" else m.nome_pot(p))
	g.add_child(ob_r)
	g.add_child(riga_lbl("Alleanza Blu:", F_GRASSETTO, 20, C_BLU))
	var ob_b := OptionButton.new()
	for p in blu:
		ob_b.add_item("nessuno" if p == "" else m.nome_pot(p))
	g.add_child(ob_b)
	if int(a["offerta"]) >= 0:
		var ir: int = rosse.find(a["R"])
		var ib: int = blu.find(a["B"])
		if ir >= 0:
			ob_r.selected = ir
		if ib >= 0:
			ob_b.selected = ib
	elif blu.size() > 1:
		ob_b.selected = 1 if rosse[0] == blu[0] else 0
	g.add_child(riga_lbl("Offerta in Oro:", F_GRASSETTO, 20))
	var sb := SpinBox.new()
	sb.min_value = int(r.get("minimo", 0))
	sb.max_value = int(r.get("massimo", 10))
	sb.value = sb.min_value
	g.add_child(sb)
	var msg := etichetta("", F_CORSIVO, 18, C_CERALACCA)
	pannello_dec.add_child(msg)
	pannello_dec.add_child(etichetta("Hai %d Oro. Paghi solo se vinci l'asta; se non basta, Tassazione (+1 Tensione ogni 2 Oro)." % int(m.g(mio())["oro"]), F_TESTO, 18, C_SPENTO))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	pannello_dec.add_child(h)
	h.add_child(bottone("Proponi" if int(a["offerta"]) < 0 else "Rilancia", func():
		var pr: String = rosse[ob_r.selected] if ob_r.selected >= 0 else ""
		var pb: String = blu[ob_b.selected] if ob_b.selected >= 0 else ""
		var id := "%s|%s|%d" % [pr, pb, int(sb.value)]
		if _ha_opzione(r, id):
			_decidi(id)
		else:
			msg.text = "Proposta non valida: scegli due potenze diverse non ancora schierate.", 21))
	if int(a["offerta"]) >= 0:
		h.add_child(bottone("Passo", func(): _decidi("passa"), 21))
	# le alleanze già formate
	var gia := ""
	for lato in ["R", "B"]:
		var arr: Array = []
		for p in m.s["slot"][lato]:
			arr.append(m.nome_pot(p))
		gia += "%s: %s\n" % ["Rossa" if lato == "R" else "Blu", ", ".join(arr) if not arr.is_empty() else "nessuno"]
	pannello_dec.add_child(etichetta("Già schierati nelle Grandi Alleanze:\n" + gia, F_TESTO, 18))

func _ha_opzione(r: Dictionary, id: String) -> bool:
	for o in r["opz"]:
		if str(o["id"]) == id:
			return true
	return false

func _mostra_fine() -> void:
	var es: Dictionary = m.s["esito"]
	var v := _apri_popup("Fine della partita", 820)
	v.add_child(etichetta(str(es.get("testo", "")), F_SOTTO, 28, C_CERALACCA))
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 24)
	v.add_child(g)
	for i in es.get("classifica", []):
		var gg := m.g(int(i))
		g.add_child(immagine("res://assets/stemmi/%s.png" % Dati.STEMMA[gg["pot"]], 40, 48))
		g.add_child(riga_lbl(m.nome(int(i)), F_GRASSETTO, 22))
		g.add_child(riga_lbl("%d PV" % int(gg["pv"]), F_TESTO, 22))
		g.add_child(riga_lbl("Tensione %d%s" % [int(gg["tens"]), " - rivoluzione!" if gg["fuori"] else ""], F_TESTO, 20))
	v.add_child(bottone("Torna al menu", func():
		if not online:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SALVA_LOCALE))
		mostra_menu(), 22))
	v.add_child(bottone("Guarda la mappa", _chiudi_popup, 20))
