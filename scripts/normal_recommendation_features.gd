extends RefCounted

# Spatial descriptors rerank only an already eligible size/difficulty bucket.
# The sampler is injected to reuse LevelDirector's reward without a preload cycle.
const VERSION := 1
const DIMENSIONS := ["spatialEntropy", "boundaryDensity"]
const BUCKETS := ["low", "medium", "high"]
# Calibrated once against the shipped catalog, frozen for VERSION 1. Board
# sizes have different geometric baselines; never recompute live quantiles.
const EDGES_BY_SIZE := {
	5: {"spatialEntropy": [0.49, 0.52], "boundaryDensity": [0.425, 0.45]},
	6: {"spatialEntropy": [0.425, 0.455], "boundaryDensity": [0.40, 0.435]},
	7: {"spatialEntropy": [0.39, 0.42], "boundaryDensity": [0.38, 0.42]},
	8: {"spatialEntropy": [0.33, 0.37], "boundaryDensity": [0.35, 0.385]},
	9: {"spatialEntropy": [0.27, 0.29], "boundaryDensity": [0.30, 0.32]}
}
const NEAR_REWARD_BAND := 0.02
static var _cache: Dictionary = {}


static func measure(level: Dictionary) -> Dictionary:
	var rows := int(level.get("rows", 0))
	var cols := int(level.get("cols", rows))
	var regions: Array = level.get("regions", [])
	if rows < 2 or cols < 2 or regions.size() != rows:
		return {}
	for row in regions:
		if not row is Array or row.size() != cols:
			return {}
	var key := "%d:%d:%d:%d" % [int(level.get("levelId", -1)), rows, cols, regions.hash()]
	if _cache.has(key):
		return _cache[key].duplicate()
	var colors := {}
	var boundaries := 0
	for row in range(rows):
		for col in range(cols):
			colors[regions[row][col]] = true
			if row + 1 < rows and regions[row][col] != regions[row + 1][col]:
				boundaries += 1
			if col + 1 < cols and regions[row][col] != regions[row][col + 1]:
				boundaries += 1
	var entropy := 0.0
	if colors.size() > 1:
		# Average normalized Shannon entropy in overlapping 3x3 neighborhoods.
		# Unlike a global color histogram this responds to spatial arrangement.
		for row in range(rows):
			for col in range(cols):
				var counts := {}
				var total := 0
				for y in range(maxi(0, row - 1), mini(rows, row + 2)):
					for x in range(maxi(0, col - 1), mini(cols, col + 2)):
						var color = regions[y][x]
						counts[color] = int(counts.get(color, 0)) + 1
						total += 1
				var local_entropy := 0.0
				for count in counts.values():
					var probability := float(count) / float(total)
					local_entropy -= probability * log(probability)
				entropy += local_entropy / log(float(mini(total, colors.size())))
	var result := {
		"spatialEntropy": clampf(entropy / float(rows * cols), 0.0, 1.0),
		"boundaryDensity": float(boundaries) / float(rows * (cols - 1) + cols * (rows - 1))
	}
	_cache[key] = result
	return result.duplicate()


static func buckets(features: Dictionary, size: int) -> Dictionary:
	if not EDGES_BY_SIZE.has(size):
		return {}
	var result := {}
	for dimension in DIMENSIONS:
		if not features.has(dimension):
			return {}
		var value := float(features[dimension])
		if not is_finite(value) or value < 0.0 or value > 1.0:
			return {}
		var edges: Array = EDGES_BY_SIZE[size][dimension]
		result[dimension] = BUCKETS[0 if value < edges[0] else (1 if value < edges[1] else 2)]
	return result


static func stats_key(size: int, difficulty: String, dimension: String, bucket: String) -> String:
	return "%d|%s|%s|%s" % [size, difficulty, dimension, bucket]


static func hint_key(size: int, difficulty: String, entropy_bucket: String, count: int) -> String:
	return "%d|%s|%s|hints:%d" % [size, difficulty, entropy_bucket, count]


static func select_index(levels: Array, candidates: Array, progress: Dictionary, rng: RandomNumberGenerator, sampler: Callable) -> int:
	if candidates.is_empty():
		return -1
	var stats: Dictionary = progress.get("normalFeatureStats", {})
	var prepared: Array = []
	var scores := {}
	# Stable traversal and one draw per bucket; catalog duplication does not
	# grant extra posterior draws to a structure.
	for index in candidates:
		var level: Dictionary = levels[int(index)]
		var feature_buckets := buckets(measure(level), int(level.get("rows", 0)))
		if feature_buckets.is_empty():
			continue
		var keys: Array = []
		for dimension in DIMENSIONS:
			var key := stats_key(int(level["rows"]), str(level["difficulty"]), dimension, feature_buckets[dimension])
			keys.append(key)
			scores[key] = 0.0
		prepared.append({"index": int(index), "keys": keys})
	if prepared.is_empty():
		return int(candidates[rng.randi_range(0, candidates.size() - 1)])
	var ordered_keys: Array = scores.keys()
	ordered_keys.sort()
	for key in ordered_keys:
		scores[key] = sampler.call(stats.get(key, {}), rng)
	var best := -INF
	for candidate in prepared:
		var score := 0.0
		for key in candidate["keys"]:
			score += float(scores[key]) / float(DIMENSIONS.size())
		candidate["score"] = score
		best = maxf(best, score)
	var shortlist: Array = prepared.filter(func(item: Dictionary) -> bool: return float(item["score"]) >= best - NEAR_REWARD_BAND)
	return int(shortlist[rng.randi_range(0, shortlist.size() - 1)]["index"])


static func choose_hint_count(level: Dictionary, feature_buckets: Dictionary, progress: Dictionary, rng: RandomNumberGenerator, sampler: Callable) -> int:
	var stats: Dictionary = progress.get("openingHintStats", {})
	var size := int(level["rows"])
	var difficulty := str(level["difficulty"])
	var entropy_bucket := str(feature_buckets.get("spatialEntropy", "unknown"))
	var best := -INF
	var chosen := 1
	for count in [1, 2]:
		var key := hint_key(size, difficulty, entropy_bucket, count)
		var score := float(sampler.call(stats.get(key, {}), rng))
		if score > best:
			best = score
			chosen = count
	return chosen
