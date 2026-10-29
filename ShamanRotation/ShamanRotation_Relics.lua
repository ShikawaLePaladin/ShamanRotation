---------------------------------------------------------------
-- ShamanRotation_Relics.lua : echange de reliques (totems de l'emplacement 18), version "wait" UNIQUEMENT
-- Donnee serveur (Player.cpp, deja prouvee pour les armes) : equiper un objet en combat declenche un GCD de 1,5 s. Un echange "en meme temps que le sort"
-- est donc impossible : l'echange prend l'appui, le sort part a l'appui suivant (= le mode "wait" de ShikaSwap).
-- Modes : off | main (une seule relique, posee HORS combat) | spell (une relique par sort, echange en combat espace d'au moins relicGap s).
-- Effets des reliques : item_template + Spell.dbc du serveur (voir DESIGN.md). Lua 5.0 strict.
---------------------------------------------------------------
local SH = ShamanRotation

-- nom -> { id, effet (verifie sur le serveur), sorts concernes }
SH.RELICS = {
	["Totem of the Storm"] = { 23199, "+33 degats a Chain Lightning et Lightning Bolt", { "Lightning Bolt", "Chain Lightning" } },
	["Totem of Crackling Thunder"] = { 61292, "Lightning Bolt : 10 % de chances de +8 % vitesse d'attaque et d'incantation pendant 8 s", { "Lightning Bolt" } },
	["Totem of Static Charge"] = { 55370, "Lightning Bolt : 10 % de chances d'un choc de Nature supplementaire (29 degats de base)", { "Lightning Bolt" } },
	["Totem of Rage"] = { 22395, "Augmente les degats des chocs (Flame / Earth / Frost Shock)", { "Flame Shock", "Earth Shock", "Frost Shock" } },
	["Totem of the Endless Flicker"] = { 51803, "Flame Shock dure 3 s de plus", { "Flame Shock" } },
	["Totem of Broken Earth"] = { 55114, "Earth Shock : degats en plus et ralentit la vitesse d'attaque de la cible", { "Earth Shock" } },
	["Totem of Distant Tremors"] = { 33090, "Earthquake : l'Aftershock fait +67 % de degats mais arrive 2 s plus tard", { "Earthquake" } },
	["Totem of Eruption"] = { 58241, "Molten Blast : +35 degats (et degats supplementaires selon la duree rafraichie)", { "Molten Blast" } },
}
SH.RELIC_NAMES = { "Totem of the Storm", "Totem of Crackling Thunder", "Totem of Static Charge", "Totem of Rage", "Totem of the Endless Flicker", "Totem of Broken Earth",
	"Totem of Distant Tremors", "Totem of Eruption" }
SH.RELIC_SPELLS = { "Lightning Bolt", "Chain Lightning", "Flame Shock", "Earth Shock", "Earthquake", "Molten Blast" }
SH.RELIC_SLOT = 18

SH.relic = { at = -100, busyUntil = 0 }

function SH.ItemIdOfLink(link)
	if not link then return nil end
	local _, _, id = string.find(link, "item:(%d+)")
	if id then return tonumber(id) end
	return nil
end

function SH.RelicEquippedId()
	return SH.ItemIdOfLink(GetInventoryItemLink("player", SH.RELIC_SLOT))
end

-- (sac, case) de l'objet `id` dans les sacs, ou nil
function SH.RelicFind(id)
	local bag, slot
	for bag = 0, 4 do
		local n = GetContainerNumSlots(bag) or 0
		for slot = 1, n do
			if SH.ItemIdOfLink(GetContainerItemLink(bag, slot)) == id then return bag, slot end
		end
	end
	return nil
end

-- relique possedee (equipee ou en sac)
function SH.RelicOwned(name)
	local info = SH.RELICS[name]
	if not info then return false end
	if SH.RelicEquippedId() == info[1] then return true end
	return SH.RelicFind(info[1]) ~= nil
end

function SH.RelicRule(spell)
	local db = ShamanRotationDB
	if type(db) ~= "table" or type(db.relics) ~= "table" then return nil end
	local name = db.relics[spell]
	if name and SH.RELICS[name] then return name end
	return nil
end
function SH.SetRelicRule(spell, name)
	local db = ShamanRotationDB
	if type(db) ~= "table" then return end
	db.relics = db.relics or {}
	db.relics[spell] = name
end

-- equipe la relique `name` ; vrai si l'ordre a ete donne
function SH.RelicEquip(name, now)
	local info = SH.RELICS[name]
	if not info then return false end
	if SH.RelicEquippedId() == info[1] then return false end
	local bag, slot = SH.RelicFind(info[1])
	if not bag then return false end
	SH.Dbg("RELIQUE -> " .. name)
	UseContainerItem(bag, slot)
	SH.relic.at = now
	SH.relic.busyUntil = now + 1.6
	return true
end

-- appele par SH.TryCast avant chaque sort : en mode "spell", si la relique du sort n'est pas equipee, l'echange prend l'appui (wait) ; le sort part ensuite
function SH.RelicGate(spell, now)
	local CFG = SH.CFG
	if CFG.relicMode ~= "spell" then return false end
	local want = SH.RelicRule(spell)
	if not want then return false end
	local info = SH.RELICS[want]
	if SH.RelicEquippedId() == info[1] then return false end
	local inCombat = UnitAffectingCombat("player")
	-- en combat : espace de relicGap s entre deux echanges (chacun coute un GCD de 1,5 s)
	if inCombat and now - SH.relic.at < CFG.relicGap then return false end
	if SH.RelicEquip(want, now) then
		SH.Decide(now, "Relique : " .. want .. " pour " .. spell .. (inCombat and " (wait : le sort part apres le GCD d'echange)" or ""))
		return true
	end
	return false
end

-- hors combat (fin de combat, connexion) : relique principale, ou celle de Lightning Bolt en mode "spell"
function SH.RelicOpener()
	local CFG = SH.CFG
	if UnitAffectingCombat("player") or UnitIsDeadOrGhost("player") then return end
	local name = nil
	if CFG.relicMode == "main" then
		name = CFG.relicMain
	elseif CFG.relicMode == "spell" then
		name = SH.RelicRule("Lightning Bolt")
	end
	if name and SH.RELICS[name] then SH.RelicEquip(name, GetTime()) end
end

SH.EV["PLAYER_REGEN_ENABLED"] = function() SH.RelicOpener() end
SH.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
SH.EV["PLAYER_LOGIN"] = function() SH.RelicOpener() end
SH.frame:RegisterEvent("PLAYER_LOGIN")
