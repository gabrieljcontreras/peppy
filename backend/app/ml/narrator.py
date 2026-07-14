"""Claude narrative layer with wholesale fallback to deterministic rule text."""

import json
import logging
from typing import Optional, Sequence

import anthropic

from app.config import Settings, get_settings
from app.ml.insights_engine import GeneratedInsight

logger = logging.getLogger(__name__)

_GUARDRAILS = (
    "You write short, warm, plain-English health observations for the peppy app. "
    "Repeat numbers exactly as given in the input — never invent, recompute, or round them "
    "differently. Never give medical advice or dosing instructions; at most suggest discussing "
    "with a healthcare provider. Sentence case, no exclamation marks, no emoji, second person "
    "('you')."
)

_SUMMARY_SCHEMA = {
    "type": "object",
    "properties": {
        "narrative": {"type": "string", "minLength": 1},
        "what_to_watch": {
            "type": "array",
            "maxItems": 3,
            "items": {
                "type": "object",
                "properties": {
                    "title": {"type": "string", "minLength": 1},
                    "detail": {"type": "string", "minLength": 1},
                },
                "required": ["title", "detail"],
                "additionalProperties": False,
            },
        },
        "provider_questions": {
            "type": "array",
            "maxItems": 3,
            "items": {"type": "string", "minLength": 1},
        },
    },
    "required": ["narrative", "what_to_watch", "provider_questions"],
    "additionalProperties": False,
}


def _enrich_schema(candidate_count: int) -> dict:
    return {
        "type": "object",
        "properties": {
            "descriptions": {
                "type": "array",
                "minItems": candidate_count,
                "maxItems": candidate_count,
                "items": {"type": "string", "minLength": 1},
            }
        },
        "required": ["descriptions"],
        "additionalProperties": False,
    }


def _nonempty_string(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _valid_summary_payload(payload: object) -> bool:
    if not isinstance(payload, dict) or set(payload) != {
        "narrative",
        "what_to_watch",
        "provider_questions",
    }:
        return False
    if not _nonempty_string(payload["narrative"]):
        return False

    watch_items = payload["what_to_watch"]
    if not isinstance(watch_items, list) or len(watch_items) > 3:
        return False
    for item in watch_items:
        if (
            not isinstance(item, dict)
            or set(item) != {"title", "detail"}
            or not _nonempty_string(item["title"])
            or not _nonempty_string(item["detail"])
        ):
            return False

    questions = payload["provider_questions"]
    return (
        isinstance(questions, list)
        and len(questions) <= 3
        and all(_nonempty_string(question) for question in questions)
    )


class Narrator:
    def __init__(
        self,
        settings: Optional[Settings] = None,
        client: Optional[anthropic.AsyncAnthropic] = None,
    ):
        self._settings = settings or get_settings()
        self._client = client
        if self._client is None and self._settings.anthropic_api_key:
            self._client = anthropic.AsyncAnthropic(api_key=self._settings.anthropic_api_key)

    @property
    def enabled(self) -> bool:
        return bool(self._settings.anthropic_api_key and self._client is not None)

    async def enrich_insight_descriptions(
        self,
        candidates: Sequence[GeneratedInsight],
        snapshot: dict,
    ) -> Optional[list[str]]:
        if not self.enabled or not candidates:
            return None
        try:
            findings = [
                {
                    "title": candidate.title,
                    "template_description": candidate.description,
                    "explanation": candidate.explanation,
                    "supporting_data": (
                        json.loads(candidate.supporting_data) if candidate.supporting_data else None
                    ),
                }
                for candidate in candidates
            ]
            prompt = (
                "Rewrite each finding's description as one or two plain-English sentences "
                "(the 'observation' a user reads on a card). Return exactly "
                f"{len(candidates)} descriptions in the same order.\n\n"
                f"FINDINGS:\n{json.dumps(findings, indent=2)}\n\n"
                "USER DATA SNAPSHOT (context only — numbers come from FINDINGS):\n"
                f"{json.dumps(snapshot, indent=2)}"
            )
            assert self._client is not None
            response = await self._client.messages.create(
                model=self._settings.insight_narrative_model,
                max_tokens=2048,
                system=_GUARDRAILS,
                output_config={
                    "format": {
                        "type": "json_schema",
                        "schema": _enrich_schema(len(candidates)),
                    }
                },
                messages=[{"role": "user", "content": prompt}],
            )
            if response.stop_reason != "end_turn":
                return None
            text = next(block.text for block in response.content if block.type == "text")
            payload = json.loads(text)
            if not isinstance(payload, dict) or set(payload) != {"descriptions"}:
                return None
            descriptions = payload["descriptions"]
            if (
                not isinstance(descriptions, list)
                or len(descriptions) != len(candidates)
                or not all(
                    isinstance(description, str) and description.strip()
                    for description in descriptions
                )
            ):
                return None
            return descriptions
        except Exception:
            logger.warning("narrator: enrichment failed, falling back", exc_info=True)
            return None

    async def write_summary_narrative(
        self,
        stats: dict,
        snapshot: dict,
    ) -> Optional[dict]:
        if not self.enabled:
            return None
        try:
            prompt = (
                "Write the AI weekly summary for this user.\n"
                "- narrative: one encouraging sentence about the week.\n"
                "- what_to_watch: up to 3 items drawn ONLY from patterns visible in the "
                "stats/snapshot (rephrase, never invent numbers).\n"
                "- provider_questions: up to 3 questions the user could ask their healthcare "
                "provider.\n\n"
                f"WEEK STATS (authoritative numbers):\n{json.dumps(stats, indent=2)}\n\n"
                f"USER DATA SNAPSHOT:\n{json.dumps(snapshot, indent=2)}"
            )
            assert self._client is not None
            response = await self._client.messages.create(
                model=self._settings.summary_narrative_model,
                max_tokens=2048,
                system=_GUARDRAILS,
                output_config={"format": {"type": "json_schema", "schema": _SUMMARY_SCHEMA}},
                messages=[{"role": "user", "content": prompt}],
            )
            if response.stop_reason != "end_turn":
                return None
            text = next(block.text for block in response.content if block.type == "text")
            payload = json.loads(text)
            if not _valid_summary_payload(payload):
                return None
            return payload
        except Exception:
            logger.warning("narrator: summary narrative failed, falling back", exc_info=True)
            return None
