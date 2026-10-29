-- t_ui.lua : menu, HUD, minimap de ShamanRotation (API 1.12 stricte)
local SH = ShamanRotation
local CFG = SH.CFG

local function try(name, fn)
  local okp, err = pcall(fn)
  if not okp then FAILS = FAILS + 1; print("FAIL: " .. name .. " -> " .. tostring(err)) else PASSES = PASSES + 1 end
  return okp
end

SIM.setup(); SIM.load(nil)
Fire("PLAYER_LOGIN")
ok(ShamanRotationHud ~= nil, "HUD cree a la connexion")
ok(ShamanRotationMinimapButton ~= nil, "bouton de minimap cree")

try("ouverture du menu", function() SH.OpenMenu(true) end)
ok(ShamanRotationOptionsFrame ~= nil and ShamanRotationOptionsFrame:IsShown(), "menu affiche")
try("tous les onglets", function()
  for i = 1, table.getn(SH.TAB_DEFS) do SH.ShowTab(SH.TAB_DEFS[i].id) end
end)
-- taille FIXE : la hauteur du panneau ne change jamais d'un onglet a l'autre
local h0 = ShamanRotationOptionsFrame:GetHeight()
local same = true
for i = 1, table.getn(SH.TAB_DEFS) do SH.ShowTab(SH.TAB_DEFS[i].id); if ShamanRotationOptionsFrame:GetHeight() ~= h0 then same = false end end
ok(same, "hauteur du menu identique sur tous les onglets (" .. tostring(h0) .. ")")
try("refresh", function() SH.RefreshOptions(); SH.RefreshStatus() end)

-- cases a cocher : ecrivent dans les reglages ET dans la sauvegarde
local c = ShamanRotOpt_UseFs
ok(c ~= nil, "case Flame Shock presente")
c:SetChecked(false); this = c; c.scripts.OnClick()
eq(CFG.useFs, false, "case Flame Shock decochee")
eq(ShamanRotationDB.settings.useFs, false, "... sauvegardee")
c:SetChecked(true); this = c; c.scripts.OnClick()
eq(CFG.useFs, true, "case Flame Shock recochee")

-- bouton cyclique : mode AoE auto -> on -> off -> auto
local cy = ShamanRotCyc_aoe
ok(cy ~= nil, "bouton de mode AoE present")
eq(CFG.aoeMode, "auto", "mode AoE par defaut : auto")
this = cy; cy.scripts.OnClick(); eq(CFG.aoeMode, "on", "clic -> on")
this = cy; cy.scripts.OnClick(); eq(CFG.aoeMode, "off", "clic -> off")
this = cy; cy.scripts.OnClick(); eq(CFG.aoeMode, "auto", "clic -> auto")
local ct = ShamanRotCyc_tot
this = ct; ct.scripts.OnClick(); eq(CFG.totemPreset, "melee", "combo de totems : caster -> melee")

-- curseurs
local sl = ShamanRotOpt_fsRefresh
ok(sl ~= nil, "curseur fsRefresh present")
sl:SetValue(6); eq(CFG.fsRefresh, 6, "curseur fsRefresh : 6 s")
eq(ShamanRotationDB.settings.fsRefresh, 6, "... sauvegarde")

-- persistance : rechargement avec la sauvegarde
local saved = ShamanRotationDB
SH.SetSetting("autoAoeMin", 4)
for k, v in pairs(SH.DEFAULTS) do CFG[k] = v end
SIM.load(saved)
eq(CFG.autoAoeMin, 4, "rechargement : autoAoeMin conserve")
eq(CFG.fsRefresh, 6, "rechargement : fsRefresh conserve")
eq(CFG.totemPreset, "melee", "rechargement : combo de totems conserve")
-- valeur de mauvais type dans la sauvegarde : ignoree
SIM.load({ settings = { fsRefresh = "abc", useCl = 5 } })
eq(CFG.fsRefresh, SH.DEFAULTS.fsRefresh, "sauvegarde corrompue : valeur par defaut")

-- HUD : mise a jour sans erreur dans tous les etats
try("HUD sans cible", function() W.target = nil; SH.HudUpdate() end)
SIM.setup(); SIM.load(nil)
try("HUD avec cible et Flame Shock", function() SIM.press(); Pump(1.6); SH.HudUpdate() end)
ok(SH.hudIcons.fs.txt:GetText() ~= nil, "HUD : minuteur Flame Shock")
try("HUD apres burst + totems", function() ShamanRotation_Burst(); ShamanRotation_Totems(); Pump(1.6); SH.HudUpdate() end)
try("HUD cache / affiche / echelle", function() CFG.hud = false; SH.HudRefreshConfig(); CFG.hud = true; CFG.hudScale = 1.5; SH.HudRefreshConfig() end)
try("commandes menu / hud", function() SH.Slash("menu"); SH.Slash("menu"); SH.Slash("hud"); SH.Slash("hud") end)

-- minimap
try("minimap : positionner, bouton, clic droit", function()
  SH.MinimapPlace(); SH.MinimapToggle(); SH.MinimapToggle()
  this = ShamanRotationMinimapButton; arg1 = "RightButton"; ShamanRotationMinimapButton.scripts.OnClick(); arg1 = "LeftButton"; ShamanRotationMinimapButton.scripts.OnClick()
end)

-- aucune extension
try("menu sans extensions", function() W.noRange = true; W.noXP = true; SH.RefreshStatus(); SH.HudUpdate() end)

DONE()
