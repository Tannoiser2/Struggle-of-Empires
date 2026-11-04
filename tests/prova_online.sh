#!/bin/bash
# Prova online completa: finto Firebase + due istanze di Godot (host e ospite).
# Uso: GODOT=/percorso/godot tests/prova_online.sh
cd "$(dirname "$0")/.."
G=${GODOT:-godot}
python3 tests/firebase_mock.py 8765 > /tmp/mock.log 2>&1 &
MOCK=$!
sleep 1
export FR_DB_URL=http://127.0.0.1:8765/db FR_AUTH_URL=http://127.0.0.1:8765/signup FR_REFRESH_URL=http://127.0.0.1:8765/refresh
rm -f /tmp/soe_code /tmp/s_host.cfg /tmp/s_guest.cfg
SOE_ROLE=host SOE_CODEFILE=/tmp/soe_code FR_SESSION=/tmp/s_host.cfg timeout 900 $G --headless --path . -s res://tests/online_auto.gd > /tmp/host.log 2>&1 &
H=$!
SOE_ROLE=guest SOE_CODEFILE=/tmp/soe_code FR_SESSION=/tmp/s_guest.cfg timeout 900 $G --headless --path . -s res://tests/online_auto.gd > /tmp/guest.log 2>&1 &
O=$!
wait $H $O
kill $MOCK
grep "SOE" /tmp/host.log /tmp/guest.log
