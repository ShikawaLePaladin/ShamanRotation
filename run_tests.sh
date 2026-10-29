#!/bin/sh
# run_tests.sh : verifie ShamanRotation (jamais de deploiement). Usage : sh run_tests.sh
cd "$(dirname "$0")" || exit 1
export NODE_PATH="${NODE_PATH:-C:/Temp/ccx/luatest/node_modules}"
FAIL=0
echo "=== Lint Lua 5.0"
for f in ShamanRotation/*.lua; do out=$(node tests/lint50.js "$f" 2>&1); if echo "$out" | head -1 | grep -q "LINT OK"; then echo "  OK   $f"; else echo "  ECHEC $f"; echo "$out"; FAIL=1; fi; done
echo "=== Suites"
for t in t_sha t_ui t_relic; do out=$(cd tests && node harness.js $t.lua 2>&1); echo "  $t : $(echo "$out" | tail -1)"; if ! echo "$out" | tail -1 | grep -q " 0 ECHECS"; then echo "$out" | head -20; FAIL=1; fi; done
if [ $FAIL -eq 0 ]; then echo "TOUT EST VERT"; else echo "ECHEC : voir ci-dessus"; fi
exit $FAIL
