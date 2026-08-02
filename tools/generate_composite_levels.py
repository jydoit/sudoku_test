#!/usr/bin/env python3
"""Pure-Python offline generator for Color King block-assembly levels.

The script reads ``data/levels.json`` directly and performs region selection,
clue selection, piece splitting, exact-cover layout enumeration, crown
uniqueness checks and placement-order generation without launching Godot.
"""

from __future__ import annotations

import argparse
import copy
import itertools
import json
import math
import random
import sys
import tempfile
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Iterable


Cell = tuple[int, int]  # (row, col)
ORTHOGONAL: tuple[Cell, ...] = ((-1, 0), (0, 1), (1, 0), (0, -1))
DIFFICULTIES = ("simple", "medium", "hard")
PIECE_COUNT_FACTORS = {"simple": 0.5, "medium": 0.6, "hard": 0.8}
MIN_REGION_CELLS = 3
MIN_PIECE_CELLS = 2
DATA_VERSION = 9
EXPORT_VERSION = 2
DEFAULT_SEED = 20260722
QUALITY_BATCH_SIZE = 8
REGION_SPLIT_ATTEMPT_MULTIPLIERS = {
    "simple": 4,
    "medium": 12,
    "hard": 32,
}
REGION_SEARCH_NODE_LIMIT = 25_000
SIMPLE_TWO_REGION_DISCONNECTED_PROBABILITY = 0.40
SIMPLE_THREE_REGION_ISOLATED_PROBABILITY = 0.60
MEDIUM_MID_SIZE_THREE_REGION_PROBABILITY = 0.60

SHAPE_TEMPLATES: tuple[tuple[str, tuple[Cell, ...]], ...] = (
    ("bar", ((0, 0), (0, 1))),
    ("bar", ((0, 0), (0, 1), (0, 2))),
    ("bar", ((0, 0), (0, 1), (0, 2), (0, 3))),
    ("rectangle", ((0, 0), (0, 1), (1, 0), (1, 1))),
    ("l", ((0, 0), (1, 0), (1, 1))),
    ("l", ((0, 0), (1, 0), (2, 0), (2, 1))),
    ("t", ((0, 0), (0, 1), (0, 2), (1, 1))),
    ("z", ((0, 0), (0, 1), (1, 1), (1, 2))),
    ("z", ((0, 1), (0, 2), (1, 0), (1, 1))),
    ("irregular", ((0, 0), (1, 0), (1, 1), (2, 1), (2, 2))),
)


class GenerationError(RuntimeError):
    pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--levels", type=Path, default=Path("data/levels.json"))
    parser.add_argument("--output", type=Path, default=Path("data/composite_levels.json"))
    parser.add_argument("--difficulty", action="append", choices=DIFFICULTIES)
    parser.add_argument("--level-id", action="append", type=int)
    parser.add_argument("--max-levels", type=int, default=0)
    parser.add_argument("--attempts", type=int, default=256)
    parser.add_argument("--split-attempts", type=int, default=12)
    parser.add_argument("--max-search-nodes", type=int, default=250_000)
    parser.add_argument("--validate-only", action="store_true")
    return parser.parse_args()


def normalize_difficulty(raw: str) -> str:
    value = raw.lower()
    if value == "simple":
        return "simple"
    if value in {"hard", "challenge"}:
        return "hard"
    return "medium"


def load_levels(path: Path) -> list[dict[str, Any]]:
    raw = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(raw, list):
        levels = raw
    elif isinstance(raw, dict) and isinstance(raw.get("levels"), list):
        levels = raw["levels"]
    elif isinstance(raw, dict) and isinstance(raw.get("level"), dict):
        levels = [raw["level"]]
    elif isinstance(raw, dict) and {"rows", "cols", "regions"} <= raw.keys():
        levels = [raw]
    else:
        levels = []
    if not isinstance(levels, list):
        raise ValueError(f"{path} does not contain level layout data")
    supported: list[dict[str, Any]] = []
    for index, level in enumerate(levels):
        if not isinstance(level, dict):
            continue
        rows = int(level.get("rows", 0))
        cols = int(level.get("cols", 0))
        if rows < 6 or rows != cols:
            continue
        regions = level.get("regions", [])
        if (
            not isinstance(regions, list)
            or len(regions) != rows
            or any(not isinstance(row, list) or len(row) != cols for row in regions)
        ):
            raise ValueError(f"{path} level index {index} has an invalid regions matrix")
        normalized = dict(level)
        normalized.setdefault("levelId", index + 1)
        supported.append(normalized)
    return supported


def selected_levels(levels: list[dict[str, Any]], args: argparse.Namespace) -> list[dict[str, Any]]:
    selected = levels
    if args.level_id:
        requested = set(args.level_id)
        selected = [level for level in selected if int(level.get("levelId", -1)) in requested]
        missing = sorted(requested - {int(level["levelId"]) for level in selected})
        if missing:
            raise ValueError(f"unsupported or missing level ids: {missing}")
    if args.max_levels > 0:
        selected = selected[: args.max_levels]
    return selected


def generate_entry(
    level: dict[str, Any],
    difficulty: str,
    attempts: int,
    split_attempts: int,
    max_search_nodes: int,
) -> dict[str, Any]:
    level_id = int(level["levelId"])
    difficulty_index = DIFFICULTIES.index(difficulty)
    base_seed = level_id * 1_000_003 + difficulty_index * 104_729 + DEFAULT_SEED
    rejection_counts: Counter[str] = Counter()
    for batch_start in range(0, attempts, QUALITY_BATCH_SIZE):
        batch: list[dict[str, Any]] = []
        batch_end = min(attempts, batch_start + QUALITY_BATCH_SIZE)
        for seed_offset in range(batch_start, batch_end):
            seed = base_seed + seed_offset
            rng = random.Random(seed)
            candidate, reason = build_split_candidate(
                level, difficulty, seed, rng, split_attempts
            )
            if not candidate:
                rejection_counts[reason] += 1
                continue
            batch.append(candidate)
        batch.sort(key=cut_quality_sort_key, reverse=True)
        for candidate in batch:
            analysis = analyze_complete_placements(
                candidate,
                max_layouts=2,
                max_search_nodes=max_search_nodes,
            )
            if (
                int(analysis["solutionCount"]) >= 2
                and len(analysis["layouts"]) >= 2
            ):
                for repaired in repair_ambiguous_split(candidate, analysis, 24):
                    repaired_analysis = analyze_complete_placements(
                        repaired,
                        max_layouts=2,
                        max_search_nodes=max_search_nodes,
                    )
                    if (
                        int(repaired_analysis["solutionCount"]) == 1
                        and repaired_analysis["exhausted"]
                        and len(repaired_analysis["layouts"]) == 1
                    ):
                        candidate = repaired
                        analysis = repaired_analysis
                        break
            complete_placements = analysis["layouts"]
            if int(analysis["solutionCount"]) != 1 or len(complete_placements) != 1:
                rejection_counts["multiple_or_zero_placement_solutions"] += 1
                continue
            if not analysis["exhausted"]:
                rejection_counts["global_search_budget"] += 1
                continue
            approved_layout = make_layout(
                candidate, complete_placements[0]["placements"]
            )
            if approved_layout is None:
                rejection_counts["unique_placement_does_not_restore_source"] += 1
                continue
            candidate["validLayouts"] = [approved_layout]
            candidate["globalUniqueSolution"] = True
            candidate["globalUniquePlacement"] = True
            candidate["globalSolutionSignature"] = approved_layout["signature"]
            candidate["globalPlacementSignature"] = approved_layout["placementSignature"]
            candidate["globalSearchNodes"] = analysis["searchNodes"]
            candidate["globalSearchMemoStates"] = analysis["memoStates"]
            candidate["globalSearchNodeLimit"] = max_search_nodes
            candidate["globalSearchExhausted"] = True
            candidate["solutionOrder"] = build_solution_order(candidate, approved_layout)
            if len(candidate["solutionOrder"]) != len(candidate["pieces"]):
                rejection_counts["solution_order"] += 1
                continue
            return {
                "levelId": level_id,
                "difficulty": difficulty,
                "data": candidate,
            }
    summary = ", ".join(f"{name}={count}" for name, count in sorted(rejection_counts.items()))
    raise GenerationError(
        f"unable to generate {level_id}:{difficulty} after {attempts} attempts"
        + (f" ({summary})" if summary else "")
    )


def build_split_candidate(
    level: dict[str, Any],
    difficulty: str,
    seed: int,
    rng: random.Random,
    split_attempts: int,
) -> tuple[dict[str, Any] | None, str]:
    rows = int(level["rows"])
    cols = int(level["cols"])
    base_regions = [[int(value) for value in row] for row in level["regions"]]
    cells_by_region = collect_region_cells(base_regions)
    selected, fallback = select_regions(cells_by_region, base_regions, difficulty, rng)
    if not selected:
        return None, "region_selection"

    pieces: list[dict[str, Any]] = []
    clue_cells: list[Cell] = []
    construction_cells: set[Cell] = set()
    next_piece_id = 0
    for region_id in selected:
        split = split_region_with_clue(
            cells_by_region[region_id],
            base_regions,
            region_id,
            difficulty,
            rng,
            split_attempts,
        )
        if split is None:
            return None, "piece_split"
        clue, region_pieces = split
        clue_cells.append(clue)
        for absolute_cells in region_pieces:
            construction_cells.update(absolute_cells)
            origin, local_cells = normalize_cells(absolute_cells)
            pieces.append(
                {
                    "pieceId": next_piece_id,
                    "regionId": region_id,
                    "cells": cells_to_arrays(local_cells),
                    "initialOrigin": list(origin),
                    "trayIndex": next_piece_id,
                    "family": shape_family(local_cells),
                }
            )
            next_piece_id += 1

    candidate: dict[str, Any] = {
        "version": DATA_VERSION,
        "levelId": int(level["levelId"]),
        "seed": seed,
        "difficulty": difficulty,
        "difficultyFallback": fallback,
        "rows": rows,
        "cols": cols,
        "baseRegions": base_regions,
        "lockedRegionIds": sorted(set(cells_by_region) - set(selected)),
        "selectedRegionIds": selected,
        "clueCells": cells_to_arrays(sorted(clue_cells)),
        "constructionCells": cells_to_arrays(sorted(construction_cells)),
        "pieces": pieces,
        "validLayouts": [],
    }
    prepare_candidate_origins(candidate)
    candidate["cutQuality"] = analyze_cut_quality(candidate)
    initial_placements = {
        str(piece["pieceId"]): list(piece["initialOrigin"]) for piece in pieces
    }
    initial_layout = make_layout(candidate, initial_placements)
    if initial_layout is None:
        return None, "initial_layout"
    return candidate, ""


def collect_region_cells(regions: list[list[int]]) -> dict[int, set[Cell]]:
    result: dict[int, set[Cell]] = defaultdict(set)
    for row, values in enumerate(regions):
        for col, region_id in enumerate(values):
            result[int(region_id)].add((row, col))
    return dict(result)


def select_regions(
    region_cells: dict[int, set[Cell]],
    regions: list[list[int]],
    difficulty: str,
    rng: random.Random,
) -> tuple[list[int], str]:
    eligible = sorted(
        region_id
        for region_id, cells in region_cells.items()
        if len(cells) >= MIN_REGION_CELLS
    )
    if not eligible:
        return [], ""
    board_size = len(regions)
    desired = desired_region_count(board_size, difficulty, rng)
    fallback = ""
    if difficulty == "hard" and len(eligible) == 2:
        desired = 2
        fallback = "hard_two_regions"
    if len(eligible) < desired:
        return [], ""

    if difficulty == "simple" and desired == 1:
        largest = max(len(region_cells[region_id]) for region_id in eligible)
        choices = [
            region_id for region_id in eligible if len(region_cells[region_id]) == largest
        ]
        return [rng.choice(choices)], ""

    groups = [
        list(group)
        for group in itertools.combinations(eligible, desired)
    ]
    if not groups:
        return [], ""
    if difficulty == "simple":
        adjacency = region_adjacency(regions, set(eligible))
        groups = select_simple_topology_groups(
            groups,
            desired,
            adjacency,
            rng,
        )

    scored: list[tuple[list[int], int, float]] = []
    for group in groups:
        combined = set().union(*(region_cells[region_id] for region_id in group))
        coverage = len(combined)
        spread = sum(
            euclidean(cells_center(region_cells[first]), cells_center(region_cells[second]))
            for first, second in itertools.combinations(group, 2)
        )
        rows = [cell[0] for cell in combined]
        cols = [cell[1] for cell in combined]
        spread += max(rows) - min(rows) + 1 + max(cols) - min(cols) + 1
        scored.append((group, coverage, coverage + spread))
    if difficulty == "simple":
        best_value = min(item[1] for item in scored)
        best = [item[0] for item in scored if item[1] == best_value]
    else:
        best_value = max(item[2] for item in scored)
        best = [item[0] for item in scored if math.isclose(item[2], best_value)]
    return rng.choice(best), fallback


def desired_region_count(
    board_size: int,
    difficulty: str,
    rng: random.Random,
) -> int:
    if difficulty == "simple":
        if board_size >= 9:
            return 3
        if board_size >= 7:
            return 2
        return 1
    if difficulty == "medium":
        if board_size >= 9:
            return 3
        if board_size >= 7:
            return (
                3
                if rng.random() < MEDIUM_MID_SIZE_THREE_REGION_PROBABILITY
                else 2
            )
        return 2
    return 3


def allowed_region_counts(board_size: int, difficulty: str) -> set[int]:
    if difficulty == "simple":
        if board_size >= 9:
            return {3}
        if board_size >= 7:
            return {2}
        return {1}
    if difficulty == "medium":
        if board_size >= 9:
            return {3}
        if board_size >= 7:
            return {2, 3}
        return {2}
    return {3}


def select_simple_topology_groups(
    groups: list[list[int]],
    desired: int,
    adjacency: dict[int, set[int]],
    rng: random.Random,
) -> list[list[int]]:
    if desired < 2:
        return groups
    isolated_groups = [
        group
        for group in groups
        if group_has_isolated_region(group, adjacency)
    ]
    non_isolated_groups = [
        group
        for group in groups
        if not group_has_isolated_region(group, adjacency)
    ]
    isolated_probability = (
        SIMPLE_TWO_REGION_DISCONNECTED_PROBABILITY
        if desired == 2
        else SIMPLE_THREE_REGION_ISOLATED_PROBABILITY
    )
    preferred = (
        isolated_groups
        if rng.random() < isolated_probability
        else non_isolated_groups
    )
    return preferred if preferred else groups


def group_has_isolated_region(
    group: Iterable[int],
    adjacency: dict[int, set[int]],
) -> bool:
    selected = set(group)
    return any(
        not (adjacency.get(region_id, set()) & (selected - {region_id}))
        for region_id in selected
    )


def region_adjacency(
    regions: list[list[int]], eligible: set[int]
) -> dict[int, set[int]]:
    result = {region_id: set() for region_id in eligible}
    for row, values in enumerate(regions):
        for col, first in enumerate(values):
            first = int(first)
            if first not in eligible:
                continue
            for dr, dc in ((0, 1), (1, 0)):
                nr, nc = row + dr, col + dc
                if nr >= len(regions) or nc >= len(regions[nr]):
                    continue
                second = int(regions[nr][nc])
                if second in eligible and second != first:
                    result[first].add(second)
                    result[second].add(first)
    return result


def split_region_with_clue(
    cells: set[Cell],
    regions: list[list[int]],
    region_id: int,
    difficulty: str,
    rng: random.Random,
    split_attempts: int,
) -> tuple[Cell, list[set[Cell]]] | None:
    clue = select_clue_cell(cells, regions, region_id, rng)
    if clue is None:
        return None
    remaining = set(cells)
    remaining.remove(clue)
    piece_count = desired_piece_count(len(remaining), difficulty)
    attempt_budget = (
        split_attempts * REGION_SPLIT_ATTEMPT_MULTIPLIERS[difficulty]
    )
    seen: set[tuple[tuple[Cell, ...], ...]] = set()
    for attempt_index in range(attempt_budget):
        # The product rule allows a singleton only after three ordinary split
        # attempts have failed. Keep retrying ordinary cuts as well so the
        # fallback does not become the dominant Hard-level shape.
        allow_singleton = attempt_index >= 3 and attempt_index % 4 == 3
        pieces = split_region(
            remaining,
            clue,
            piece_count,
            difficulty,
            rng,
            allow_singleton,
        )
        if pieces is None:
            continue
        signature = region_partition_signature(pieces)
        if signature in seen:
            continue
        seen.add(signature)
        if region_split_has_unique_placement(
            pieces,
            remaining,
            regions,
            region_id,
        ):
            return clue, pieces
    return None


def region_partition_signature(
    pieces: list[set[Cell]],
) -> tuple[tuple[Cell, ...], ...]:
    """Canonicalize a cut without depending on piece creation order."""
    return tuple(sorted(tuple(sorted(piece)) for piece in pieces))


def region_split_has_unique_placement(
    pieces: list[set[Cell]],
    construction: set[Cell],
    regions: list[list[int]],
    region_id: int,
) -> bool:
    """Prove that one color region has exactly one final piece arrangement.

    This is a generation-time prefilter. The complete multi-region exact-cover
    search still runs before export and remains the authoritative proof.
    """
    temporary_pieces: list[dict[str, Any]] = []
    for piece_id, absolute_cells in enumerate(pieces):
        origin, local_cells = normalize_cells(absolute_cells)
        temporary_pieces.append(
            {
                "pieceId": piece_id,
                "regionId": region_id,
                "cells": cells_to_arrays(local_cells),
                "initialOrigin": list(origin),
            }
        )
    temporary_data: dict[str, Any] = {
        "cols": len(regions[0]),
        "baseRegions": regions,
        "constructionCells": cells_to_arrays(sorted(construction)),
        "pieces": temporary_pieces,
    }
    prepare_candidate_origins(temporary_data)
    analysis = analyze_complete_placements(
        temporary_data,
        max_layouts=2,
        max_search_nodes=REGION_SEARCH_NODE_LIMIT,
    )
    return (
        bool(analysis["exhausted"])
        and int(analysis["solutionCount"]) == 1
        and len(analysis["layouts"]) == 1
    )


def select_clue_cell(
    cells: set[Cell],
    regions: list[list[int]],
    region_id: int,
    rng: random.Random,
) -> Cell | None:
    safe_edges = [
        cell
        for cell in cells
        if any(add_cells(cell, direction) not in cells for direction in ORTHOGONAL)
        and cells_connected(cells - {cell})
    ]
    if not safe_edges:
        return None
    scored = [
        (
            row_column_different_color_max(cell, regions, region_id),
            cell,
        )
        for cell in safe_edges
    ]
    best_score = max(score for score, _ in scored)
    return rng.choice(
        [cell for score, cell in scored if score == best_score]
    )


def row_column_different_color_max(
    cell: Cell, regions: list[list[int]], region_id: int
) -> int:
    row, col = cell
    row_count = sum(
        int(value) != region_id for index, value in enumerate(regions[row]) if index != col
    )
    column_count = sum(
        int(regions[index][col]) != region_id
        for index in range(len(regions))
        if index != row
    )
    return max(row_count, column_count)


def desired_piece_count(cell_count: int, difficulty: str) -> int:
    desired = math.ceil((cell_count / MIN_PIECE_CELLS) * PIECE_COUNT_FACTORS[difficulty])
    return min(max(1, cell_count // MIN_PIECE_CELLS), min(max(2, desired),6))


def split_region(
    source_cells: set[Cell],
    clue: Cell,
    piece_count: int,
    difficulty: str,
    rng: random.Random,
    allow_singleton: bool,
) -> list[set[Cell]] | None:
    if piece_count == 1:
        return [set(source_cells)] if cells_connected(source_cells) else None
    remaining = set(source_cells)
    filled = {clue}
    pieces: list[set[Cell]] = []
    for index in range(piece_count - 1):
        remaining_piece_count = piece_count - index - 1
        minimum_remaining = remaining_piece_count * MIN_PIECE_CELLS
        if allow_singleton:
            minimum_remaining -= 1
        max_take = len(remaining) - minimum_remaining
        if max_take < MIN_PIECE_CELLS:
            return None
        candidates = template_cut_candidates(remaining, filled, difficulty, max_take)
        if not candidates:
            fallback = random_growth_cut(remaining, filled, max_take, rng)
            if fallback is None:
                return None
            candidates = [(fallback, "irregular", 1.0)]
        scored_candidates: list[tuple[set[Cell], str, float]] = []
        existing_shapes = Counter(
            tuple(sorted(normalize_cells(piece)[1])) for piece in pieces
        )
        for candidate_cells, family, base_weight in candidates:
            shape = tuple(sorted(normalize_cells(candidate_cells)[1]))
            placement_count = count_shape_translations(candidate_cells, source_cells)
            duplicate_count = existing_shapes[shape]
            uniqueness_weight = 1.0 / (
                max(1, placement_count) ** 1.25
                * (1.0 + duplicate_count * 1.5)
            )
            scored_candidates.append(
                (candidate_cells, family, base_weight * uniqueness_weight)
            )
        picked, _, _ = weighted_choice(scored_candidates, rng)
        pieces.append(picked)
        remaining -= picked
        filled |= picked
    if not remaining or (len(remaining) == 1 and not allow_singleton):
        return None
    if not cells_connected(remaining):
        return None
    pieces.append(remaining)
    return pieces


def template_cut_candidates(
    remaining: set[Cell],
    filled: set[Cell],
    difficulty: str,
    max_take: int,
) -> list[tuple[set[Cell], str, float]]:
    result: list[tuple[set[Cell], str, float]] = []
    seen: set[tuple[Cell, ...]] = set()
    for family, template in SHAPE_TEMPLATES:
        for rotation in rotations(set(template)):
            if len(rotation) > max_take:
                continue
            for target in remaining:
                for anchor in rotation:
                    dr, dc = target[0] - anchor[0], target[1] - anchor[1]
                    placed = {(row + dr, col + dc) for row, col in rotation}
                    signature = tuple(sorted(placed))
                    if signature in seen or not placed <= remaining:
                        continue
                    if not touches(placed, filled):
                        continue
                    seen.add(signature)
                    result.append((placed, family, family_weight(family, difficulty)))
    return result


def random_growth_cut(
    remaining: set[Cell],
    filled: set[Cell],
    max_take: int,
    rng: random.Random,
) -> set[Cell] | None:
    starts = [cell for cell in remaining if touches({cell}, filled)]
    maximum = min(max_take, len(remaining) - 1)
    if not starts or maximum < MIN_PIECE_CELLS:
        return None
    for _ in range(80):
        target_size = rng.randint(MIN_PIECE_CELLS, maximum)
        selected = {rng.choice(starts)}
        while len(selected) < target_size:
            frontier = {
                add_cells(cell, direction)
                for cell in selected
                for direction in ORTHOGONAL
                if add_cells(cell, direction) in remaining
                and add_cells(cell, direction) not in selected
            }
            if not frontier:
                break
            selected.add(rng.choice(sorted(frontier)))
        if len(selected) >= MIN_PIECE_CELLS:
            return selected
    return None


def family_weight(family: str, difficulty: str) -> float:
    if difficulty == "simple":
        return 4.0 if family in {"rectangle", "bar"} else 1.2
    if difficulty == "hard":
        return 3.4 if family in {"l", "z", "irregular"} else 1.4
    return 2.6 if family in {"l", "z"} else 2.0


def weighted_choice(
    candidates: list[tuple[set[Cell], str, float]], rng: random.Random
) -> tuple[set[Cell], str, float]:
    pick = rng.random() * sum(item[2] for item in candidates)
    for candidate in candidates:
        pick -= candidate[2]
        if pick <= 0:
            return candidate
    return candidates[-1]


def count_shape_translations(shape_cells: set[Cell], allowed_cells: set[Cell]) -> int:
    _origin, normalized = normalize_cells(shape_cells)
    origins: set[Cell] = set()
    for target in sorted(allowed_cells):
        for anchor in sorted(normalized):
            origin = (target[0] - anchor[0], target[1] - anchor[1])
            absolute = {
                (origin[0] + row, origin[1] + col) for row, col in normalized
            }
            if absolute <= allowed_cells:
                origins.add(origin)
    return len(origins)


def prepare_candidate_origins(data: dict[str, Any]) -> None:
    construction = arrays_to_cells(data["constructionCells"])
    cols = int(data["cols"])
    regions = data["baseRegions"]
    for piece in data["pieces"]:
        candidates = piece_candidates(piece, construction, cols)
        region_id = int(piece["regionId"])
        target_candidates = [
            candidate
            for candidate in candidates
            if all(
                int(regions[row][col]) == region_id
                for row, col in candidate["cells"]
            )
        ]
        piece["_candidates"] = candidates
        piece["_targetCandidates"] = target_candidates
        piece["_candidateOrigins"] = [
            list(candidate["origin"]) for candidate in candidates
        ]


def piece_candidates(
    piece: dict[str, Any], construction: set[Cell], cols: int
) -> list[dict[str, Any]]:
    local_cells = arrays_to_cells(piece["cells"])
    candidates: list[dict[str, Any]] = []
    seen: set[Cell] = set()
    for target in sorted(construction):
        for anchor in sorted(local_cells):
            origin = (target[0] - anchor[0], target[1] - anchor[1])
            if origin in seen:
                continue
            absolute = {
                (origin[0] + row, origin[1] + col) for row, col in local_cells
            }
            if absolute <= construction:
                seen.add(origin)
                candidates.append(
                    {
                        "origin": origin,
                        "cells": absolute,
                        "mask": cells_mask(absolute, cols),
                    }
                )
    candidates.sort(key=lambda candidate: tuple(candidate["origin"]))
    return candidates


def analyze_complete_placements(
    data: dict[str, Any],
    max_layouts: int,
    max_search_nodes: int,
) -> dict[str, Any]:
    solution_limit = max(2, max_layouts)
    groups = build_piece_groups(data, target_only=True)
    construction = arrays_to_cells(data["constructionCells"])
    construction_mask = cells_mask(construction, int(data["cols"]))
    initial_counts = tuple(len(group["pieceIds"]) for group in groups)
    initial_min_indices = tuple(0 for _group in groups)
    nodes = 0
    budget_hit = False
    memo: dict[
        tuple[int, tuple[int, ...], tuple[int, ...]],
        tuple[tuple[tuple[int, int], ...], ...],
    ] = {}

    def search(
        occupied_mask: int,
        remaining_counts: tuple[int, ...],
        min_candidate_indices: tuple[int, ...],
    ) -> tuple[tuple[tuple[int, int], ...], ...]:
        nonlocal nodes, budget_hit
        state = (occupied_mask, remaining_counts, min_candidate_indices)
        if state in memo:
            return memo[state]
        if budget_hit:
            return ()
        if nodes >= max_search_nodes:
            budget_hit = True
            return ()
        nodes += 1
        if not any(remaining_counts):
            result = ((),) if occupied_mask == construction_mask else ()
            memo[state] = result
            return result

        available_by_group: dict[int, list[int]] = {}
        coverable_mask = occupied_mask
        active_groups: list[tuple[int, int, int, int]] = []
        for group_index, remaining_count in enumerate(remaining_counts):
            if remaining_count <= 0:
                continue
            group = groups[group_index]
            available = [
                candidate_index
                for candidate_index in range(
                    min_candidate_indices[group_index],
                    len(group["candidates"]),
                )
                if not occupied_mask
                & int(group["candidates"][candidate_index]["mask"])
            ]
            if len(available) < remaining_count:
                memo[state] = ()
                return ()
            available_by_group[group_index] = available
            for candidate_index in available:
                coverable_mask |= int(group["candidates"][candidate_index]["mask"])
            active_groups.append(
                (
                    len(available) - remaining_count,
                    len(available),
                    -len(group["cells"]),
                    group_index,
                )
            )
        if (coverable_mask & construction_mask) != construction_mask:
            memo[state] = ()
            return ()

        _slack, _available_count, _negative_size, group_index = min(active_groups)
        solutions: list[tuple[tuple[int, int], ...]] = []
        for candidate_index in available_by_group[group_index]:
            candidate = groups[group_index]["candidates"][candidate_index]
            mask = int(candidate["mask"])
            next_counts = list(remaining_counts)
            next_counts[group_index] -= 1
            next_min_indices = list(min_candidate_indices)
            next_min_indices[group_index] = candidate_index + 1
            child_solutions = search(
                occupied_mask | mask,
                tuple(next_counts),
                tuple(next_min_indices),
            )
            for child_suffix in child_solutions:
                solutions.append(((group_index, candidate_index),) + child_suffix)
                if len(solutions) >= solution_limit:
                    break
            if len(solutions) >= solution_limit or budget_hit:
                break
        result = tuple(solutions)
        if not budget_hit:
            memo[state] = result
        return result

    solution_choices = search(
        0,
        initial_counts,
        initial_min_indices,
    )
    layouts: list[dict[str, Any]] = []
    for choices in solution_choices:
        placements = placements_from_group_choices(
            groups, choices
        )
        layout = make_complete_placement(data, placements)
        if layout is not None:
            layouts.append(layout)
    return {
        "layouts": layouts,
        "solutionCount": min(solution_limit, len(solution_choices)),
        "searchNodes": nodes,
        "memoStates": len(memo),
        "exhausted": not budget_hit and len(solution_choices) < solution_limit,
    }


def build_piece_groups(
    data: dict[str, Any], target_only: bool = False
) -> list[dict[str, Any]]:
    grouped: dict[tuple[int, tuple[Cell, ...]], list[dict[str, Any]]] = defaultdict(list)
    for piece in data["pieces"]:
        grouped[piece_equivalence_key(piece)].append(piece)
    result: list[dict[str, Any]] = []
    for key in sorted(grouped):
        pieces = sorted(grouped[key], key=lambda piece: int(piece["pieceId"]))
        candidate_key = "_targetCandidates" if target_only else "_candidates"
        candidates = sorted(
            pieces[0][candidate_key],
            key=lambda candidate: tuple(candidate["origin"]),
        )
        result.append(
            {
                "key": key,
                "pieceIds": [int(piece["pieceId"]) for piece in pieces],
                "cells": arrays_to_cells(pieces[0]["cells"]),
                "candidates": candidates,
                "targetOrigins": sorted(
                    (
                        int(piece["initialOrigin"][0]),
                        int(piece["initialOrigin"][1]),
                    )
                    for piece in pieces
                ),
            }
        )
    return result


def analyze_cut_quality(data: dict[str, Any]) -> dict[str, Any]:
    groups = build_piece_groups(data, target_only=True)
    spatial_groups = build_piece_groups(data, target_only=False)
    duplicate_piece_count = sum(
        max(0, len(group["pieceIds"]) - 1) for group in groups
    )
    candidate_position_count = sum(len(group["candidates"]) for group in groups)
    spatial_candidate_position_count = sum(
        len(group["candidates"]) for group in spatial_groups
    )
    target_alternative_count = sum(
        max(0, len(group["candidates"]) - len(group["pieceIds"]))
        for group in groups
    )
    initial_forced_group_count = sum(
        len(group["candidates"]) == len(group["pieceIds"])
        for group in groups
    )
    occupied_mask = 0
    remaining_groups = set(range(len(groups)))
    forced_piece_count = 0
    forced_group_order: list[int] = []
    while remaining_groups:
        forced: list[tuple[int, int]] = []
        for group_index in sorted(remaining_groups):
            group = groups[group_index]
            available = [
                candidate
                for candidate in group["candidates"]
                if not occupied_mask & int(candidate["mask"])
            ]
            target_origins = set(group["targetOrigins"])
            available_origins = {
                (
                    int(candidate["origin"][0]),
                    int(candidate["origin"][1]),
                )
                for candidate in available
            }
            if (
                len(available) == len(group["pieceIds"])
                and available_origins == target_origins
            ):
                forced.append((-len(group["pieceIds"]), group_index))
        if not forced:
            break
        _negative_size, group_index = min(forced)
        group = groups[group_index]
        for candidate in group["candidates"]:
            origin = (
                int(candidate["origin"][0]),
                int(candidate["origin"][1]),
            )
            if origin in set(group["targetOrigins"]):
                occupied_mask |= int(candidate["mask"])
        forced_piece_count += len(group["pieceIds"])
        forced_group_order.append(group_index)
        remaining_groups.remove(group_index)
    piece_count = len(data["pieces"])
    return {
        "candidatePositionCount": candidate_position_count,
        "spatialCandidatePositionCount": spatial_candidate_position_count,
        "targetAlternativeCount": target_alternative_count,
        "duplicatePieceCount": duplicate_piece_count,
        "initialForcedGroupCount": initial_forced_group_count,
        "forcedPlacementCount": forced_piece_count,
        "forcedPlacementRatio": (
            float(forced_piece_count) / float(piece_count) if piece_count else 0.0
        ),
        "forcedChainComplete": forced_piece_count == piece_count,
        "forcedGroupOrder": forced_group_order,
    }


def cut_quality_sort_key(data: dict[str, Any]) -> tuple[Any, ...]:
    quality = data.get("cutQuality", {})
    return (
        bool(quality.get("forcedChainComplete", False)),
        float(quality.get("forcedPlacementRatio", 0.0)),
        int(quality.get("initialForcedGroupCount", 0)),
        -int(quality.get("targetAlternativeCount", 0)),
        -int(quality.get("duplicatePieceCount", 0)),
        -int(quality.get("candidatePositionCount", 0)),
        -int(data.get("seed", 0)),
    )


def repair_ambiguous_split(
    data: dict[str, Any],
    analysis: dict[str, Any],
    limit: int,
) -> list[dict[str, Any]]:
    if len(analysis.get("layouts", [])) < 2 or limit <= 0:
        return []
    ambiguous_ids = ambiguous_piece_ids(data, analysis["layouts"][1]["placements"])
    absolute_by_id = {
        int(piece["pieceId"]): absolute_piece_cells(
            piece, piece["initialOrigin"]
        )
        for piece in data["pieces"]
    }
    pieces_by_id = {
        int(piece["pieceId"]): piece for piece in data["pieces"]
    }
    mutations: list[dict[str, Any]] = []
    seen: set[tuple[tuple[int, tuple[Cell, ...]], ...]] = set()
    piece_ids = sorted(pieces_by_id)
    directed_pairs = [
        (donor_id, receiver_id)
        for donor_id in piece_ids
        for receiver_id in piece_ids
        if donor_id != receiver_id
        and int(pieces_by_id[donor_id]["regionId"])
        == int(pieces_by_id[receiver_id]["regionId"])
        and (donor_id in ambiguous_ids or receiver_id in ambiguous_ids)
    ]
    for donor_id, receiver_id in directed_pairs:
        donor_cells = absolute_by_id[donor_id]
        receiver_cells = absolute_by_id[receiver_id]
        if len(donor_cells) <= MIN_PIECE_CELLS:
            continue
        boundary_cells = sorted(
            cell
            for cell in donor_cells
            if any(
                add_cells(cell, direction) in receiver_cells
                for direction in ORTHOGONAL
            )
        )
        for moved_cell in boundary_cells:
            next_donor = donor_cells - {moved_cell}
            next_receiver = receiver_cells | {moved_cell}
            if (
                len(next_donor) < MIN_PIECE_CELLS
                or not cells_connected(next_donor)
                or not cells_connected(next_receiver)
            ):
                continue
            mutated = copy.deepcopy(data)
            mutated["validLayouts"] = []
            for piece in mutated["pieces"]:
                piece.pop("_candidates", None)
                piece.pop("_candidateOrigins", None)
                piece_id = int(piece["pieceId"])
                if piece_id == donor_id:
                    set_piece_absolute_cells(piece, next_donor)
                elif piece_id == receiver_id:
                    set_piece_absolute_cells(piece, next_receiver)
            signature = tuple(
                (
                    int(piece["pieceId"]),
                    tuple(
                        sorted(
                            absolute_piece_cells(piece, piece["initialOrigin"])
                        )
                    ),
                )
                for piece in mutated["pieces"]
            )
            if signature in seen:
                continue
            seen.add(signature)
            prepare_candidate_origins(mutated)
            initial_placements = {
                str(piece["pieceId"]): list(piece["initialOrigin"])
                for piece in mutated["pieces"]
            }
            if make_layout(mutated, initial_placements) is None:
                continue
            mutated["cutQuality"] = analyze_cut_quality(mutated)
            mutated["cutQuality"]["repairDepth"] = (
                int(data.get("cutQuality", {}).get("repairDepth", 0)) + 1
            )
            mutations.append(mutated)
    mutations.sort(key=cut_quality_sort_key, reverse=True)
    return mutations[:limit]


def ambiguous_piece_ids(
    data: dict[str, Any], alternative_placements: dict[str, list[int]]
) -> set[int]:
    result: set[int] = set()
    for group in build_piece_groups(data):
        target_origins = set(group["targetOrigins"])
        alternative_origins = {
            (
                int(alternative_placements[str(piece_id)][0]),
                int(alternative_placements[str(piece_id)][1]),
            )
            for piece_id in group["pieceIds"]
        }
        if target_origins != alternative_origins:
            result.update(group["pieceIds"])
    return result


def absolute_piece_cells(
    piece: dict[str, Any], origin_raw: Iterable[int]
) -> set[Cell]:
    origin_values = list(origin_raw)
    origin = (int(origin_values[0]), int(origin_values[1]))
    return {
        (origin[0] + row, origin[1] + col)
        for row, col in arrays_to_cells(piece["cells"])
    }


def set_piece_absolute_cells(piece: dict[str, Any], absolute_cells: set[Cell]) -> None:
    origin, local_cells = normalize_cells(absolute_cells)
    piece["cells"] = cells_to_arrays(local_cells)
    piece["initialOrigin"] = list(origin)
    piece["family"] = shape_family(local_cells)


def placements_from_group_choices(
    groups: list[dict[str, Any]],
    choices: tuple[tuple[int, int], ...],
) -> dict[str, list[int]]:
    origins_by_group: dict[int, list[Cell]] = defaultdict(list)
    for group_index, candidate_index in choices:
        origin = groups[group_index]["candidates"][candidate_index]["origin"]
        origins_by_group[group_index].append(
            (int(origin[0]), int(origin[1]))
        )
    placements: dict[str, list[int]] = {}
    for group_index, group in enumerate(groups):
        origins = sorted(origins_by_group.get(group_index, []))
        if len(origins) != len(group["pieceIds"]):
            return {}
        for piece_id, origin in zip(group["pieceIds"], origins):
            placements[str(piece_id)] = list(origin)
    return placements


def make_layout(
    data: dict[str, Any], placements: dict[str, list[int]]
) -> dict[str, Any] | None:
    complete = make_complete_placement(data, placements)
    if complete is None:
        return None
    regions = complete["regions"]
    if regions != data["baseRegions"]:
        return None
    if any(
        not cells_connected(cells_for_region(regions, int(region_id)))
        for region_id in data["selectedRegionIds"]
    ):
        return None
    solutions = find_crown_solutions(regions, limit=2)
    if len(solutions) != 1:
        return None
    complete["solution"] = solutions[0]
    return complete


def make_complete_placement(
    data: dict[str, Any], placements: dict[str, list[int]]
) -> dict[str, Any] | None:
    if len(placements) != len(data["pieces"]):
        return None
    regions = [row[:] for row in data["baseRegions"]]
    construction = arrays_to_cells(data["constructionCells"])
    filled: set[Cell] = set()
    serialized: dict[str, list[int]] = {}
    for piece in data["pieces"]:
        piece_key = str(piece["pieceId"])
        origin_raw = placements.get(piece_key)
        if origin_raw is None:
            return None
        origin = (int(origin_raw[0]), int(origin_raw[1]))
        absolute = {
            (origin[0] + row, origin[1] + col)
            for row, col in arrays_to_cells(piece["cells"])
        }
        if not absolute <= construction or filled & absolute:
            return None
        filled |= absolute
        for row, col in absolute:
            regions[row][col] = int(piece["regionId"])
        serialized[piece_key] = list(origin)
    if filled != construction:
        return None
    return {
        "signature": regions_signature(regions),
        "placementSignature": placement_signature(data["pieces"], serialized),
        "placements": serialized,
        "regions": regions,
    }


def piece_equivalence_key(piece: dict[str, Any]) -> tuple[int, tuple[Cell, ...]]:
    return int(piece["regionId"]), tuple(sorted(arrays_to_cells(piece["cells"])))


def placement_signature(
    pieces: list[dict[str, Any]], placements: dict[str, list[int]]
) -> str:
    grouped: dict[tuple[int, tuple[Cell, ...]], list[Cell]] = defaultdict(list)
    for piece in pieces:
        origin = placements[str(int(piece["pieceId"]))]
        grouped[piece_equivalence_key(piece)].append(
            (int(origin[0]), int(origin[1]))
        )
    sections: list[str] = []
    for (region_id, shape), origins in sorted(grouped.items()):
        shape_text = ";".join(f"{row},{col}" for row, col in shape)
        origins_text = ";".join(
            f"{row},{col}" for row, col in sorted(origins)
        )
        sections.append(f"{region_id}[{shape_text}]@{origins_text}")
    return "/".join(sections)


def find_crown_solutions(
    regions: list[list[int]], limit: int = 2
) -> list[list[list[int]]]:
    size = len(regions)
    assigned_rows: set[int] = set()
    used_cols: set[int] = set()
    used_regions: set[int] = set()
    placed_by_row: dict[int, int] = {}
    solutions: list[list[list[int]]] = []

    def search(depth: int) -> None:
        if len(solutions) >= limit:
            return
        if depth == size:
            if len(used_regions) == size:
                solutions.append([[row, placed_by_row[row]] for row in range(size)])
            return
        best_row = -1
        best_options: list[int] = []
        for row in range(size):
            if row in assigned_rows:
                continue
            options = [
                col
                for col in range(size)
                if col not in used_cols
                and int(regions[row][col]) not in used_regions
                and all(
                    abs(other_row - row) > 1
                    or abs(other_col - col) > 1
                    for other_row, other_col in placed_by_row.items()
                )
            ]
            if not options:
                return
            if best_row < 0 or len(options) < len(best_options):
                best_row, best_options = row, options
        assigned_rows.add(best_row)
        for col in best_options:
            region_id = int(regions[best_row][col])
            used_cols.add(col)
            used_regions.add(region_id)
            placed_by_row[best_row] = col
            search(depth + 1)
            del placed_by_row[best_row]
            used_regions.remove(region_id)
            used_cols.remove(col)
            if len(solutions) >= limit:
                break
        assigned_rows.remove(best_row)

    search(0)
    return solutions


def build_solution_order(
    data: dict[str, Any], layout: dict[str, Any]
) -> list[dict[str, Any]]:
    remaining = list(data["pieces"])
    occupied_mask = 0
    result: list[dict[str, Any]] = []
    approved = layout["placements"]
    while remaining:
        choices: list[tuple[int, int, dict[str, Any], dict[str, Any]]] = []
        for piece in remaining:
            allowed = [
                candidate
                for candidate in piece["_candidates"]
                if not occupied_mask & int(candidate["mask"])
            ]
            approved_origin = tuple(approved[str(piece["pieceId"])])
            approved_candidate = next(
                (candidate for candidate in allowed if candidate["origin"] == approved_origin),
                None,
            )
            if approved_candidate is not None:
                choices.append(
                    (len(allowed), int(piece["pieceId"]), piece, approved_candidate)
                )
        if not choices:
            return []
        candidate_count, piece_id, piece, candidate = min(
            choices, key=lambda item: (item[0], item[1])
        )
        result.append(
            {
                "pieceId": piece_id,
                "origin": list(candidate["origin"]),
                "candidateCount": candidate_count,
            }
        )
        occupied_mask |= int(candidate["mask"])
        remaining.remove(piece)
    return result


def strip_runtime_fields(data: dict[str, Any]) -> None:
    for piece in data["pieces"]:
        piece.pop("_candidates", None)
        piece.pop("_targetCandidates", None)
        piece.pop("_candidateOrigins", None)


def validate_payload(
    payload: dict[str, Any],
    levels: list[dict[str, Any]],
    difficulties: tuple[str, ...],
) -> None:
    entries = payload.get("entries", [])
    expected = {
        (int(level["levelId"]), difficulty)
        for level in levels
        for difficulty in difficulties
    }
    actual: set[tuple[int, str]] = set()
    for entry in entries:
        key = (int(entry.get("levelId", -1)), str(entry.get("difficulty", "")))
        if key in actual:
            raise ValueError(f"duplicate offline composite entry: {key}")
        actual.add(key)
        data = entry.get("data", {})
        layouts = data.get("validLayouts", [])
        pieces = data.get("pieces", [])
        order = data.get("solutionOrder", [])
        selected_count = len(data.get("selectedRegionIds", []))
        fallback = str(data.get("difficultyFallback", ""))
        board_size = int(data.get("rows", 0))
        if key[1] == "hard":
            if selected_count == 2 and fallback != "hard_two_regions":
                raise ValueError(f"{key} silently falls back to two regions")
            if selected_count not in {2, 3}:
                raise ValueError(f"{key} must select three regions or use the explicit fallback")
        elif selected_count not in allowed_region_counts(board_size, key[1]):
            raise ValueError(
                f"{key} selects {selected_count} regions, "
                f"expected {sorted(allowed_region_counts(board_size, key[1]))} "
                f"for a {board_size}x{board_size} board"
            )
        if (
            not data.get("globalUniqueSolution")
            or not data.get("globalUniquePlacement")
            or not data.get("globalSearchExhausted")
        ):
            raise ValueError(f"{key} has no exhausted global uniqueness proof")
        if (
            len(layouts) != 1
            or not layouts[0].get("signature")
            or not layouts[0].get("placementSignature")
        ):
            raise ValueError(f"{key} must contain exactly one approved placement")
        if (
            str(data.get("globalSolutionSignature", "")) != layouts[0]["signature"]
            or str(data.get("globalPlacementSignature", ""))
            != layouts[0]["placementSignature"]
        ):
            raise ValueError(f"{key} uniqueness signatures do not match its layout")
        if len(order) != len(pieces) or not pieces:
            raise ValueError(f"{key} has an incomplete placement order")
        validate_clues_and_construction(key, data)
        validate_piece_partition(key, data)
        approved = layouts[0]["placements"]
        if sorted(int(step["pieceId"]) for step in order) != sorted(
            int(piece["pieceId"]) for piece in pieces
        ):
            raise ValueError(f"{key} placement order does not cover every piece")
        if any(
            list(step["origin"]) != list(approved[str(int(step["pieceId"]))])
            or int(step["candidateCount"]) < 1
            for step in order
        ):
            raise ValueError(f"{key} contains an invalid placement-order step")
        if len(find_crown_solutions(layouts[0]["regions"], 2)) != 1:
            raise ValueError(f"{key} approved layout has no unique crown solution")
        validate_solution_order(key, data, order)
        validation_data = copy.deepcopy(data)
        prepare_candidate_origins(validation_data)
        reproduced_quality = analyze_cut_quality(validation_data)
        stored_quality = dict(data.get("cutQuality", {}))
        stored_quality.pop("repairDepth", None)
        if stored_quality != reproduced_quality:
            raise ValueError(f"{key} cut-quality metrics cannot be reproduced")
        uniqueness = analyze_complete_placements(
            validation_data,
            max_layouts=2,
            max_search_nodes=max(1, int(data.get("globalSearchNodeLimit", 250_000))),
        )
        if (
            not uniqueness["exhausted"]
            or int(uniqueness["solutionCount"]) != 1
            or len(uniqueness["layouts"]) != 1
            or uniqueness["layouts"][0]["placementSignature"]
            != layouts[0]["placementSignature"]
        ):
            raise ValueError(f"{key} placement uniqueness cannot be reproduced")
    missing = sorted(expected - actual)
    extra = sorted(actual - expected)
    if missing or extra:
        raise ValueError(
            f"offline composite coverage mismatch: missing={missing[:12]} extra={extra[:12]}"
        )


def validate_piece_partition(key: tuple[int, str], data: dict[str, Any]) -> None:
    construction = arrays_to_cells(data["constructionCells"])
    occupied: set[Cell] = set()
    pieces_by_region: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for piece in data["pieces"]:
        pieces_by_region[int(piece["regionId"])].append(piece)
        local = arrays_to_cells(piece["cells"])
        if len(local) != len(piece["cells"]) or not cells_connected(local):
            raise ValueError(f"{key} contains a duplicate or disconnected piece")
        origin = tuple(int(value) for value in piece["initialOrigin"])
        absolute = {(origin[0] + row, origin[1] + col) for row, col in local}
        if not absolute <= construction or occupied & absolute:
            raise ValueError(f"{key} initial pieces overlap or leave the construction area")
        occupied |= absolute
    if occupied != construction:
        raise ValueError(f"{key} initial pieces do not cover the construction area")
    difficulty = key[1]
    for region_id in data["selectedRegionIds"]:
        movable_count = sum(
            int(data["baseRegions"][row][col]) == region_id
            for row, col in construction
        )
        expected = desired_piece_count(movable_count, difficulty)
        region_pieces = pieces_by_region[region_id]
        if len(region_pieces) != expected:
            raise ValueError(
                f"{key} region {region_id} has {len(region_pieces)} pieces, expected {expected}"
            )
        if sum(len(piece["cells"]) == 1 for piece in region_pieces) > 1:
            raise ValueError(f"{key} region {region_id} has multiple singleton pieces")


def validate_clues_and_construction(
    key: tuple[int, str], data: dict[str, Any]
) -> None:
    regions = [[int(value) for value in row] for row in data["baseRegions"]]
    selected_ids = {int(value) for value in data["selectedRegionIds"]}
    clue_cells = arrays_to_cells(data["clueCells"])
    construction = arrays_to_cells(data["constructionCells"])
    if len(clue_cells) != len(selected_ids):
        raise ValueError(f"{key} must contain exactly one clue for each selected region")
    expected_construction: set[Cell] = set()
    clue_regions: set[int] = set()
    for clue in clue_cells:
        row, col = clue
        if row < 0 or row >= len(regions) or col < 0 or col >= len(regions[row]):
            raise ValueError(f"{key} contains an out-of-bounds clue")
        region_id = regions[row][col]
        if region_id not in selected_ids or region_id in clue_regions:
            raise ValueError(f"{key} contains duplicate or non-selected clue colors")
        clue_regions.add(region_id)
        region_cells = cells_for_region(regions, region_id)
        safe_edges = [
            cell
            for cell in region_cells
            if any(
                add_cells(cell, direction) not in region_cells
                for direction in ORTHOGONAL
            )
            and cells_connected(region_cells - {cell})
        ]
        if clue not in safe_edges:
            raise ValueError(f"{key} clue {clue} is not a safe boundary cell")
        clue_score = row_column_different_color_max(
            clue, regions, region_id
        )
        best_score = max(
            row_column_different_color_max(cell, regions, region_id)
            for cell in safe_edges
        )
        if clue_score != best_score:
            raise ValueError(f"{key} clue {clue} does not use the maximum score")
        expected_construction |= region_cells - {clue}
    if clue_regions != selected_ids or construction != expected_construction:
        raise ValueError(f"{key} clues and construction cells do not partition selected regions")


def validate_solution_order(
    key: tuple[int, str],
    data: dict[str, Any],
    order: list[dict[str, Any]],
) -> None:
    construction = arrays_to_cells(data["constructionCells"])
    cols = int(data["cols"])
    pieces = {int(piece["pieceId"]): piece for piece in data["pieces"]}
    occupied_mask = 0
    for step in order:
        piece_id = int(step["pieceId"])
        piece = pieces[piece_id]
        available = [
            candidate
            for candidate in piece_candidates(piece, construction, cols)
            if not occupied_mask & int(candidate["mask"])
        ]
        origin = tuple(int(value) for value in step["origin"])
        approved = next(
            (candidate for candidate in available if candidate["origin"] == origin),
            None,
        )
        if approved is None:
            raise ValueError(f"{key} solution order places piece {piece_id} illegally")
        if int(step["candidateCount"]) != len(available):
            raise ValueError(f"{key} solution order has a stale candidate count")
        occupied_mask |= int(approved["mask"])
    if occupied_mask != cells_mask(construction, cols):
        raise ValueError(f"{key} solution order does not fill the construction area")


def generate_payload(
    levels: list[dict[str, Any]], difficulties: tuple[str, ...], args: argparse.Namespace
) -> dict[str, Any]:
    entries: list[dict[str, Any]] = []
    for level in levels:
        for difficulty in difficulties:
            entry = generate_entry(
                level,
                difficulty,
                max(1, args.attempts),
                max(1, args.split_attempts),
                max(1, args.max_search_nodes),
            )
            strip_runtime_fields(entry["data"])
            entries.append(entry)
            print(
                f"generated {entry['levelId']}:{difficulty} "
                f"pieces={len(entry['data']['pieces'])} "
                f"nodes={entry['data']['globalSearchNodes']}"
            )
    entries.sort(key=lambda entry: (int(entry["levelId"]), str(entry["difficulty"])))
    return {
        "version": EXPORT_VERSION,
        "compositeDataVersion": DATA_VERSION,
        "difficulties": list(difficulties),
        "entries": entries,
    }


def add_cells(first: Cell, second: Cell) -> Cell:
    return first[0] + second[0], first[1] + second[1]


def cells_connected(cells: set[Cell]) -> bool:
    if not cells:
        return False
    pending = [next(iter(cells))]
    visited = {pending[0]}
    while pending:
        current = pending.pop()
        for direction in ORTHOGONAL:
            neighbor = add_cells(current, direction)
            if neighbor in cells and neighbor not in visited:
                visited.add(neighbor)
                pending.append(neighbor)
    return visited == cells


def cells_for_region(regions: list[list[int]], region_id: int) -> set[Cell]:
    return {
        (row, col)
        for row, values in enumerate(regions)
        for col, value in enumerate(values)
        if int(value) == region_id
    }


def cells_center(cells: set[Cell]) -> tuple[float, float]:
    return (
        sum(cell[0] for cell in cells) / len(cells),
        sum(cell[1] for cell in cells) / len(cells),
    )


def euclidean(first: tuple[float, float], second: tuple[float, float]) -> float:
    return math.hypot(first[0] - second[0], first[1] - second[1])


def touches(cells: set[Cell], other: set[Cell]) -> bool:
    return any(
        add_cells(cell, direction) in other
        for cell in cells
        for direction in ORTHOGONAL
    )


def normalize_cells(cells: set[Cell]) -> tuple[Cell, set[Cell]]:
    min_row = min(row for row, _ in cells)
    min_col = min(col for _, col in cells)
    return (min_row, min_col), {
        (row - min_row, col - min_col) for row, col in cells
    }


def rotations(cells: set[Cell]) -> list[set[Cell]]:
    result: list[set[Cell]] = []
    seen: set[tuple[Cell, ...]] = set()
    current = set(cells)
    for _ in range(4):
        _, normalized = normalize_cells(current)
        signature = tuple(sorted(normalized))
        if signature not in seen:
            seen.add(signature)
            result.append(normalized)
        current = {(-col, row) for row, col in current}
    return result


def shape_family(cells: set[Cell]) -> str:
    signature = tuple(sorted(normalize_cells(cells)[1]))
    for family, template in SHAPE_TEMPLATES:
        if family == "z" and any(
            tuple(sorted(rotation)) == signature for rotation in rotations(set(template))
        ):
            return "z"
    rows = [row for row, _ in cells]
    cols = [col for _, col in cells]
    area = (max(rows) - min(rows) + 1) * (max(cols) - min(cols) + 1)
    if len(cells) == area:
        return "rectangle" if len(set(rows)) > 1 and len(set(cols)) > 1 else "bar"
    degrees = sorted(
        sum(add_cells(cell, direction) in cells for direction in ORTHOGONAL)
        for cell in cells
    )
    if len(cells) >= 4 and degrees[-1] >= 3:
        return "t"
    if len(cells) >= 3 and degrees.count(1) == 2:
        return "l"
    return "irregular"


def cells_mask(cells: set[Cell], cols: int) -> int:
    mask = 0
    for row, col in cells:
        mask |= 1 << (row * cols + col)
    return mask


def cells_to_arrays(cells: Iterable[Cell]) -> list[list[int]]:
    return [[row, col] for row, col in sorted(cells)]


def arrays_to_cells(cells: Iterable[Iterable[int]]) -> set[Cell]:
    return {(int(cell[0]), int(cell[1])) for cell in cells}


def regions_signature(regions: list[list[int]]) -> str:
    return "/".join(",".join(str(int(value)) for value in row) for row in regions)


def normalized_path(root: Path, path: Path) -> Path:
    return path if path.is_absolute() else root / path


def main() -> int:
    args = parse_args()
    root = Path(__file__).resolve().parents[1]
    levels_path = normalized_path(root, args.levels)
    output_path = normalized_path(root, args.output)
    try:
        levels = selected_levels(load_levels(levels_path), args)
        difficulties = tuple(dict.fromkeys(args.difficulty or DIFFICULTIES))
        if not levels:
            raise ValueError("no supported levels selected")
        if args.validate_only:
            payload = json.loads(output_path.read_text(encoding="utf-8"))
            validate_payload(payload, levels, difficulties)
        else:
            payload = generate_payload(levels, difficulties, args)
            validate_payload(payload, levels, difficulties)
            output_path.parent.mkdir(parents=True, exist_ok=True)
            with tempfile.NamedTemporaryFile(
                "w",
                encoding="utf-8",
                dir=output_path.parent,
                prefix="composite_levels_",
                suffix=".json",
                delete=False,
            ) as temporary:
                json.dump(payload, temporary, ensure_ascii=False, separators=(",", ":"))
                temporary.write("\n")
                temporary_path = Path(temporary.name)
            temporary_path.replace(output_path)
        print(
            f"OFFLINE COMPOSITE DATA OK: {len(payload['entries'])} entries, "
            f"{len(levels)} levels, {','.join(difficulties)}"
        )
        return 0
    except (OSError, ValueError, GenerationError, json.JSONDecodeError) as error:
        print(f"OFFLINE COMPOSITE DATA FAILED: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
