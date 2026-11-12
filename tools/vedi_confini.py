import cv2, json, numpy as np, sys
im = cv2.imread('assets/mappa/plancia.jpg'); W=1500; H=int(im.shape[0]*W/im.shape[1])
sm = cv2.resize(im,(W,H),interpolation=cv2.INTER_AREA)
c = json.load(open('assets/mappa/confini.json'))
sel = sys.argv[1].split(',') if len(sys.argv)>1 else list(c)
tiles=[]
for reg in sel:
    v = (sm*0.6).astype(np.uint8)
    pts=[]
    for poly in c[reg]:
        a = (np.array(poly)*[W,H]).astype(np.int32)
        cv2.polylines(v,[a],True,(0,255,255),2); pts+=a.tolist()
    a=np.array(pts); x0,y0=a.min(0)-30; x1,y1=a.max(0)+30
    x0,y0=max(x0,0),max(y0,0)
    t=v[y0:y1,x0:x1]; f=min(360/t.shape[1],300/t.shape[0]); t=cv2.resize(t,None,fx=f,fy=f)
    T=np.zeros((310,370,3),np.uint8); T[:t.shape[0],:t.shape[1]]=t
    cv2.putText(T,reg,(5,300),0,0.6,(255,255,255),2); tiles.append(T)
while len(tiles)%4: tiles.append(np.zeros_like(tiles[0]))
rows=[np.hstack(tiles[i:i+4]) for i in range(0,len(tiles),4)]
cv2.imwrite('/tmp/tav.jpg',np.vstack(rows))
