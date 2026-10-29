---------------------------------------------------------------
-- ShamanRotation_Shield.lua : bouclier elementaire automatique (Water Shield / Earth Shield), remis quand il disparait
-- Donnees serveur (spell_template + Spell.dbc) : les deux durent 10 min, ont 3 charges, un seul bouclier elementaire a la fois, GCD normal (133).
--   Water Shield rang 5 : 0 mana ; quand une attaque TE TOUCHE (1 fois / 3 s max) : +130 mana et une charge consommee.
--   Earth Shield rang 3 : 300 mana ; quand une attaque te touche : +150 PV et une charge ; +30 % de chances de ne pas etre interrompu par les degats.
-- Lua 5.0 strict.
---------------------------------------------------------------
local SH = ShamanRotation

SH.SHIELD_SPELL = { water = "Water Shield", earth = "Earth Shield" }
SH.SHIELD_IDS = {
	water = { [45527] = true, [51533] = true, [51534] = true, [51535] = true, [51536] = true },
	earth = { [45525] = true, [51525] = true, [51526] = true },
}
SH.shieldTry = -10
SH.shieldCast = nil
SH.shieldMiss = 0
SH.shieldWait = 3
SH.shieldSeen = false

-- icone du sort dans le livre (repli quand le client ne donne pas l'ID du sort dans UnitBuff)
function SH.ShieldTex(kind)
	local idx = SH.GetSpellIdx(SH.SHIELD_SPELL[kind])
	if idx and GetSpellTexture then return GetSpellTexture(idx, "spell") end
	return nil
end

-- repli : lit le NOM du buff dans une infobulle cachee (methode classique 1.12), quand ni l'ID ni l'icone ne correspondent
function SH.ShieldByTooltip()
	if not SH.scanTip then
		local ok, tip = pcall(CreateFrame, "GameTooltip", "ShamanRotScanTip", UIParent, "GameTooltipTemplate")
		if not ok or not tip then SH.scanTip = false; return nil end
		pcall(tip.SetOwner, tip, UIParent, "ANCHOR_NONE")
		SH.scanTip = tip
	end
	if not SH.scanTip then return nil end
	local i = 1
	while i <= 32 do
		local ok = pcall(SH.scanTip.SetUnitBuff, SH.scanTip, "player", i)
		if not ok then return nil end
		local fs = getglobal("ShamanRotScanTipTextLeft1")
		local txt = fs and fs:GetText() or nil
		if not txt or txt == "" then return nil end
		if txt == "Water Shield" then return "water", 1 end
		if txt == "Earth Shield" then return "earth", 1 end
		i = i + 1
	end
	return nil
end

-- bouclier actuellement sur le joueur : "water" | "earth" | nil, et son nombre de charges
function SH.ActiveShield()
	local texW, texE = SH.ShieldTex("water"), SH.ShieldTex("earth")
	local i = 1
	while i <= 32 do
		local tex, stacks, sid = UnitBuff("player", i)
		if not tex then break end
		if sid then
			sid = tonumber(sid)
			if SH.SHIELD_IDS.water[sid] then return "water", stacks or 1 end
			if SH.SHIELD_IDS.earth[sid] then return "earth", stacks or 1 end
		end
		if texW and tex == texW then return "water", stacks or 1 end
		if texE and tex == texE then return "earth", stacks or 1 end
		i = i + 1
	end
	local okT, k, n = pcall(SH.ShieldByTooltip)
	if okT and k then return k, n end
	return nil, 0
end

-- trace de diagnostic : les buffs vus (icone + ID) quand le bouclier lance n'est pas reconnu (lue apres un /reload)
function SH.ShieldDiag(now)
	local db = ShamanRotationDB
	if type(db) ~= "table" or db.shieldDiag then return end
	local out, i = {}, 1
	while i <= 12 do
		local tex, stacks, sid = UnitBuff("player", i)
		if not tex then break end
		table.insert(out, tostring(tex) .. " / id " .. tostring(sid) .. " / x" .. tostring(stacks))
		i = i + 1
	end
	db.shieldDiag = { at = now, book = tostring(SH.ShieldTex(SH.CFG.shield)), buffs = out }
end

-- heuristique : le joueur boit / mange (un sort ferait perdre la regeneration) ; reconnu a l'icone du buff
function SH.IsEatingOrDrinking()
	local i = 1
	while i <= 32 do
		local tex = UnitBuff("player", i)
		if not tex then break end
		local low = string.lower(tex)
		if string.find(low, "drink", 1, true) or string.find(low, "food", 1, true) or string.find(low, "fork", 1, true) then return true end
		i = i + 1
	end
	return false
end

-- monte ? IsMounted si le client l'a, sinon l'icone du buff de monture (Ability_Mount_*)
function SH.IsMountedNow()
	if type(IsMounted) == "function" then
		local ok, r = pcall(IsMounted)
		if ok and r then return true end
	end
	local i = 1
	while i <= 32 do
		local tex = UnitBuff("player", i)
		if not tex then break end
		if string.find(string.lower(tex), "ability_mount", 1, true) then return true end
		i = i + 1
	end
	return false
end

-- remet le bouclier choisi s'il manque (ou si l'AUTRE bouclier est actif : il est remplace). Vrai si l'appui est consomme.
function SH.ShieldStep(now, inCombat)
	local CFG = SH.CFG
	local kind = CFG.shield
	if kind ~= "water" and kind ~= "earth" then return false end
	if inCombat and not CFG.shieldCombat then return false end
	if (not inCombat) and not CFG.shieldAuto then return false end
	local name = SH.SHIELD_SPELL[kind]
	if not SH.Known(name) then return false end
	if now - SH.shieldTry < SH.shieldWait then return false end   -- laisse le jeu repondre, pas de rafale si le lancer echoue
	local active, stacks = SH.ActiveShield()
	if active == kind then SH.shieldSeen = true end
	if active == kind and (stacks or 1) >= CFG.shieldMinCharges then
		SH.shieldMiss = 0
		SH.shieldWait = 3
		return false
	end
	-- on l'avait lance il y a peu et il n'est toujours pas reconnu : detection en defaut -> on espace de plus en plus (3, 6, 12... 120 s), jamais de rafale
	if SH.shieldCast and not SH.shieldSeen and now - SH.shieldCast < 30 then
		SH.shieldMiss = SH.shieldMiss + 1
		SH.shieldWait = math.min(120, 3 * (2 ^ SH.shieldMiss))
		SH.ShieldDiag(now)
	end
	if SH.CdInfo(name) > 0 or SH.Blocked(name) then return false end
	if now < SH.castUntil then return false end
	if not inCombat and SH.IsEatingOrDrinking() then return false end
	SH.shieldTry = now
	SH.shieldCast = now
	SH.shieldSeen = false
	SH.Dbg("BOUCLIER -> " .. name)
	SH.Cast(name)
	SH.Decide(now, "Bouclier : " .. name .. (active and (active ~= kind) and " (remplace l'autre bouclier)" or ""))
	return true
end
