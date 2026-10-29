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

-- icone du sort dans le livre (repli quand le client ne donne pas l'ID du sort dans UnitBuff)
function SH.ShieldTex(kind)
	local idx = SH.GetSpellIdx(SH.SHIELD_SPELL[kind])
	if idx and GetSpellTexture then return GetSpellTexture(idx, "spell") end
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
	return nil, 0
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
	if now - SH.shieldTry < 3 then return false end            -- laisse le jeu repondre, pas de rafale si le lancer echoue
	local active, stacks = SH.ActiveShield()
	if active == kind and (stacks or 1) >= CFG.shieldMinCharges then return false end
	if SH.CdInfo(name) > 0 or SH.Blocked(name) then return false end
	if now < SH.castUntil then return false end
	if not inCombat and SH.IsEatingOrDrinking() then return false end
	SH.shieldTry = now
	SH.Dbg("BOUCLIER -> " .. name)
	SH.Cast(name)
	SH.Decide(now, "Bouclier : " .. name .. (active and (active ~= kind) and " (remplace l'autre bouclier)" or ""))
	return true
end
