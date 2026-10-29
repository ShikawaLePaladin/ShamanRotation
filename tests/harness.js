// Harnais de test ShikiwaRotation : API WoW 1.12 simulee (fengari = Lua 5.3 avec les raccourcis 5.0), STRICT :
//  - methodes de widgets limitees a la liste 1.12 (voir mock_wow.lua) ;
//  - lecture d'une globale non definie = ERREUR (sauf API optionnelles listees) -> detecte les fautes de frappe ;
//  - les fichiers de l'addon sont charges dans l'ordre du .toc, chacun dans son propre chunk (comme le client).
// Usage : node harness.js <suite.lua>      env : ADDON_DIR (dossier de l'addon), LEGACY=1 (charge legacy/ShikiwaRotation_v1.lua)
const fs = require('fs');
const path = require('path');
function req(name) {
  const cands = [path.join(__dirname, 'node_modules'), 'C:/Temp/ccx/luatest/node_modules', path.join(__dirname, '..', 'node_modules')];
  for (const c of cands) { try { return require(path.join(c, name)); } catch (e) { /* suivant */ } }
  return require(name);
}
const { lua, lauxlib, lualib, to_luastring } = req('fengari');
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);

function run(code, name) {
  const s = to_luastring(code);
  if (lauxlib.luaL_loadbuffer(L, s, s.length, to_luastring('@' + name)) || lua.lua_pcall(L, 0, 0, 0)) {
    console.log('LUA ERROR in ' + name + ': ' + lua.lua_tojsstring(L, -1));
    process.exit(1);
  }
}
const here = __dirname;
const addonDir = process.env.ADDON_DIR || path.join(here, '..', 'ShamanRotation');
run(fs.readFileSync(path.join(here, 'mock_wow.lua'), 'utf8').replace(/^\uFEFF/, ''), 'mock_wow.lua');
{
  // sauvegardes REELLES de la v1 (copies en lecture seule des SavedVariables des clients) : injectees comme texte
  const fdir = path.join(here, 'fixtures');
  let code = 'FIXTURES = {}\n';
  if (fs.existsSync(fdir)) for (const f of fs.readdirSync(fdir)) code += 'FIXTURES[' + JSON.stringify(f) + '] = ' + JSON.stringify(fs.readFileSync(path.join(fdir, f), 'utf8')) + '\n';
  run(code, 'fixtures');
}
run('STRICT_ON()', 'strict');
if (process.env.NOAPI) run('NOAPI_REMOVE()', 'noapi');
let files;
if (process.env.LEGACY) {
  files = [path.join(here, '..', 'legacy', 'ShikiwaRotation_v1.lua')];
} else {
  const toc = fs.readFileSync(path.join(addonDir, 'ShamanRotation.toc'), 'utf8').split(/\r?\n/);
  files = toc.map(l => l.trim()).filter(l => l && l.indexOf('##') !== 0).map(f => path.join(addonDir, f));
}
for (const f of files) run(fs.readFileSync(f, 'utf8').replace(/^\uFEFF/, ''), path.basename(f));
run(fs.readFileSync(path.join(here, 'lib_sim_sha.lua'), 'utf8').replace(/^\uFEFF/, ''), 'lib_sim_sha.lua');
const suite = process.argv[2];
run(fs.readFileSync(path.isAbsolute(suite) ? suite : path.join(process.cwd(), suite), 'utf8').replace(/^\uFEFF/, ''), path.basename(suite));
run('if not TESTS_DONE then print("SUITE ENDED WITHOUT TESTS_DONE") ; os.exit(1) end', 'end');
