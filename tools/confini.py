"""Estrae i contorni delle regioni dalla plancia: pixel del colore della regione (preso dai punti seme)
dentro un'area di ritaglio (il cerchio per le colonie, un riquadro per l'Europa) -> assets/mappa/confini.json"""
import cv2, numpy as np, json
im = cv2.imread('assets/mappa/plancia.jpg')
W = 1500
s = W / im.shape[1]
sm = cv2.resize(im, (W, int(im.shape[0] * s)), interpolation=cv2.INTER_AREA)
bl = cv2.medianBlur(sm, 9)
bl = cv2.bilateralFilter(bl, 9, 30, 9)
lab = cv2.cvtColor(bl, cv2.COLOR_BGR2LAB).astype(np.float32)
H = sm.shape[0]
CERCHI = {"am": (475, 330, 250), "af": (680, 722, 152), "in": (1007, 722, 152), "ie": (1342, 722, 152)}
R = {  # semi, ritaglio, soglia
 "nordamerica": ([(450,120),(330,190),(560,150),(400,200)], ("c","am",(0,0,1500,238)), 22),
 "caraibi": ([(330,250),(345,240),(380,322),(460,345),(450,245),(400,330),(490,350)], ("c","am",(318,232,520,365)), 15),
 "sudamerica": ([(520,450),(450,520),(470,400),(560,470),(440,560)], ("c","am",(0,345,1500,1000)), 22),
 "africa": ([(700,700),(640,650),(760,760)], ("c","af",None), 22),
 "india": ([(1000,700),(960,640),(1050,650)], ("c","in",None), 22),
 "indie": ([(1250,620),(1265,700),(1300,650),(1330,770),(1400,700),(1440,760)], ("c","ie",None), 12),
 "baltico": ([(1310,160),(1290,80),(1110,90),(1050,110),(1180,70),(1350,100)], ("b",(1000,40,1400,185)), 15),
 "centro": ([(1300,280),(1250,220),(1380,300),(1230,330)], ("b",(1165,170,1430,360)), 20),
 "mediterraneo": ([(1080,420),(1150,470),(1050,475),(1185,535),(1140,560),(1100,440)], ("b",(1025,350,1215,580)), 16),
 "ottomano": ([(1300,450),(1400,420),(1230,420),(1260,520),(1450,480),(1450,560)], ("b",(1165,320,1500,605)), 18),
 "casa_gb": ([(890,180),(800,190),(880,110),(900,240)], ("b",(765,55,955,285)), 20),
 "casa_fr": ([(920,370),(960,320),(1000,390)], ("b",(870,280,1035,425)), 14),
 "casa_sp": ([(850,450),(880,500),(920,430)], ("b",(780,408,950,565)), 16),
 "casa_up": ([(1000,215),(1015,230)], ("b",(985,195,1045,250)), 20),
 "casa_au": ([(1180,330),(1160,350)], ("b",(1110,300,1205,395)), 12),
 "casa_pr": ([(1130,215),(1150,200),(1105,230)], ("b",(1085,175,1175,240)), 14),
 "casa_ru": ([(1460,250),(1465,330),(1450,150)], ("b",(1380,60,1500,400)), 12),
 "germania": ([(990,270),(1060,300),(1150,300),(1060,200),(1190,295)], ("b",(945,165,1225,335)), 18),
}
yy, xx = np.mgrid[0:H, 0:W]
MARE = [(300,300),(305,260),(310,330),(800,300),(700,450),(980,560),(1230,150),(1000,150),(600,300),(780,690),(560,760),(900,760),(1240,780),(1400,560),(860,560),(1180,600),(980,440),(1330,540)]
mc = np.array([lab[y, x] for (x, y) in MARE])
dmare = np.min(np.stack([np.linalg.norm(lab - c, axis=2) for c in mc]), axis=0)
out = {}
fatte = {}
ESCLUDI = {"germania": ["casa_pr", "casa_up", "casa_au", "casa_fr", "centro"], "centro": []}
vis = sm.copy()
for reg, (semi, clip, soglia) in R.items():
    cols = np.array([lab[y, x] for (x, y) in semi])
    d = np.min(np.stack([np.linalg.norm(lab - c, axis=2) for c in cols]), axis=0)
    mask = ((d < soglia) & ((dmare > 9) | (d < dmare - 6))).astype(np.uint8) * 255
    clipm = np.zeros((H, W), np.uint8)
    if clip[0] == "c":
        cx, cy, r = CERCHI[clip[1]]
        clipm[((xx - cx) ** 2 + (yy - cy) ** 2) < (r - 4) ** 2] = 255
        if clip[2]:
            x0, y0, x1, y1 = clip[2]
            b = np.zeros_like(clipm); b[y0:y1, x0:x1] = 255; clipm &= b
    else:
        x0, y0, x1, y1 = clip[1]
        clipm[y0:y1, x0:x1] = 255
    mask &= clipm
    for altro in ESCLUDI.get(reg, []):
        mask &= cv2.bitwise_not(cv2.dilate(fatte[altro], np.ones((5, 5), np.uint8)))
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5)))
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (15, 15)))
    # tieni solo i pezzi che contengono un seme o sono grandi
    n, lbl, st, _ = cv2.connectedComponentsWithStats(mask)
    keep = set(lbl[y, x] for (x, y) in semi if mask[y, x])
    for i in range(1, n):
        if st[i, cv2.CC_STAT_AREA] > 900:
            keep.add(i)
    keep.discard(0)
    mask = np.isin(lbl, list(keep)).astype(np.uint8) * 255
    fatte[reg] = mask
    cs, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    polys = []
    for c in cs:
        if cv2.contourArea(c) < 150:
            continue
        c = cv2.approxPolyDP(c, 1.0, True)
        polys.append([[round(float(p[0][0]) / W, 5), round(float(p[0][1]) / H, 5)] for p in c])
        cv2.polylines(vis, [c], True, (0, 0, 255), 2)
    for (x, y) in semi:
        cv2.circle(vis, (x, y), 3, (255, 0, 255), -1)
    out[reg] = polys
    print(reg, len(polys), sum(len(p) for p in polys))
json.dump(out, open('assets/mappa/confini.json', 'w'))
cv2.imwrite('/tmp/confini.jpg', vis)
