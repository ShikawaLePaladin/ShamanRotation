---------------------------------------------------------------
-- ShamanRotation_Cmd.lua : commandes /shamrot (et /shaman)
-- Lua 5.0 strict.
---------------------------------------------------------------
local SH = ShamanRotation

local function help()
	SH.Print("v" .. SH.VERSION .. " - /shamrot aoe [auto|on|off] | burst | totems [all|caster|melee|aoe|nova|fear|poison|disease|off] | immune fire|nature|frost [clear]")
	SH.Print("   menu | hud | relic | known <sort> | status | set <cle> <valeur> | debug | trace | reset")
end

local function status()
	local CFG = SH.CFG
	local now = GetTime()
	SH.Print("AoE : " .. CFG.aoeMode .. (SH.autoN and (" (" .. SH.autoN .. " ennemi(s) a " .. CFG.aoeRadius .. " m de la cible)") or " (comptage impossible : UnitXP / plaques absents)")
		.. " -> " .. (SH.AoeOn() and "AOE" or "MONO"))
	SH.Print("Flame Shock : reste " .. string.format("%.1f", SH.FsRemain()) .. " s sur la cible ; mana " .. string.format("%.0f", SH.ManaPct() * 100) .. " %")
	SH.Print("Totems (preset " .. CFG.totemPreset .. ") :")
	local txt = SH.TotemStatus()
	local line
	for line in string.gfind(txt, "[^\n]+") do SH.Print(line) end
	SH.Print("Extensions : Nampower " .. (type(IsSpellInRange) == "function" and "oui" or "non") .. ", UnitXP " .. ((type(UnitXP) == "function") and "oui" or "non")
		.. ", SuperWoW " .. ((type(SUPERWOW_VERSION) ~= "nil") and "oui" or "non"))
end

function SH.Slash(msg)
	msg = msg or ""
	local _, _, cmd, rest = string.find(msg, "^%s*(%S*)%s*(.-)%s*$")
	cmd = string.lower(cmd or "")
	rest = rest or ""
	if cmd == "" or cmd == "help" then
		help()
	elseif cmd == "relic" or cmd == "reliques" then
		local _, _, sub, val = string.find(rest, "^(%S*)%s*(.-)$")
		if sub == "mode" and (val == "off" or val == "main" or val == "spell") then
			SH.SetSetting("relicMode", val)
			SH.Print("Reliques : mode " .. val .. " (wait uniquement : un echange en combat coute un GCD de 1,5 s)")
		else
			SH.Print("Reliques : mode " .. SH.CFG.relicMode .. ", relique principale : " .. SH.CFG.relicMain .. ", equipee : " .. tostring(SH.RelicEquippedId() or "aucune"))
			local i
			for i = 1, table.getn(SH.RELIC_SPELLS) do
				SH.Print("   " .. SH.RELIC_SPELLS[i] .. " : " .. (SH.RelicRule(SH.RELIC_SPELLS[i]) or "aucune"))
			end
			SH.Print("   /shamrot relic mode off|main|spell ; les reliques par sort se reglent dans le menu (onglet Reliques)")
		end
	elseif cmd == "known" or cmd == "sort" then
		-- verifie si un sort est dans le livre de sorts de CE personnage (rang le plus haut, recharge)
		if rest == "" then
			SH.Print("/shamrot known <nom exact du sort>   ex. /shamrot known Call of the Elements")
		elseif SH.Known(rest) then
			local rem = SH.CdInfo(rest)
			SH.Print(rest .. " : dans ton livre de sorts" .. (rem > 0 and (" (recharge " .. string.format("%.1f", rem) .. " s)") or " (pret)"))
		else
			SH.Print(rest .. " : ABSENT de ton livre de sorts (ni appris ni sous ce nom exact)")
		end
	elseif cmd == "menu" or cmd == "config" then
		SH.OpenMenu()
	elseif cmd == "hud" then
		SH.SetSetting("hud", not SH.CFG.hud)
		SH.HudRefreshConfig()
		SH.Print("indicateur : " .. (SH.CFG.hud and "affiche" or "cache"))
	elseif cmd == "status" then
		status()
	elseif cmd == "aoe" then
		if rest == "auto" or rest == "on" or rest == "off" then
			SH.SetSetting("aoeMode", rest)
			SH.autoAoe = false
			SH.Print("Mode AoE : " .. rest)
		else
			ShamanRotation_AoeToggle()
		end
	elseif cmd == "burst" then
		ShamanRotation_Burst()
	elseif cmd == "totems" then
		if rest == "all" or rest == "tous" then
			ShamanRotation_TotemsAll()
		elseif rest ~= "" then
			local ok, i = false, 0
			for i = 1, table.getn(SH.PRESET_LIST) do
				if SH.PRESET_LIST[i] == rest then ok = true end
			end
			if ok then
				SH.SetSetting("totemPreset", rest)
				SH.Print("Preset de totems : " .. rest)
			else
				SH.Print("Preset inconnu : " .. rest)
			end
		else
			ShamanRotation_Totems()
		end
	elseif cmd == "immune" then
		local _, _, school, what = string.find(rest, "^(%S+)%s*(.-)$")
		local name = UnitName("target")
		if (school == "fire" or school == "nature" or school == "frost") and name then
			local on = (what ~= "clear")
			SH.SetImmune(school, name, on)
			SH.Print(name .. " : immunite " .. school .. (on and " ENREGISTREE" or " retiree"))
		else
			SH.Print("Cible un mob puis : /shamrot immune fire|nature|frost [clear]")
		end
	elseif cmd == "set" then
		local _, _, key, val = string.find(rest, "^(%S+)%s+(%S+)$")
		if key and SH.DEFAULTS[key] ~= nil then
			local d = SH.DEFAULTS[key]
			local v = val
			if type(d) == "boolean" then v = (val == "1" or val == "on" or val == "true")
			elseif type(d) == "number" then v = tonumber(val) end
			if v ~= nil then
				SH.SetSetting(key, v)
				SH.Print(key .. " = " .. tostring(v))
			else
				SH.Print("valeur invalide : " .. val)
			end
		else
			SH.Print("cle inconnue. Cles : aoeMode autoAoeMin fsRefresh useFs useCl useEq useMb interrupt esFill manaCl totemPreset totemsInCombat burstEm burstBf burstTrinkets ...")
		end
	elseif cmd == "debug" then
		SH.SetSetting("debug", not SH.CFG.debug)
		SH.Print("debug : " .. tostring(SH.CFG.debug))
	elseif cmd == "trace" then
		local t = ShamanRotationDB and ShamanRotationDB.trace
		if type(t) ~= "table" then
			SH.Print("trace vide")
		else
			local n, i = table.getn(t), 0
			for i = math.max(1, n - 12), n do SH.Print(t[i]) end
		end
	elseif cmd == "reset" then
		local k, v
		for k, v in pairs(SH.DEFAULTS) do SH.SetSetting(k, v) end
		SH.Print("Reglages remis aux valeurs par defaut.")
	else
		help()
	end
end

SLASH_SHAMANROT1 = "/shamrot"
SLASH_SHAMANROT2 = "/shaman"
SlashCmdList["SHAMANROT"] = function(msg) SH.Slash(msg) end

local loaded = CreateFrame("Frame")
loaded:RegisterEvent("PLAYER_LOGIN")
loaded:SetScript("OnEvent", function()
	local _, class = UnitClass("player")
	if class ~= "SHAMAN" then
		SH.Print("charge, mais ce personnage n'est pas un Chaman : la rotation ne fait rien d'utile.")
	else
		SH.Print("v" .. SH.VERSION .. " chargee. /shamrot pour l'aide ; lie une touche dans Controles > Shaman Rotation.")
	end
end)
