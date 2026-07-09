#!/usr/bin/env python3
"""Generate bundled offline trivia JSON from Wikidata.

This script is a developer tool only. It queries Wikidata at build/content time,
then writes static JSON files that the app bundles and loads offline.
"""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import random
import time
import urllib.parse
import urllib.request
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / "TriviaAlarm" / "Resources"
ENDPOINT = "https://query.wikidata.org/sparql"
USER_AGENT = "Alarm-Trivia/1.0 (offline bundled trivia generator)"


CATEGORIES = {
    "general": "General",
    "science": "Science",
    "history": "History",
    "geography": "Geography",
    "sports": "Sports",
    "entertainment": "Entertainment",
}


@dataclass(frozen=True)
class RawQuestion:
    question: str
    correct: str
    distractor_pool: tuple[str, ...]
    category: str
    difficulty: str
    source_key: str


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target-per-category", type=int, default=250)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--delay", type=float, default=0.25)
    args = parser.parse_args()

    random.seed(args.seed)
    generators = {
        "general": general_questions,
        "science": science_questions,
        "history": history_questions,
        "geography": geography_questions,
        "sports": sports_questions,
        "entertainment": entertainment_questions,
    }

    for key, generator in generators.items():
        try:
            raw_questions = generator(args.delay)
        except Exception as error:
            print(f"{CATEGORIES[key]}: skipped because Wikidata query failed: {error}", flush=True)
            continue

        questions = materialize_questions(
            raw_questions,
            target=args.target_per_category,
            id_prefix=f"{key}_wd",
        )
        write_category_file(key, questions)
        print(f"{CATEGORIES[key]}: wrote {len(questions)} questions", flush=True)


def general_questions(delay: float) -> list[RawQuestion]:
    occupation_ids = [
        "Q36180",
        "Q33999",
        "Q82955",
        "Q901",
        "Q177220",
        "Q36834",
        "Q1028181",
        "Q43845",
    ]
    rows: list[dict[str, str]] = []
    for occupation_id in occupation_ids:
        rows.extend(
            sparql(
                f"""
                SELECT ?person ?personLabel ?occupationLabel ?countryLabel ?birth WHERE {{
                  ?person wdt:P106 wd:{occupation_id};
                          wdt:P27 ?country;
                          wdt:P569 ?birth.
                  BIND(wd:{occupation_id} AS ?occupation)
                  SERVICE wikibase:label {{ bd:serviceParam wikibase:language "en". }}
                }}
                LIMIT 100
                """,
                delay,
            )
        )
    occupations = tuple(unique(row["occupationLabel"] for row in rows))
    countries = tuple(unique(row["countryLabel"] for row in rows))
    questions: list[RawQuestion] = []

    for row in rows:
        person = row["personLabel"]
        questions.append(
            RawQuestion(
                question=f"What was {person} known for?",
                correct=row["occupationLabel"],
                distractor_pool=occupations,
                category="General",
                difficulty="Medium",
                source_key=f"{row['person']}:occupation",
            )
        )
        questions.append(
            RawQuestion(
                question=f"Which country is {person} associated with by citizenship?",
                correct=row["countryLabel"],
                distractor_pool=countries,
                category="General",
                difficulty="Medium",
                source_key=f"{row['person']}:country",
            )
        )

        year = year_from_wikidata_time(row.get("birth", ""))
        if year:
            years = year_distractors(year, spread=30)
            questions.append(
                RawQuestion(
                    question=f"In what year was {person} born?",
                    correct=str(year),
                    distractor_pool=years,
                    category="General",
                    difficulty="Hard",
                    source_key=f"{row['person']}:birth",
                )
            )

    return questions


def science_questions(delay: float) -> list[RawQuestion]:
    rows = sparql(
        """
        SELECT ?element ?elementLabel ?symbol ?atomicNumber WHERE {
          ?element wdt:P31 wd:Q11344;
                   wdt:P246 ?symbol;
                   wdt:P1086 ?atomicNumber.
          SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
        }
        LIMIT 200
        """,
        delay,
    )
    symbols = tuple(unique(row["symbol"] for row in rows))
    element_names = tuple(unique(row["elementLabel"] for row in rows))
    atomic_numbers = tuple(unique(row["atomicNumber"] for row in rows))
    questions: list[RawQuestion] = []

    for row in rows:
        element = row["elementLabel"]
        questions.append(
            RawQuestion(
                question=f"What is the chemical symbol for {element}?",
                correct=row["symbol"],
                distractor_pool=symbols,
                category="Science",
                difficulty="Medium",
                source_key=f"{row['element']}:symbol",
            )
        )
        questions.append(
            RawQuestion(
                question=f"Which element has the chemical symbol {row['symbol']}?",
                correct=element,
                distractor_pool=element_names,
                category="Science",
                difficulty="Medium",
                source_key=f"{row['element']}:name",
            )
        )
        questions.append(
            RawQuestion(
                question=f"What is the atomic number of {element}?",
                correct=row["atomicNumber"],
                distractor_pool=atomic_numbers,
                category="Science",
                difficulty="Hard",
                source_key=f"{row['element']}:atomic-number",
            )
        )

    return questions


def history_questions(delay: float) -> list[RawQuestion]:
    rows = sparql(
        """
        SELECT ?event ?eventLabel ?date WHERE {
          VALUES ?type { wd:Q178561 wd:Q198 wd:Q13418847 }
          ?event wdt:P31 ?type;
                 wdt:P585 ?date.
          SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
        }
        LIMIT 400
        """,
        delay,
    )
    questions: list[RawQuestion] = []
    for row in rows:
        year = year_from_wikidata_time(row.get("date", ""))
        if not year:
            continue
        questions.append(
            RawQuestion(
                question=f"In what year did {row['eventLabel']} happen?",
                correct=str(year),
                distractor_pool=year_distractors(year, spread=40),
                category="History",
                difficulty="Hard",
                source_key=f"{row['event']}:date",
            )
        )
    return questions


def geography_questions(delay: float) -> list[RawQuestion]:
    rows = sparql(
        """
        SELECT ?country ?countryLabel ?capitalLabel ?continentLabel ?currencyLabel WHERE {
          ?country wdt:P31 wd:Q6256;
                   wdt:P36 ?capital;
                   wdt:P30 ?continent;
                   wdt:P38 ?currency.
          SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
        }
        LIMIT 250
        """,
        delay,
    )
    capitals = tuple(unique(row["capitalLabel"] for row in rows))
    continents = tuple(unique(row["continentLabel"] for row in rows))
    currencies = tuple(unique(row["currencyLabel"] for row in rows))
    questions: list[RawQuestion] = []

    for row in rows:
        country = row["countryLabel"]
        questions.append(
            RawQuestion(
                question=f"What is the capital of {country}?",
                correct=row["capitalLabel"],
                distractor_pool=capitals,
                category="Geography",
                difficulty="Easy",
                source_key=f"{row['country']}:capital",
            )
        )
        questions.append(
            RawQuestion(
                question=f"On which continent is {country} located?",
                correct=row["continentLabel"],
                distractor_pool=continents,
                category="Geography",
                difficulty="Easy",
                source_key=f"{row['country']}:continent",
            )
        )
        questions.append(
            RawQuestion(
                question=f"What currency is used in {country}?",
                correct=row["currencyLabel"],
                distractor_pool=currencies,
                category="Geography",
                difficulty="Medium",
                source_key=f"{row['country']}:currency",
            )
        )

    return questions


def sports_questions(delay: float) -> list[RawQuestion]:
    sport_ids = [
        "Q2736",
        "Q5372",
        "Q847",
        "Q5369",
        "Q5377",
        "Q542",
        "Q108429",
        "Q31920",
    ]
    rows: list[dict[str, str]] = []
    for sport_id in sport_ids:
        rows.extend(
            sparql(
                f"""
                SELECT ?person ?personLabel ?sportLabel ?countryLabel WHERE {{
                  ?person wdt:P641 wd:{sport_id};
                          wdt:P27 ?country.
                  BIND(wd:{sport_id} AS ?sport)
                  SERVICE wikibase:label {{ bd:serviceParam wikibase:language "en". }}
                }}
                LIMIT 100
                """,
                delay,
            )
        )
    sports = tuple(unique(row["sportLabel"] for row in rows))
    countries = tuple(unique(row["countryLabel"] for row in rows))
    questions: list[RawQuestion] = []

    for row in rows:
        person = row["personLabel"]
        questions.append(
            RawQuestion(
                question=f"Which sport is {person} associated with?",
                correct=row["sportLabel"],
                distractor_pool=sports,
                category="Sports",
                difficulty="Medium",
                source_key=f"{row['person']}:sport",
            )
        )
        questions.append(
            RawQuestion(
                question=f"Which country did {person} represent or hold citizenship with?",
                correct=row["countryLabel"],
                distractor_pool=countries,
                category="Sports",
                difficulty="Hard",
                source_key=f"{row['person']}:country",
            )
        )

    return questions


def entertainment_questions(delay: float) -> list[RawQuestion]:
    rows = sparql(
        """
        SELECT ?film ?filmLabel ?directorLabel ?date WHERE {
          ?film wdt:P31 wd:Q11424;
                wdt:P57 ?director;
                wdt:P577 ?date.
          SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
        }
        LIMIT 600
        """,
        delay,
    )
    directors = tuple(unique(row["directorLabel"] for row in rows))
    questions: list[RawQuestion] = []

    for row in rows:
        film = row["filmLabel"]
        questions.append(
            RawQuestion(
                question=f"Who directed {film}?",
                correct=row["directorLabel"],
                distractor_pool=directors,
                category="Entertainment",
                difficulty="Medium",
                source_key=f"{row['film']}:director",
            )
        )
        year = year_from_wikidata_time(row.get("date", ""))
        if year:
            questions.append(
                RawQuestion(
                    question=f"In what year was {film} first released?",
                    correct=str(year),
                    distractor_pool=year_distractors(year, spread=25),
                    category="Entertainment",
                    difficulty="Hard",
                    source_key=f"{row['film']}:release-year",
                )
            )

    return questions


def sparql(query: str, delay: float) -> list[dict[str, str]]:
    time.sleep(delay)
    print("Querying Wikidata...", flush=True)
    params = urllib.parse.urlencode({"query": query, "format": "json"})
    request = urllib.request.Request(
        f"{ENDPOINT}?{params}",
        headers={
            "Accept": "application/sparql-results+json",
            "User-Agent": USER_AGENT,
        },
    )
    with urllib.request.urlopen(request, timeout=25) as response:
        payload = json.loads(response.read().decode("utf-8"))

    rows: list[dict[str, str]] = []
    for binding in payload["results"]["bindings"]:
        rows.append({key: value["value"] for key, value in binding.items()})
    print(f"Received {len(rows)} Wikidata rows", flush=True)
    return rows


def materialize_questions(raw_questions: list[RawQuestion], target: int, id_prefix: str) -> list[dict]:
    random.shuffle(raw_questions)
    questions: list[dict] = []
    seen_prompts = set()

    for raw in raw_questions:
        if len(questions) >= target:
            break
        prompt = clean_text(raw.question)
        correct = clean_text(raw.correct)
        if not prompt or not correct or prompt in seen_prompts:
            continue

        distractors = [
            clean_text(answer)
            for answer in raw.distractor_pool
            if clean_text(answer) and clean_text(answer) != correct
        ]
        distractors = unique(distractors)
        if len(distractors) < 3:
            continue

        answers = random.sample(distractors, 3) + [correct]
        random.shuffle(answers)
        correct_index = answers.index(correct)
        question_id = stable_id(id_prefix, raw.source_key, prompt)
        questions.append(
            {
                "id": question_id,
                "question": prompt,
                "answers": answers,
                "correctIndex": correct_index,
                "category": raw.category,
                "difficulty": raw.difficulty,
            }
        )
        seen_prompts.add(prompt)

    return sorted(questions, key=lambda question: question["id"])


def write_category_file(key: str, generated_questions: list[dict]) -> None:
    path = RESOURCES / f"trivia_{key}.json"
    existing = json.loads(path.read_text()) if path.exists() else []
    merged = {question["id"]: question for question in existing}
    merged.update({question["id"]: question for question in generated_questions})
    ordered = sorted(merged.values(), key=lambda question: question["id"])
    path.write_text(json.dumps(ordered, indent=2, ensure_ascii=False) + "\n")


def stable_id(prefix: str, source_key: str, prompt: str) -> str:
    digest = hashlib.sha1(f"{source_key}:{prompt}".encode("utf-8")).hexdigest()[:10]
    return f"{prefix}_{digest}"


def clean_text(value: str) -> str:
    return " ".join(html.unescape(value).replace("_", " ").split())


def unique(values) -> list[str]:
    seen = set()
    result = []
    for value in values:
        value = clean_text(str(value))
        if value and value not in seen:
            seen.add(value)
            result.append(value)
    return result


def year_from_wikidata_time(value: str) -> int | None:
    if not value:
        return None
    try:
        return int(value[:4])
    except ValueError:
        if value.startswith("-"):
            return None
        return None


def year_distractors(year: int, spread: int) -> tuple[str, ...]:
    candidates = set()
    for offset in range(-spread, spread + 1):
        if offset != 0:
            candidates.add(str(year + offset))
    return tuple(sorted(candidates))


if __name__ == "__main__":
    main()
