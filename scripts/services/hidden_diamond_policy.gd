extends RefCounted

const DIAMONDS_PER_EVENT := 1
const INTRO_SECONDS := 1.25
const PERFORMANCE_FACTOR := 0.7
const INITIAL_RATIO := 0.9
const MIN_RATIO := 0.65
const MAX_RATIO := 1.35
const MAX_TIME_RATIO := 2.0
const TIME_BASELINE_VERSION := 2
const MIN_TIME_LIMIT_SECONDS := 30
const TIME_LIMIT_SECONDS_PER_LION := 6
const TARGET_SUCCESS_RATE := 0.5
const OUTCOME_WINDOW := 12


static func normalize(raw: Dictionary) -> Dictionary:
	var result := {"seed": int(raw.get("seed", randi())), "modes": {}, "bests": {}, "outcomes": {"time": [], "moves": []}, "pending": {}, "timeBaselineVersion": TIME_BASELINE_VERSION}
	for mode in ["normal", "composite"]:
		var source: Dictionary = _dict(_dict(raw.get("modes")).get(mode))
		result["modes"][mode] = {
			"checked": maxi(0, int(source.get("checked", 0))),
			"next": maxi(0, int(source.get("next", 0))),
			"earlyOffers": clampi(int(source.get("earlyOffers", 0)), 0, 2),
			"lastKind": str(source.get("lastKind", ""))
		}
	for key in _dict(raw.get("bests")):
		var sample := _dict(raw["bests"][key])
		var seconds := float(sample.get("seconds", 0.0))
		var size := int(str(key).get_slice(":", 1))
		# Version 1 mixed legacy/assisted records into an irreversible minimum.
		# Rebuild only time baselines; keep steps, scheduling and the reward ledger.
		if int(raw.get("timeBaselineVersion", 0)) < TIME_BASELINE_VERSION or not valid_time_sample(size, seconds):
			seconds = 0.0
		result["bests"][str(key)] = {"seconds": seconds, "moves": maxi(0, int(sample.get("moves", 0)))}
	for kind in ["time", "moves"]:
		var samples = _dict(raw.get("outcomes")).get(kind, [])
		if samples is Array:
			for value in samples.slice(maxi(0, samples.size() - OUTCOME_WINDOW)):
				result["outcomes"][kind].append(bool(value))
	result["pending"] = _dict(raw.get("pending")).duplicate(true)
	return result


static func event_id(mode: String, ordinal: int) -> String:
	return ("composite_round_%d" if mode == "composite" else "normal_level_%d") % ordinal


static func success_rate(progress: Dictionary, kind: String) -> float:
	var samples: Array = progress["outcomes"][kind]
	var wins := 0
	for won in samples:
		wins += int(bool(won))
	# Symmetric priors prevent one result from causing an extreme adjustment.
	return float(wins + 2) / float(samples.size() + 4)


static func dynamic_ratio(progress: Dictionary, kind: String) -> float:
	return clampf(INITIAL_RATIO * TARGET_SUCCESS_RATE / success_rate(progress, kind), MIN_RATIO, MAX_TIME_RATIO if kind == "time" else MAX_RATIO)


static func valid_time_sample(size: int, seconds: float) -> bool:
	return size >= 5 and is_finite(seconds) and seconds >= maxf(10.0, float(size * 2))


static func minimum_time_limit(size: int) -> int:
	return maxi(MIN_TIME_LIMIT_SECONDS, size * TIME_LIMIT_SECONDS_PER_LION)


static func consider(progress: Dictionary, context: Dictionary, offered: Array) -> Dictionary:
	var mode := str(context["mode"])
	var ordinal := int(context["ordinal"])
	var state: Dictionary = progress["modes"][mode]
	if ordinal <= int(state["checked"]):
		return {}
	state["checked"] = ordinal
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%s:%s" % [progress["seed"], mode, ordinal])
	if int(state["next"]) == 0:
		state["next"] = rng.randi_range(12, 18) if mode == "normal" else rng.randi_range(7, 12)
	if ordinal < int(state["next"]) or not bool(context.get("untouched", false)) or offered.has(event_id(mode, ordinal)):
		return {}
	if mode == "normal" and ordinal <= 30 and int(state["earlyOffers"]) >= 2:
		return {}
	var kind := "time" if rng.randf() < 0.5 else "moves"
	if str(state["lastKind"]) != "":
		kind = "moves" if state["lastKind"] == "time" else "time"
	state["lastKind"] = kind
	if mode == "normal" and ordinal <= 30:
		state["earlyOffers"] = int(state["earlyOffers"]) + 1
	var size := int(context["size"])
	var found := int(context.get("found", 0))
	var best: Dictionary = progress["bests"].get("%s:%d" % [mode, size], {})
	var baseline := float(best.get("seconds" if kind == "time" else "moves", 0.0))
	if kind == "time" and not valid_time_sample(size, baseline):
		baseline = 0.0
	if baseline <= 0.0:
		baseline = float(size * size * 3) if kind == "time" else float(size * 3)
	var ratio := dynamic_ratio(progress, kind)
	var floor_value := minimum_time_limit(size) if kind == "time" else maxi(1, size - found)
	return {
		"id": event_id(mode, ordinal), "mode": mode, "ordinal": ordinal,
		"kind": kind, "target": size, "reward": DIAMONDS_PER_EVENT,
		"limit": maxi(floor_value, ceili(baseline * PERFORMANCE_FACTOR * ratio)),
		"baseline": baseline, "ratio": ratio
	}


static func record_outcome(progress: Dictionary, event: Dictionary, won: bool) -> void:
	var kind := str(event.get("kind", ""))
	var mode := str(event.get("mode", ""))
	if not kind in ["time", "moves"] or not mode in ["normal", "composite"]:
		return
	var samples: Array = progress["outcomes"][kind]
	samples.append(won)
	while samples.size() > OUTCOME_WINDOW:
		samples.pop_front()
	var ordinal := int(event["ordinal"])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:gap:%s" % [progress["seed"], event["id"]])
	var base_gap := 10 if mode == "composite" or ordinal < 30 else 20
	var variation := 2 if base_gap == 10 else 4
	var rate_adjustment := roundi((success_rate(progress, kind) - TARGET_SUCCESS_RATE) * 6.0)
	var gap := maxi(6, base_gap + rng.randi_range(-variation, variation) + rate_adjustment)
	var state: Dictionary = progress["modes"][mode]
	state["next"] = ordinal + gap
	if mode == "normal" and ordinal < 30:
		state["next"] = mini(30, ordinal + gap) if int(state["earlyOffers"]) < 2 else maxi(31, ordinal + gap)


static func record_best(progress: Dictionary, mode: String, size: int, seconds: float, moves: int) -> void:
	var key := "%s:%d" % [mode, size]
	var best: Dictionary = progress["bests"].get(key, {"seconds": 0.0, "moves": 0})
	if valid_time_sample(size, seconds):
		best["seconds"] = seconds if float(best["seconds"]) <= 0.0 else minf(seconds, float(best["seconds"]))
	if moves > 0:
		best["moves"] = moves if int(best["moves"]) <= 0 else mini(moves, int(best["moves"]))
	progress["bests"][key] = best


static func import_legacy_times(progress: Dictionary, runs: Array) -> void:
	# Old moves omitted double taps/drags; old composite times included assembly.
	for run in runs:
		if run is Dictionary and bool(run.get("completed", false)) and int(run.get("size", 0)) >= 5:
			if str(run.get("mode", "")) == "manual" or int(run.get("hints", 0)) > 0 or int(run.get("directFinds", 0)) > 0 or int(run.get("toolUses", 0)) > 0:
				continue
			record_best(progress, "normal", int(run["size"]), float(run.get("elapsedSeconds", 0.0)), 0)


static func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}
