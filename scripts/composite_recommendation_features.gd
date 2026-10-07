extends RefCounted

const CompositeLevelScript = preload("res://scripts/composite_level.gd")
const LevelDirectorScript = preload("res://scripts/level_director.gd")

const DIMENSIONS := ["pieceCount", "fillRatio", "placementAmbiguity"]
const BUCKET_VERSION := 1
const BUCKET_NAMES := ["low", "medium", "high"]
# Stable numeric boundaries, not moving quantiles: a delayed reward must be
# attributed to the same feature value even after the candidate pool changes.
const BUCKET_EDGES := {
	"pieceCount": [4.0, 7.0],
	"fillRatio": [0.25, 0.45],
	"placementAmbiguity": [2.0, 5.0]
}
const MINIMUMS := {
	"simple": [2, 0.08, 1.0],
	"medium": [3, 0.14, 1.0],
	"hard": [4, 0.20, 1.5]
}
const NEAR_REWARD_BAND := 0.02


static func measure(data: Dictionary) -> Dictionary:
	var pieces: Array = data.get("pieces", [])
	var board_area := int(data.get("rows", 0)) * int(data.get("cols", 0))
	if pieces.is_empty() or board_area <= 0:
		return {}
	var movable_cells := 0
	var candidate_count := 0
	for piece in pieces:
		movable_cells += (piece.get("cells", []) as Array).size()
		# These are geometric positions in the visible empty construction space,
		# not positions restricted to the hidden answer's original color regions.
		# Production bundles already contain this cache; no solver runs here.
		candidate_count += CompositeLevelScript._piece_candidate_origins(piece, data.get("constructionCells", [])).size()
	return {
		"pieceCount": pieces.size(),
		"fillRatio": clampf(float(movable_cells) / float(board_area), 0.0, 1.0),
		"placementAmbiguity": float(candidate_count) / float(pieces.size())
	}


static func meets_minimum(features: Dictionary, pattern: String) -> bool:
	var minimum: Array = MINIMUMS.get(pattern, MINIMUMS["medium"])
	for index in range(DIMENSIONS.size()):
		if float(features.get(DIMENSIONS[index], 0.0)) < float(minimum[index]):
			return false
	return true


static func select(
	candidates: Array,
	pattern: String,
	exploring: bool,
	progress: Dictionary,
	size: int,
	rng: RandomNumberGenerator
) -> Dictionary:
	if candidates.is_empty():
		return {}
	var available_buckets := {}
	var prepared: Array = []
	for candidate in candidates:
		var buckets := feature_buckets(candidate["features"])
		if buckets.is_empty():
			continue
		prepared.append({"candidate": candidate, "buckets": buckets})
		for dimension in DIMENSIONS:
			if not available_buckets.has(dimension):
				available_buckets[dimension] = []
			if not available_buckets[dimension].has(buckets[dimension]):
				available_buckets[dimension].append(buckets[dimension])
	if prepared.is_empty():
		return {}
	var stats_by_feature: Dictionary = progress.get("statsByFeature", {})
	var sampled_rewards := {}
	var variable_dimensions: Array = []
	for dimension in DIMENSIONS:
		if available_buckets[dimension].size() > 1:
			variable_dimensions.append(dimension)
		for bucket in BUCKET_NAMES:
			if not available_buckets[dimension].has(bucket):
				continue
			var key := stats_key(size, pattern, dimension, bucket)
			# One posterior draw per feature bucket, not per level. Duplicating
			# catalog entries must not buy a bucket extra Thompson lottery tickets.
			sampled_rewards[key] = LevelDirectorScript.sample_engagement_reward(stats_by_feature.get(key, {}), rng)

	var exploration_dimension := ""
	var exploration_bucket := ""
	if exploring and not variable_dimensions.is_empty():
		exploration_dimension = _exploration_dimension(variable_dimensions, progress, size, rng)
		var least_seen: Array = []
		var minimum := 1 << 30
		for bucket in BUCKET_NAMES:
			if not available_buckets[exploration_dimension].has(bucket):
				continue
			var key := stats_key(size, pattern, exploration_dimension, bucket)
			var plays := int(stats_by_feature.get(key, {}).get("plays", 0))
			if plays < minimum:
				minimum = plays
				least_seen.clear()
			if plays == minimum:
				least_seen.append(bucket)
		exploration_bucket = str(least_seen[rng.randi_range(0, least_seen.size() - 1)])

	var ranked: Array = []
	var best_reward := -INF
	for item in prepared:
		var buckets: Dictionary = item["buckets"]
		if not exploration_dimension.is_empty() and buckets[exploration_dimension] != exploration_bucket:
			continue
		var reward := 0.0
		for dimension in DIMENSIONS:
			reward += float(sampled_rewards[stats_key(size, pattern, dimension, buckets[dimension])]) / float(DIMENSIONS.size())
		best_reward = maxf(best_reward, reward)
		item["sampledReward"] = reward
		ranked.append(item)
	var shortlist: Array = []
	for item in ranked:
		if float(item["sampledReward"]) >= best_reward - NEAR_REWARD_BAND:
			shortlist.append(item)
	var selected: Dictionary = shortlist[rng.randi_range(0, shortlist.size() - 1)]
	selected["explorationDimension"] = exploration_dimension
	selected["explorationBucket"] = exploration_bucket
	return selected


static func _exploration_dimension(dimensions: Array, progress: Dictionary, size: int, rng: RandomNumberGenerator) -> String:
	var counts := {}
	for dimension in dimensions:
		counts[dimension] = 0
	for run in progress.get("recentRuns", []):
		if not run is Dictionary or int(run.get("size", 0)) != size:
			continue
		var dimension := str(run.get("featureExplorationDimension", ""))
		if counts.has(dimension):
			counts[dimension] = int(counts[dimension]) + 1
	var least_seen: Array = []
	var minimum := 1 << 30
	for dimension in dimensions:
		var count := int(counts[dimension])
		if count < minimum:
			minimum = count
			least_seen.clear()
		if count == minimum:
			least_seen.append(dimension)
	return str(least_seen[rng.randi_range(0, least_seen.size() - 1)])


static func feature_buckets(features: Dictionary) -> Dictionary:
	var result := {}
	for dimension in DIMENSIONS:
		if not features.has(dimension):
			return {}
		var value := float(features[dimension])
		if not is_finite(value) or value <= 0.0:
			return {}
		var edges: Array = BUCKET_EDGES[dimension]
		result[dimension] = BUCKET_NAMES[0 if value < float(edges[0]) else (1 if value < float(edges[1]) else 2)]
	return result


static func stats_key(size: int, pattern: String, dimension: String, bucket: String) -> String:
	return "%d|%s|%s|%s" % [size, pattern, dimension, bucket]


static func observe_run(progress: Dictionary, run: Dictionary) -> bool:
	# Delayed next-round/retention events reuse the base run's observed flags.
	# An additional feature receipt makes mirroring idempotent across save/load.
	if int(run.get("assemblyFeatureVersion", 0)) != BUCKET_VERSION:
		return false
	var buckets: Dictionary = run.get("assemblyFeatureBuckets", {})
	for dimension in DIMENSIONS:
		if not BUCKET_NAMES.has(buckets.get(dimension, "")):
			return false
	var size := int(run.get("size", 0))
	var pattern := str(run.get("assemblyDifficultyPattern", ""))
	if size <= 0 or pattern.is_empty():
		return false
	var receipts: Dictionary = run.get("assemblyFeatureObserved", {})
	var stats_by_feature: Dictionary = progress.get("statsByFeature", {})
	var changed := false
	for metric in ["completion", "nextLevel", "retention"]:
		if bool(receipts.get(metric, false)):
			continue
		if metric != "completion" and not bool(run.get(metric + "Observed", false)):
			continue
		var success_field: String = {"completion": "completed", "nextLevel": "openedNextLevel", "retention": "retainedNextDay"}[metric]
		for dimension in DIMENSIONS:
			var key := stats_key(size, pattern, dimension, buckets[dimension])
			var stats: Dictionary = stats_by_feature.get(key, {})
			LevelDirectorScript._update_beta_metric(stats, metric, bool(run.get(success_field, false)))
			if metric == "completion":
				stats["plays"] = int(stats.get("plays", 0)) + 1
			stats_by_feature[key] = stats
		receipts[metric] = true
		changed = true
	progress["statsByFeature"] = stats_by_feature
	run["assemblyFeatureObserved"] = receipts
	return changed
