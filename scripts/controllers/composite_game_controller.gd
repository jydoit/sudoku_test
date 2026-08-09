extends RefCounted

const CompositeLevelScript = preload("res://scripts/composite_level.gd")
const CompositePlacementEngineScript = preload("res://scripts/rules/composite_placement_engine.gd")

var mode := false
var phase := "crown"
var data: Dictionary = {}
var placements: Dictionary = {}
var placement_history: Array = []
var tray_slots: Array = []
var deadlocked := false
var final_layout: Dictionary = {}
var tutorial_seen := false
var intro_running := false
var intro_marks_seen := false
var resume_state: Dictionary = {}


func is_assembly_phase() -> bool:
	return mode and phase == "assembly"


func allowed_origins() -> Dictionary:
	return CompositePlacementEngineScript.allowed_origins(data, placements)


func compatible_layouts() -> Array:
	return CompositePlacementEngineScript.compatible_layouts(data, placements)


func compatible_layout() -> Dictionary:
	return CompositePlacementEngineScript.compatible_layout(data, placements)


func direct_find_target() -> Dictionary:
	return CompositePlacementEngineScript.direct_find_target(data, placements)


func hint_target() -> Dictionary:
	return CompositePlacementEngineScript.hint_target(data, placements)


func place(piece_id: int, origin: Array) -> Dictionary:
	if not is_assembly_phase():
		return {"valid": false}
	var evaluation := CompositePlacementEngineScript.evaluate_candidate(data, placements, piece_id, origin)
	if not bool(evaluation.get("valid", false)):
		return evaluation
	placements = evaluation.get("placements", {})
	remove_piece_from_tray(piece_id)
	tray_slots = CompositeLevelScript.sanitize_tray_slots(data, placements, tray_slots)
	placement_history.erase(piece_id)
	placement_history.append(piece_id)
	deadlocked = bool(evaluation.get("deadlocked", false))
	return evaluation


func return_piece(piece_id: int, preferred_slot_index: int = -1) -> int:
	if not is_assembly_phase():
		return -1
	placements.erase(str(piece_id))
	var returned_slot := assign_piece_to_tray(piece_id, preferred_slot_index)
	placement_history.erase(piece_id)
	deadlocked = false
	return returned_slot


func clear_placements() -> bool:
	if placements.is_empty():
		return false
	placements.clear()
	placement_history.clear()
	deadlocked = false
	tray_slots = CompositeLevelScript.sanitize_tray_slots(data, placements, tray_slots)
	return true


func evaluate_direct_find(target: Dictionary) -> Dictionary:
	if target.is_empty():
		return {"valid": false}
	var layout: Dictionary = target.get("layout", {})
	var layout_placements: Dictionary = layout.get("placements", {})
	var candidate := placements.duplicate(true)
	for piece_id in target.get("pieceIds", []):
		var key := str(int(piece_id))
		if not layout_placements.has(key):
			return {"valid": false}
		candidate[key] = (layout_placements[key] as Array).duplicate()
	var evaluation := CompositeLevelScript.evaluate_placement_state(data, candidate, true)
	if not bool(evaluation.get("valid", false)):
		return evaluation
	evaluation["placements"] = candidate
	return evaluation


func commit_direct_find(target: Dictionary, evaluation: Dictionary) -> void:
	placements = evaluation.get("placements", placements)
	for piece_id in target.get("pieceIds", []):
		placement_history.erase(int(piece_id))
		placement_history.append(int(piece_id))
	tray_slots = CompositeLevelScript.sanitize_tray_slots(data, placements, tray_slots)
	deadlocked = false


func revive_last_placement() -> Dictionary:
	if not is_assembly_phase() or not deadlocked or placement_history.is_empty():
		return {}
	var piece_id := int(placement_history.pop_back())
	placements.erase(str(piece_id))
	var slot := assign_piece_to_tray(piece_id)
	deadlocked = false
	return {"pieceId": piece_id, "slot": slot}


func remove_piece_from_tray(piece_id: int) -> void:
	for index in range(tray_slots.size()):
		if int(tray_slots[index]) == piece_id:
			tray_slots[index] = -1
			return


func assign_piece_to_tray(piece_id: int, preferred_slot_index: int = -1) -> int:
	remove_piece_from_tray(piece_id)
	var slot_index := preferred_slot_index
	if slot_index < 0 or slot_index >= tray_slots.size() or int(tray_slots[slot_index]) >= 0:
		slot_index = tray_slots.find(-1)
	if slot_index >= 0:
		tray_slots[slot_index] = piece_id
	tray_slots = CompositeLevelScript.sanitize_tray_slots(data, placements, tray_slots)
	return tray_slots.find(piece_id)


func save_state(current_level: Dictionary, active_schedule: Dictionary) -> Dictionary:
	if not mode or current_level.is_empty():
		return {}
	var result := {
		"levelId": int(current_level.get("levelId", -1)),
		"phase": phase,
		"seed": int(data.get("seed", resume_state.get("seed", 0))),
		"dataVersion": int(data.get("version", resume_state.get("dataVersion", 0))),
		"placements": placements.duplicate(true),
		"placementHistory": placement_history.duplicate(),
		"traySlots": tray_slots.duplicate(),
		"deadlocked": deadlocked
	}
	if not final_layout.is_empty():
		result["layoutSignature"] = str(final_layout.get("signature", ""))
		result["finalRegions"] = final_layout.get("regions", []).duplicate(true)
		result["finalSolution"] = final_layout.get("solution", []).duplicate(true)
	elif phase == "crown":
		result["layoutSignature"] = str(active_schedule.get("assemblyLayoutSignature", ""))
		result["finalRegions"] = current_level.get("regions", []).duplicate(true)
		result["finalSolution"] = current_level.get("solution", []).duplicate(true)
	return result
