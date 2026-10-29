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

-- ===== touches : capture clavier / souris dans le menu
SIM.setup(); SIM.load(nil)
SH.OpenMenu(true); SH.ShowTab("touches")
W.bindings = {}
local function press(raw, shift)
  W.shift = shift or false
  this = SH.keyCap; arg1 = raw; SH.keyCap.scripts.OnKeyDown(); W.shift = false
end
SH.StartKeyCapture("SHAMANROT_ROTATION", "Rotation (une touche)")
ok(SH.keyCap:IsShown(), "capture ouverte")
press("F5")
eq(W.bindings["SHAMANROT_ROTATION"], "F5", "touche F5 liee a la rotation")
ok(not SH.keyCap:IsShown(), "capture fermee apres la touche")
eq(ShamanRotKeyBtn1:GetText(), "F5", "le bouton affiche F5")
-- changer de touche : l'ancienne est retiree
SH.StartKeyCapture("SHAMANROT_ROTATION", "Rotation"); press("F6", true)
eq(W.bindings["SHAMANROT_ROTATION"], "SHIFT-F6", "Maj + F6")
-- Echap annule
SH.StartKeyCapture("SHAMANROT_ROTATION", "Rotation"); press("ESCAPE")
eq(W.bindings["SHAMANROT_ROTATION"], "SHIFT-F6", "Echap : rien ne change")
-- modificateur seul ignore ; clic gauche seul ignore
SH.StartKeyCapture("SHAMANROT_ROTATION", "Rotation"); press("LSHIFT"); ok(SH.keyCap:IsShown(), "Maj seule : on attend toujours")
press("LeftButton"); ok(SH.keyCap:IsShown(), "clic gauche seul : ignore")
press("Button4"); eq(W.bindings["SHAMANROT_ROTATION"], "BUTTON4", "bouton de souris 4")
-- molette
SH.StartKeyCapture("SHAMANROT_BURST", "Burst"); this = SH.keyCap; arg1 = 1; SH.keyCap.scripts.OnMouseWheel()
eq(W.bindings["SHAMANROT_BURST"], "MOUSEWHEELUP", "molette haut")
-- une touche deja prise par une autre action lui est reprise
SH.StartKeyCapture("SHAMANROT_TOTEMS", "Totems"); press("F7")
SH.StartKeyCapture("SHAMANROT_AOE", "AoE"); press("F7")
eq(W.bindings["SHAMANROT_AOE"], "F7", "F7 reprise par le mode AoE")
eq(W.bindings["SHAMANROT_TOTEMS"], nil, "... et retiree des totems")
-- bouton Retirer
this = ShamanRotKeyClr2; ShamanRotKeyClr2.scripts.OnClick()
eq(W.bindings["SHAMANROT_BURST"], nil, "Retirer : touche du burst retiree")
eq(ShamanRotKeyBtn2:GetText(), "Cliquer pour definir", "... le bouton le dit")
-- clic sur le bouton : texte d'attente + capture
this = ShamanRotKeyBtn3; ShamanRotKeyBtn3.scripts.OnClick()
ok(SH.keyCap:IsShown(), "clic sur le bouton : capture ouverte")
press("ESCAPE")
-- menu : liaison
ok(type(ShamanRotation_OpenMenu) == "function", "fonction ShamanRotation_OpenMenu (liaison Ouvrir le menu)")
eq(table.getn(SH.KEYROWS), 6, "6 actions liables (dont Poser tous les totems)")

DONE()