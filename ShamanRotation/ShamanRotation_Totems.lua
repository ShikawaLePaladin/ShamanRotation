---------------------------------------------------------------
-- ShamanRotation_Totems.lua : combos de totems (caster / melee / AoE / anti-peur / purification), suivi par minuteur
-- Durees et couts : Spell.dbc du serveur (voir DESIGN.md). Aucune API 1.12 ne dit si un totem est detruit : le suivi est un MINUTEUR
-- (remis a zero au changement de zone et a la mort) ; le bouton Totems repose ce qui manque.
-- Lua 5.0 strict.
---------------------------------------------------------------
local SH = ShamanRotation

-- nom -> { element, duree (s) }   (Spell.dbc : SpellDuration)
SH.TOTEM = {
	["Searing Totem"] = { "fire", 55 }, ["Magma Totem"] = { "fire", 20 }, ["Fire Nova Totem"] = { "fire", 5 }, ["Flametongue Totem"] = { "fire", 120 },
	["Mana Spring Totem"] = { "water", 60 }, ["Healing Stream Totem"] = { "water", 60 }, ["Poison Cleansing Totem"] = { "water", 120 },
	["Disease Cleansing Totem"] = { "water", 120 },
	["Tranquil Air Totem"] = { "air", 120 }, ["Windfury Totem"] = { "air", 90 }, ["Grace of Air Totem"] = { "air", 120 },
	["Strength of Earth Totem"] = { "earth", 120 }, ["Tremor Totem"] = { "earth", 120 }, ["Stoneskin Totem"] = { "earth", 120 },
}
SH.TOTEM_ORDER = { "fire", "air", "earth", "water" }

-- presets : element -> totem (texte de l'ami : caster = Mana Spring + Tranquil Air + Searing ; cac = Windfury + Flametongue + Strength of Earth + Mana Spring ;
-- AoE = Magma ou Fire Nova ; anti-peur = Tremor ; anti-poison / anti-maladie = totems de purification)
SH.PRESETS = {
	caster = { fire = "Searing Totem", water = "Mana Spring Totem", air = "Tranquil Air Totem" },
	melee = { fire = "Flametongue Totem", air = "Windfury Totem", earth = "Strength of Earth Totem", water = "Mana Spring Totem" },
	aoe = { fire = "Magma Totem", water = "Mana Spring Totem", air = "Tranquil Air Totem" },
	nova = { fire = "Fire Nova Totem", water = "Mana Spring Totem", air = "Tranquil Air Totem" },
	fear = { fire = "Searing Totem", water = "Mana Spring Totem", air = "Tranquil Air Totem", earth = "Tremor Totem" },
	poison = { fire = "Searing Totem", water = "Poison Cleansing Totem", air = "Tranquil Air Totem" },
	disease = { fire = "Searing Totem", water = "Disease Cleansing Totem", air = "Tranquil Air Totem" },
}
SH.PRESET_LIST = { "caster", "melee", "aoe", "nova", "fear", "poison", "disease", "off" }

SH.totems = {}          -- [element] = { name, at }
SH.totemTry = -10

function SH.TotemsReset() SH.totems = {} end

-- le totem `name` est-il (suppose) en place ? marge de 3 s avant la fin
function SH.TotemActive(name, now)
	local info = SH.TOTEM[name]
	if not info then return false end
	local t = SH.totems[info[1]]
	return t ~= nil and t.name == name and now < t.at + info[2] - 3
end

function SH.PresetTotem(el, aoe)
	local p = SH.PRESETS[SH.CFG.totemPreset]
	if not p then return nil end
	if el == "fire" and aoe and SH.CFG.totemPreset ~= "nova" then return "Magma Totem" end
	return p[el]
end

-- pose le totem : 1 GCD ; vrai si l'appui est consomme
function SH.PlaceTotem(name, now)
	if not SH.Known(name) then return false end
	if now - SH.totemTry < 0.5 then return true end -- laisse le jeu repondre
	if SH.CdInfo(name) > 0 or SH.Blocked(name) then return false end
	SH.totemTry = now
	SH.Dbg("TOTEM -> " .. name)
	SH.Cast(name)
	local info = SH.TOTEM[name]
	if info then
		-- pose supposee ; confirmee au prochain appui si le GCD a demarre (sinon le lancer a ete refuse : la marque est retiree)
		SH.totemPending = { el = info[1], name = name, at = now, prev = SH.totems[info[1]] }
		SH.totems[info[1]] = { name = name, at = now }
	end
	return true
end

function SH.TotemConfirm(now)
	local p = SH.totemPending
	if not p then return end
	if now - p.at < 0.15 then return end
	SH.totemPending = nil
	if now - p.at > 0.6 then return end -- trop tard pour juger (le GCD est peut-etre deja fini) : on garde la pose supposee
	-- le GCD du totem a-t-il demarre APRES notre appui ? (un GCD plus ancien, d'un autre sort, ne prouve rien)
	local idx = SH.GetSpellIdx(p.name)
	local start = 0
	if idx then
		local s = GetSpellCooldown(idx, "spell")
		start = s or 0
	end
	if start < p.at - 0.1 then
		SH.totems[p.el] = p.prev -- aucun GCD demarre : lancer refuse
		SH.totemTry = -10
	end
end

-- rotation : seul le totem de feu (Searing / Magma), pendant le combat
function SH.TotemFireStep(now, aoe)
	-- une pose vient d'etre tentee : on attend sa confirmation (~0,2 s) au lieu de lancer un autre sort dont le GCD la ferait croire reussie
	if SH.totemPending and now - SH.totemPending.at < 0.45 then return true end
	local want = SH.PresetTotem("fire", aoe)
	if not want or SH.TotemActive(want, now) then return false end
	if SH.PlaceTotem(want, now) then
		SH.Decide(now, "Totem : " .. want)
		return true
	end
	return false
end

-- bouton Totems : pose le premier totem MANQUANT du preset (feu, air, terre, eau), un par appui (1 GCD chacun)
function ShamanRotation_Totems()
	local now = GetTime()
	SH.TotemConfirm(now)
	if SH.CFG.totemPreset == "off" then
		SH.Print("Totems : preset coupe (/shamrot totems caster|melee|aoe|nova|fear|poison|disease).")
		return
	end
	local i, el, want
	for i = 1, table.getn(SH.TOTEM_ORDER) do
		el = SH.TOTEM_ORDER[i]
		want = SH.PresetTotem(el, SH.AoeOn())
		if want and not SH.TotemActive(want, now) then
			if SH.PlaceTotem(want, now) then return end
		end
	end
	SH.Print("Totems en place (preset " .. SH.CFG.totemPreset .. ").")
end

function SH.TotemStatus()
	local now = GetTime()
	local txt, i, el = "", 0, nil
	for i = 1, table.getn(SH.TOTEM_ORDER) do
		el = SH.TOTEM_ORDER[i]
		local want = SH.PresetTotem(el, SH.AoeOn())
		local t = SH.totems[el]
		local left = nil
		if t and SH.TOTEM[t.name] then left = t.at + SH.TOTEM[t.name][2] - now end
		txt = txt .. "  " .. el .. " : " .. (want or "-") .. ((t and left and left > 0) and (" (en place " .. string.format("%.0f", left) .. " s)") or (want and " (MANQUANT)" or "")) .. "\n"
	end
	return txt
end

-- ===================================================================
-- Tous les totems du combo d'un seul appui : sequence automatique (un GCD de 1,5 s chacun, ~6 s pour 4 totems)
-- ===================================================================
SH.totemSeq = nil

function ShamanRotation_TotemsAll()
	if SH.CFG.totemPreset == "off" then
		SH.Print("Totems : preset coupe (/shamrot totems caster|melee|aoe|nova|fear|poison|disease).")
		return
	end
	SH.totemSeq = { at = GetTime(), skipped = {} }
	SH.Print("Pose des totems du combo " .. SH.CFG.totemPreset .. " (un GCD chacun, automatique)...")
end

-- une etape : pose le premier totem manquant des que le GCD est libre ; vrai tant que la sequence continue
function SH.TotemSeqStep(now)
	local q = SH.totemSeq
	if not q then return false end
	if UnitIsDeadOrGhost("player") or now - q.at > 15 then
		SH.totemSeq = nil
		return false
	end
	SH.TotemConfirm(now)
	if SH.totemPending then return true end            -- on attend de savoir si la pose precedente a pris
	if now < SH.castUntil then return true end         -- incantation en cours
	local i, el, want
	for i = 1, table.getn(SH.TOTEM_ORDER) do
		el = SH.TOTEM_ORDER[i]
		want = SH.PresetTotem(el, SH.AoeOn())
		if want and not q.skipped[el] and not SH.TotemActive(want, now) then
			if not SH.Known(want) then
				q.skipped[el] = true                    -- totem non appris : on passe
				SH.Say(want .. " : non appris, ignore.")
			elseif SH.Blocked(want) then
				SH.Print("Pose des totems interrompue : pas assez de mana pour " .. want .. ".")
				SH.totemSeq = nil
				return false
			elseif SH.CdInfo(want) > 0 then
				return true                             -- GCD en cours : on attend
			else
				SH.PlaceTotem(want, now)
				return true
			end
		end
	end
	SH.totemSeq = nil
	SH.Print("Totems en place (combo " .. SH.CFG.totemPreset .. ").")
	return false
end

SH.totemSeqFrame = CreateFrame("Frame", "ShamanRotationTotemSeqFrame")
SH.totemSeqAcc = 0
SH.totemSeqFrame:SetScript("OnUpdate", function()
	if not SH.totemSeq then return end
	SH.totemSeqAcc = SH.totemSeqAcc + (arg1 or 0)
	if SH.totemSeqAcc < 0.05 then return end
	SH.totemSeqAcc = 0
	SH.TotemSeqStep(GetTime())
end)
