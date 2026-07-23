#!/usr/bin/env python3
"""Validate the offline trivia bank before it is bundled."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path


EXPECTED_CATEGORIES = {
    "General",
    "Science",
    "History",
    "Geography",
    "Entertainment",
    "Sports",
}


def normalize(value: str) -> str:
    return " ".join(value.casefold().split())


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("path", nargs="?", default="TriviaAlarm/Resources/trivia_fun.json")
    parser.add_argument("--per-category", type=int, default=300)
    args = parser.parse_args()

    path = Path(args.path)
    try:
        questions = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError) as error:
        raise SystemExit(f"Could not read {path}: {error}")

    if not isinstance(questions, list):
        raise SystemExit("Trivia bank must contain a JSON array.")

    errors: list[str] = []
    ids: set[str] = set()
    prompts: set[str] = set()
    answer_sets: set[tuple[str, ...]] = set()
    categories = Counter()

    for index, question in enumerate(questions):
        location = f"question {index + 1}"
        if not isinstance(question, dict):
            errors.append(f"{location}: expected an object")
            continue

        question_id = question.get("id")
        prompt = question.get("question")
        answers = question.get("answers")
        correct_index = question.get("correctIndex")
        category = question.get("category")
        difficulty = question.get("difficulty")

        if not isinstance(question_id, str) or not question_id.strip():
            errors.append(f"{location}: missing id")
        elif question_id in ids:
            errors.append(f"{location}: duplicate id '{question_id}'")
        else:
            ids.add(question_id)

        if not isinstance(prompt, str) or not prompt.strip():
            errors.append(f"{location}: missing question text")
        else:
            normalized_prompt = normalize(prompt)
            if normalized_prompt in prompts:
                errors.append(f"{location}: duplicate question text '{prompt}'")
            prompts.add(normalized_prompt)

        if not isinstance(answers, list) or len(answers) != 4:
            errors.append(f"{location}: must have exactly four answers")
        elif any(not isinstance(answer, str) or not answer.strip() for answer in answers):
            errors.append(f"{location}: answers must be non-empty strings")
        elif len({normalize(answer) for answer in answers}) != 4:
            errors.append(f"{location}: answers must be unique")
        else:
            answer_key = tuple(sorted(normalize(answer) for answer in answers))
            if answer_key in answer_sets:
                errors.append(f"{location}: duplicate answer set")
            answer_sets.add(answer_key)

        if not isinstance(correct_index, int) or not isinstance(answers, list) or not 0 <= correct_index < len(answers):
            errors.append(f"{location}: invalid correctIndex")

        if category not in EXPECTED_CATEGORIES:
            errors.append(f"{location}: unsupported category '{category}'")
        else:
            categories[category] += 1

        if difficulty not in {"Easy", "Medium", "Hard"}:
            errors.append(f"{location}: unsupported difficulty '{difficulty}'")

    missing_categories = EXPECTED_CATEGORIES - set(categories)
    if missing_categories:
        errors.append(f"missing categories: {', '.join(sorted(missing_categories))}")

    wrong_counts = {
        category: count
        for category, count in sorted(categories.items())
        if count != args.per_category
    }
    if wrong_counts:
        errors.append(f"expected {args.per_category} per category, got {wrong_counts}")

    if errors:
        print(f"Validation failed with {len(errors)} issue(s):")
        print("\n".join(f"- {error}" for error in errors[:50]))
        if len(errors) > 50:
            print(f"- ...and {len(errors) - 50} more")
        return 1

    print(f"Validated {len(questions)} unique questions: {dict(categories)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
