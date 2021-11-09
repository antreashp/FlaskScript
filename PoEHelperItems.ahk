#IfWinActive Path of Exile
#SingleInstance force
#NoEnv  
#Warn  
#Persistent 

;SendMode InputThenPlay

InterestedStatSets := []

; Configuration
SkipUniqueItemProcessing := true
WarnUnidentified := true
InventoryXY := {start: { x: 2600, y: 815 }, end: { x: 3380, y: 1100 }}

InterestedStatSets.Push({"item class": ["contracts", "maps"], "~monsters reflect" : 1})

InterestedStatSets.Push({"maximum life": 100 }) ; T1 life
InterestedStatSets.Push({"maximum energy shield": 120 })
InterestedStatSets.Push({"chaos resistance%": 35 })
InterestedStatSets.Push({"total resistances%": 80, "total maximum life": 60 })
InterestedStatSets.Push({"total elemental resistances%": 60, "total maximum life": 60, "total maximum mana": 60 })
InterestedStatSets.Push({"item class": "boots", "movement speed": 30 })
InterestedStatSets.Push({"increased spell damage": 100 })
InterestedStatSets.Push({"total attributes": 80 })
InterestedStatSets.Push({"critical strike multiplier%": 100, "critical strike chance%": 25 })
InterestedStatSets.Push({"fire damage over time multiplier%": 3, "adds fire damage": 10 })
InterestedStatSets.Push({"cold damage over time multiplier%": 3, "adds cold damage": 10 })
InterestedStatSets.Push({"lightning damage over time multiplier%": 3, "adds lightning damage": 10 })
InterestedStatSets.Push({"chaos damage over time multiplier%": 3, "adds chaos damage": 10 })
InterestedStatSets.Push({"socketed gems deal more elemental damage%": 15 })
InterestedStatSets.Push({"~level of all" : 1 })

InterestedStatSets.Push({"strength": 50, "item class": { 1: "rings", 2: "amulets" } })
InterestedStatSets.Push({"dexterity": 50, "item class": { 1: "rings", 2: "amulets"} })
InterestedStatSets.Push({"intelligence": 50, "item class": { 1: "rings", 2: "amulets"} })

; Configuration END

log(str) {
	OutputDebug, %str% 
}

isInsideInventory(x, y) {
	global InventoryXY
	isInside := (InventoryXY["start"]["x"] < x and x < InventoryXY["end"]["x"]) and (InventoryXY["start"]["y"] < y and y < InventoryXY["end"]["y"])
	;dmp := dump(InventoryXY)
	;OutputDebug , %x% `, %y% `, %isInside% `, %dmp%
	return isInside
}

getSockets(sockets) {
	res := []
	for i, set in StrSplit(Trim(sockets), " ") {
		set := Trim(set)
		if (StrLen(set) > 1) {
			res.Push(StrSplit(set, "-"))
		}
	}
	return res
}

lc(str) {
	StringLower str, str
	return str
}

jo(arr, sep := "") {
	if (arr.MaxIndex() == "") {
		return ""
	}

	s := ""
	for i, val in arr {
		s .= val . sep
	}

	if (StrLen(sep) == 0) {
		return s
	}
	return SubStr(s, 1, StrLen(s) - StrLen(sep))
}

ObjFullyClone(obj)
{
	nobj := obj.Clone()
	for k,v in nobj
		if IsObject(v)
			nobj[k] := A_ThisFunc.(v)
	return nobj
}

checkIfInterestingValue(val, comp) {
	if (isObject(comp)) {
		for i, c in comp {
			if (checkIfInterestingValue(val, c)) {
				return 1
			}
		}
		return 0
	}

	if comp is alpha
		return val == comp
	else if comp is number
		return val >= comp
	return 0
}

checkIfInterestingValueSet(set, values) {
	s := ""
	for statName, comp in set {
		if (SubStr(statName, 1, 1) == "~") {
			newSet := ObjFullyClone(set)
			newSet.Delete(statName)
			needle := SubStr(statName, 2)
			for key, val in values {
				if (inStr(key, needle)) {
					newSet[key] := set[statName]
				}
			}
			return checkIfInterestingValueSet(newSet, values)
		}

		value := values[statName]
		if (value != 0 and !value) {
			return 0
		}

		if (!checkIfInterestingValue(value, comp)) {
			return 0
		}
		
		s .= statName . ": " . value . "`n"
	}
	return s
}

checkIfInterestingItem(values, x ,y) {
	global InterestedStatSets
;	msgtext := dump(values)
;	MsgBox %msgtext%
	for i, set in InterestedStatSets {
		res := checkIfInterestingValueSet(set, values)
		if (res) {
			OutputDebug , Interesting because
			log(dump(set))
			SoundPlay, %A_WinDir%\Media\notify.wav
			ToolTip, Interesting Item Found`n`n%res%, %x%, %y%
			SetTimer,ToolTipClear,-2000
			; SoundPlay, *48
			return 1
		}
	}
}

getVal(v1, v2) {
	v1 := v1 * 1
	if (v2) {
		v1 += v2
		v1 /= 2
	}
	return v1
}

AggregatedStats := []
AggregatedStats["total resistances%"] := ["fire resistance%", "cold resistance%", "lightning resistance%", "chaos resistance%"]
AggregatedStats["total elemental resistances%"] := ["fire resistance", "cold resistance", "lightning resistance"]
AggregatedStats["total maximum life"] := ["maximum life", {"stat": "strength", "factor": 0.5}]
AggregatedStats["total maximum mana"] := ["maximum mana", {"stat": "intelligence", "factor": 0.5}]
AggregatedStats["total maximum energy shield%"] := ["maximum energy shield"]
AggregatedStats["total attributes"] := ["strength", "dexterity", "intelligence"]
AggregatedStats["total accuracy rating"] := ["accuracy rating", {"stat": "dexterity", "factor": 2}]
AggregatedStats["total melee physical damage%"] := ["increased global physical damage%", "melee physical damage%", {"stat": "strength", "factor": 0.2, "floor": 1}]
AggregatedStats["total evasion rating%"] := ["global defenses%", {"stat": "dexterity", "factor": 0.2, "floor": 1}]
AggregatedStats["total maximum energy shield%"] := ["maximum energy shield%", {"stat": "intelligence", "factor": 0.2, "floor": 1}]


ExpandableStats := []
ExpandableStats["all elemental resistances%"] := ["fire resistance%", "cold resistance%", "lightning resistance%"]
ExpandableStats["all attributes"] := ["strength", "dexterity", "intelligence"]

processItem(itemDesc) {
	global ExpandableStats
	global AggregatedStats
	global SkipUniqueItemProcessing
	global WarnUnidentified

	OutputDebug , Processing Item:`n%itemDesc%
	if (InStr(itemDesc, "Rarity: Currency")) {
		OutputDebug , Skipping Currency Item
		return
	}

	if (SkipUniqueItemProcessing and InStr(itemDesc, "Rarity: Unique")) {
		OutputDebug , Skipping Unique Item
		return
	}

	if (inStr(itemDesc, "Unidentified")) {
		if (WarnUnidentified) {
			SoundPlay, %A_WinDir%\Media\notify.wav
			ToolTip, Undefined Item
			SetTimer,ToolTipClear,-1000
		}
		return
	}

	values := []
	Loop, parse, itemDesc, `n, `r
	{
		stat := A_LoopField
		g1 := 0
		g2 := 0
		g3 := 0
		g4 := 0
		g5 := 0
		if (inStr(stat, "Elemental Damage:") or inStr(stat, "--------") or inStr(stat, "Requirements:") or StrLen(Trim(stat)) == 0) {
			OutputDebug , Ignoring %stat%
		}
		else if (RegExMatch(stat, "([\w\s]+):\s([+-]?\d+\.?\d*)(%)?(?:-([+-]?\d+\.?\d*)%)?\s*", g)) {
			OutputDebug , Found %g1% %g3% = %g2% - %g4%
			g1 := lc(g1) . g3
			if (!values[g1]) {
				values[g1] := 0
			}
			values[g1] += getVal(g2, g4)
		}
		else if (inStr(stat, "Sockets: ")) {
			sockets := Trim(SubStr(stat, StrLen("Sockets: ")))
			OutputDebug , Found Sockets %sockets%
			values["sockets"] := getSockets(sockets)
		}
		else if (RegExMatch(stat, "([\w\s]+):\s([+-]?\d+\.?\d*)(%)?\s*", g)) {
			OutputDebug , Found %g1% %g2% = %g3%
			g1 := lc(g1) . g2
			if (!values[g1]) {
				values[g1] := 0
			}
			values[g1] += g3 * 1
		}
		else if (RegExMatch(stat, "([\w\s]+):\s([\w\s]+)\s*", g)) {
			OutputDebug , Found %g1% = %g2%
			g1 := lc(g1)
			g2 := lc(g2)
			values[g1] := g2
		}
		else if (RegExMatch(stat, "([^\d+-]*)([+-]?\d+\.?\d*)(%)? (?:to )?([+-]?\d+\.?\d*)?%?([\w\s]+)", g)) {
			g1 := lc(g1)
			g5 := lc(g5)
			keys := []
			(g1) ? keys.Push(Trim(g1))
			(g5) ? keys.Push(Trim(g5))
			key := jo(keys, " ") . (g3 ? "`%" : "")
			if (!values[key]) {
				values[key] := 0
			}
			values[key] += getVal(g2, g4)
			OutputDebug , Found %g1% %g5% = %g2% %g4%%g3% => %key%
		}
		else {
			OutputDebug , Treating %stat% as flag
			values[lc(stat)] := 1
		}
	}

	if (values.Count() == 0) {
		OutputDebug , Unparsable
		return
	}

	for expStatName, expandsTo in ExpandableStats {
		value := values[expStatName]
		if (!value) {
			continue
		}

		for i, statName in expandsTo {
			; OutputDebug , Add %value% to %statName%
			values[statName] += value
			; val := values[statName]
			; OutputDebug , Expand %expStatName% -> %statName% `= %val%
		}
	}

	for statName, aggrFrom in AggregatedStats {
		; OutputDebug , Aggr %statName%
		values[statName] := 0
		for i, fromStatName in aggrFrom {
			factor := 1
			floorIt := 0
			if (IsObject(fromStatName)) {
				factor := (fromStatName["factor"] or 1)
				floorIt := (fromStatName["floor"] or 0)
				fromStatName := fromStatName["stat"]
			}
				
			val := (values[fromStatName] ? values[fromStatName] : 0) * factor
			if (floorIt) {
				val := Floor(val)
			}
			values[statName] += (val ? val : 0)
		}
	}

	MouseGetPos, x, y
	checkIfInterestingItem(values, x, y + 50)
}

dump(o, inVal := false) {
	s := ""
	if (!IsObject(o)) {
		return o
	}

	for key, value in o {
		s .= key
		if (IsObject(value)) {
			s .= ": { `n"
			s .= dump(value, true)
			s .= "},`n"
		}
		else {
			s .= "="
			s .= value
			s .= ", " . (inVal ? "`n" : "")
		}
	}
	return s
}

~^LButton::
	OutputDebug, User Check
	Clipboard := ""
	Send ^c
	ClipWait , 0.1
	processItem(Clipboard)
	return

; clear tooltip
ToolTipClear:
	ToolTip
	Return
