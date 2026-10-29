# ShamanRotation : conception (2026-10-29)

Sources : Spell.dbc + spell_template du serveur (SQL lecture seule), logs Chronicle d'OctoWoW (real_shares.json, octo_top_builds.json), texte de l'ami (a verifier).

## Faits PROUVES (serveur)
* Flame Shock r6 (29228) : 410 mana, GCD 1,5 s, DoT 15 s, categorie 19 recharge 6 s.
* Earth Shock r7 (10414) : 450 mana, GCD 1,5 s, categorie 19 recharge 6 s, interrompt 2 s.  Frost Shock r4 (10473) : 430 mana, categorie 19, 6 s.
  => les 3 chocs PARTAGENT une recharge de 6 s ET ont un GCD : on ne peut pas "intercaler un Earth Shock entre les GCD" (contredit le texte de l'ami).
* Chain Lightning r4 (10605) : 605 mana, incantation 2,5 s, recharge 6 s (categorie 85). Lightning Bolt r9 33457 : 210 mana, 3,0 s (r10 non liste dans la requete).
* Earthquake r3 (48308) : 440 mana, incantation 2,5 s, recharge 16 s (categorie 1173), effet de zone (zone persistante 51290/51291).
* Molten Blast r6 (36921) : 210 mana, incantation 2,0 s, pas de recharge. Rekindled Flame 46109 : 40 mana, instantane (declencheur interne).
* Elemental Mastery 16166 : recharge 180 s, +% degats Feu/Givre/Nature et -% cout. Blood Fury racial 23234.
* Elemental Focus (talent) 45541 -> Clearcasting 45542 : apres un critique Feu/Givre/Nature, sorts moins chers.
* Totems (duree, mana) : Searing r6 55 s/170 ; Magma r4 20 s/650 ; Fire Nova r5 5 s/520 ; Flametongue r4 120 s/275 ; Mana Spring r4 60 s/100 ;
  Tranquil Air 120 s ; Windfury r3 90 s/250 ; Strength of Earth r5 120 s/275 ; Grace of Air r3 120 s/310 ; Tremor 120 s/60 ; Poison/Disease Cleansing 120 s ;
  Grounding 45 s ; Healing Stream r5 60 s/80 ; Stoneskin r6 120 s/210 ; Totemic Recall 45513 (rend 24 % de la mana).  Tous : GCD 1,5 s.

## Faits REELS (logs Chronicle, meilleurs Elementaires, sur tous les boss)
Part des degats : Lightning Bolt 54,6 % (15,2 lancers/min) ; Chain Lightning 23,7 % (6,9/min) ; Earthquake 6,0 % (+2,4 % Aftershock, 2,3/min) ;
Earth Shock 5,0 % (2,25/min) ; Flame Shock 4,1 % (5,6/min) ; Molten Blast 1,5 % (0,75/min) ; Rekindled Flame 0,7 % ; Ancient Accord 0,8 %.
=> Flame Shock ~ toutes les 10,7 s (DoT 15 s : rafraichi vers 4 s restantes), Chain Lightning presque a chaque recharge (6 s), Earth Shock rare.

## Decisions
* Rotation "suivre les meilleurs" (choix de l'utilisateur) : Flame Shock entretenu, Chain Lightning a chaque retour, Earthquake en AoE, Lightning Bolt de remplissage ;
  Earth Shock = interruption (et repli si Flame Shock immunise), PAS de remplissage par defaut.
* Immunites : apprises par message "X is immune" (sauvegarde par nom de mob) + commande manuelle. Aucune table inventee.
* Totems : suivi par minuteur (aucune API 1.12 pour savoir si un totem est detruit) ; combos caster / melee / AoE / anti-peur / purification.
* Burst : Elemental Mastery + Blood Fury (+ objets a utiliser si l'utilisateur les coche) ; bijoux desactives par defaut (texte de l'ami : pas assez de toucher).
* Etape 3 (plus tard) : echange de reliques "wait" uniquement (GCD d'echange 1,5 s en combat, prouve cote serveur pour les armes/reliques).
* Etape 2 (plus tard) : menu complet a onglets taille fixe + defilement, HUD GCD / recharges.

## Ajouts 2026-10-29 (etape 2 + 3)
* Talents Elementaire du serveur (Talent.dbc, 17 talents) : Convection, Concussion, Earth's Grasp, Elemental Warding, Elemental Devastation, Elemental Focus, Reverberation,
  Call of Thunder, Improved Molten Blast, Improved Fire Totems, Call of Earth, Call of Flame, Storm Reach, Elemental Mastery, Elemental Fury, Lightning Mastery, Earthquake.
  Les 8 meilleurs builds (logs) prennent tous Earthquake ; 6 sur 8 prennent Improved Molten Blast 2/2 ; Tahua (37 pts) = le meme build que les meilleurs, sans Elemental Warding.
  Sans le talent Earthquake le sort n'est pas dans le livre : l'addon le saute tout seul (SH.Known).
* Reliques (item_template + Spell.dbc) : Totem of the Storm 23199 (+33 degats Chain Lightning / Lightning Bolt) ; Totem of Crackling Thunder 61292 (Lightning Bolt 10 % : +8 % vitesse d'attaque ET
  d'incantation 8 s, sort 45849/45850) ; Totem of Static Charge 55370 ; Totem of Rage 22395 (chocs) ; Totem of the Endless Flicker 51803 (Flame Shock +3 s) ; Totem of Broken Earth 55114 ;
  Totem of Distant Tremors 33090 (Aftershock +67 %, +2 s) ; Totem of Eruption 58241 (Molten Blast). Echange en combat = GCD 1,5 s (prouve) -> mode wait uniquement.
* Procs de l'ami : Totem of Crackling Thunder "8 % vitesse d'attaque sur 8 s" = VERIFIE (et aussi vitesse d'incantation). Spellwoven Nobility Drape 55056 = degats/soins des sorts (spell 9416),
  PAS de proc mana dans item_template : "+150 mana sur 6 s" NON VERIFIE. Set "T0.5 4 pieces : proc +95 sorts 10 s" NON TROUVE : sets lus = The Five Thunders 519 (6 pieces : degats des sorts)
  et Earthfury Garb 666 (3 : Searing Totem +15 s ; 5 : Earth Shield ; 8 : Earthquake +2 s et Aftershock +25 %). Le proc de crit "deux sorts gratuits" = Elemental Focus (Clearcasting 45542).
* Tahua : equipement = Five Thunders (6 pieces) + Earthfury Epaulets ; relique equipee dans le dernier releve : Totem of Crackling Thunder (61292).

## Totems : GCD par element (verifie 2026-10-29, spell_template.StartRecoveryCategory)
* Feu (Searing, Magma, Flametongue) = categorie 105 ; Terre (Strength of Earth, Tremor, Stoneskin) = 106 ; Eau (Mana Spring, Healing Stream, Cleansing) = 107 ; Air (Tranquil Air, Grace of Air) = 108 ;
  les sorts normaux (Lightning Bolt, chocs, Chain Lightning, Earthquake...) = 133. Exceptions en 133 : Windfury Totem rang 3 (27621) et Fire Nova Totem (11315).
* Consequence : les 4 totems d'un combo partent dans la MEME image (un par element) ; le totem de feu ne prend pas le GCD de la rotation. Ma premiere analyse (duree du GCD seule) etait fausse ;
  corrigee grace a l'addon CallOfElements de shaga (octowow.st/git/shaga/CallOfElements, GPL-3.0, commande /coe throwset) et verifiee dans la base.

## Boucliers elementaires (verifie 2026-10-29)
* Water Shield r5 (51536) : 0 mana, 10 min, 3 charges, GCD normal (133). Chaque attaque qui TOUCHE le chaman (1 fois / 3 s) : +130 mana et une charge. Pas de regeneration passive (l'effet 2, mod regen, vaut 0).
* Earth Shield r3 (51526) : 300 mana, 10 min, 3 charges. Chaque attaque qui touche : +150 PV ; +30 % de chances de ne pas etre interrompu par les degats. Un seul bouclier elementaire a la fois.
* Consequence : sans etre touche, aucun des deux ne rapporte quoi que ce soit ; Water coute 0 mana, Earth 300. Water = defaut ; Earth utile quand on prend des coups EN lancant (PvP, adds).

## Totems trop loin (2026-10-29)
* Rayon des auras de buff = 30 m (Spell.dbc, creatures de totem : Mana Spring 10494, Healing Stream 10461, Strength of Earth 25362, Grace of Air 25360, Tranquil Air 25909, Stoneskin 10405, Flametongue 16388).
  Windfury, Tremor, purification, Searing, Magma : rayon non verifie, non surveilles.
* Methode (aucune API 1.12 pour la position d'un totem ; CallOfElements de shaga ne mesure pas la distance, il suit des minuteurs) : le totem apparait sur les plaques de nom a moins de 8 m juste apres la pose ;
  on retient son GUID, UnitXP("distanceBetween","player",guid) donne la distance, UnitExists / UnitIsDead disent s'il est detruit. Demande UnitXP + SuperWoW + plaques de nom amicales.

## Chain Lightning et la mana (2026-10-29)
* Serveur : Chain Lightning r4 = 605 mana, 2,5 s d'incantation, recharge 6 s, 3 cibles, -30 % a chaque saut ; Lightning Bolt r9 = 210 mana, 3,0 s. Talents Elementaire : Lightning Mastery 5/5 = -1,0 s d'incantation sur les deux
  (LB 2,0 s, CL 1,5 s) ; Convection 5/5 = -10 % de cout.
* Logs (meilleur parse, MC / Majordomo, plusieurs cibles) : moyenne par coup Lightning Bolt 1427, Chain Lightning 1221 (coups de saut compris). Avec les couts du serveur et -10 % (Convection) : LB ~ 7,5 degats / mana ;
  CL ~ 2,2 par coup, donc ~ 2,2 sur UNE cible et ~ 6,7 sur 3 cibles. Une seule cible : CL rapporte ~ 3 fois moins par mana (APPROXIMATION : un seul parse, plusieurs cibles) ; a 3 cibles : a egalite avec LB et beaucoup plus de DPS.
* Decision : clMode auto (defaut) = Chain Lightning seulement a 2+ ennemis proches de la cible, sous Clearcasting, sous Elemental Mastery, ou tant que la mana > clMonoMana (60 %, a ajuster) ; "on" = a chaque recharge ; "off" = jamais.
  Le seuil de 60 % est un REGLAGE, pas une valeur mesuree.
