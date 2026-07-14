import json
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

import pytest

from app.config import Settings
from app.ml.insights_engine import GeneratedInsight
from app.ml.narrator import Narrator
from app.models.insight import InsightSeverity, InsightType


def _candidate(title: str = "Weight trending down", supporting_data: str | None = None):
    return GeneratedInsight(
        type=InsightType.TREND,
        severity=InsightSeverity.INFO,
        title=title,
        description="template description",
        explanation="because data",
        confidence=0.7,
        supporting_data=supporting_data,
    )


def _fake_text_client(text: str, *, stop_reason: str = "end_turn"):
    block = SimpleNamespace(type="text", text=text, citations=None)
    response = SimpleNamespace(
        id="msg_test",
        type="message",
        role="assistant",
        model="test-model",
        content=[block],
        stop_reason=stop_reason,
        stop_sequence=None,
        usage=SimpleNamespace(input_tokens=10, output_tokens=10),
    )
    return SimpleNamespace(messages=SimpleNamespace(create=AsyncMock(return_value=response)))


def _fake_client(payload: dict, *, stop_reason: str = "end_turn"):
    return _fake_text_client(json.dumps(payload), stop_reason=stop_reason)


def _settings(**overrides):
    return Settings(anthropic_api_key="test-key", debug=True, **overrides)


def test_settings_pin_narrative_models():
    settings = Settings(debug=True)

    assert settings.anthropic_api_key == ""
    assert settings.insight_narrative_model == "claude-haiku-4-5"
    assert settings.summary_narrative_model == "claude-sonnet-5"


def test_configured_key_constructs_async_anthropic_client():
    client = _fake_client({"descriptions": ["unused"]})
    with patch(
        "app.ml.narrator.anthropic.AsyncAnthropic",
        return_value=client,
    ) as client_factory:
        narrator = Narrator(settings=_settings())

    assert narrator.enabled is True
    client_factory.assert_called_once_with(api_key="test-key")


@pytest.mark.asyncio
async def test_disabled_without_api_key_never_calls_injected_client():
    client = _fake_client({"descriptions": ["polished"]})
    narrator = Narrator(settings=Settings(debug=True), client=client)

    assert narrator.enabled is False
    assert await narrator.enrich_insight_descriptions([_candidate()], {}) is None
    client.messages.create.assert_not_awaited()


@pytest.mark.asyncio
async def test_enrich_returns_descriptions_in_order_with_haiku_structured_output():
    client = _fake_client(
        {"descriptions": ["Polished first observation.", "Polished second observation."]}
    )
    narrator = Narrator(settings=_settings(), client=client)
    candidates = [
        _candidate(
            "First finding",
            supporting_data=json.dumps([{"label": "Energy", "value": "2.0 / 10 avg"}]),
        ),
        _candidate("Second finding"),
    ]

    output = await narrator.enrich_insight_descriptions(
        candidates,
        {"window": {"start": "2026-06-01"}, "checkins": [{"notes": "user note"}]},
    )

    assert output == ["Polished first observation.", "Polished second observation."]
    kwargs = client.messages.create.await_args.kwargs
    assert kwargs["model"] == "claude-haiku-4-5"
    assert kwargs["max_tokens"] == 2048
    assert kwargs["output_config"]["format"]["type"] == "json_schema"
    schema = kwargs["output_config"]["format"]["schema"]
    assert schema["required"] == ["descriptions"]
    assert schema["properties"]["descriptions"]["minItems"] == 2
    assert schema["properties"]["descriptions"]["maxItems"] == 2
    assert schema["properties"]["descriptions"]["items"]["minLength"] == 1
    assert "effort" not in kwargs["output_config"]
    assert "temperature" not in kwargs
    assert "top_p" not in kwargs
    assert "First finding" in kwargs["messages"][0]["content"]
    assert "2.0 / 10 avg" in kwargs["messages"][0]["content"]
    assert "user note" in kwargs["messages"][0]["content"]


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "payload",
    [
        {"descriptions": ["only one"]},
        {"descriptions": ["valid", "   "]},
        {"descriptions": "not a list"},
        {"wrong_key": ["one", "two"]},
    ],
)
async def test_enrich_falls_back_on_response_shape_mismatch(payload):
    narrator = Narrator(settings=_settings(), client=_fake_client(payload))

    output = await narrator.enrich_insight_descriptions(
        [_candidate("first"), _candidate("second")],
        {},
    )

    assert output is None


@pytest.mark.asyncio
async def test_enrich_falls_back_on_api_error():
    client = SimpleNamespace(
        messages=SimpleNamespace(create=AsyncMock(side_effect=RuntimeError("provider unavailable")))
    )
    narrator = Narrator(settings=_settings(), client=client)

    assert await narrator.enrich_insight_descriptions([_candidate()], {}) is None


@pytest.mark.asyncio
async def test_enrich_falls_back_on_malformed_response_json():
    narrator = Narrator(
        settings=_settings(),
        client=_fake_text_client("not-json"),
    )

    assert await narrator.enrich_insight_descriptions([_candidate()], {}) is None


@pytest.mark.asyncio
async def test_enrich_falls_back_when_response_is_truncated():
    narrator = Narrator(
        settings=_settings(),
        client=_fake_client(
            {"descriptions": ["valid but incomplete"]},
            stop_reason="max_tokens",
        ),
    )

    assert await narrator.enrich_insight_descriptions([_candidate()], {}) is None


@pytest.mark.asyncio
async def test_enrich_falls_back_on_invalid_supporting_data_without_calling_api():
    client = _fake_client({"descriptions": ["unused"]})
    narrator = Narrator(settings=_settings(), client=client)

    output = await narrator.enrich_insight_descriptions(
        [_candidate(supporting_data="{not-json")],
        {},
    )

    assert output is None
    client.messages.create.assert_not_awaited()


@pytest.mark.asyncio
async def test_enrich_falls_back_on_non_serializable_snapshot_without_calling_api():
    client = _fake_client({"descriptions": ["unused"]})
    narrator = Narrator(settings=_settings(), client=client)

    output = await narrator.enrich_insight_descriptions(
        [_candidate()],
        {"invalid": object()},
    )

    assert output is None
    client.messages.create.assert_not_awaited()


@pytest.mark.asyncio
async def test_summary_uses_sonnet_structured_output_and_parses_payload():
    payload = {
        "narrative": "Your logged trend moved in a positive direction this week.",
        "what_to_watch": [
            {
                "title": "Nausea after dose day",
                "detail": "Logged after 3 of 4 dose days.",
            }
        ],
        "provider_questions": ["Is this nausea pattern expected?"],
    }
    client = _fake_client(payload)
    narrator = Narrator(settings=_settings(), client=client)

    output = await narrator.write_summary_narrative(
        {"weight_delta_kg": -1.0},
        {"window": {"start": "2026-06-01"}, "checkins": [{"notes": "felt well"}]},
    )

    assert output == payload
    kwargs = client.messages.create.await_args.kwargs
    assert kwargs["model"] == "claude-sonnet-5"
    assert kwargs["max_tokens"] == 2048
    assert kwargs["output_config"]["format"]["type"] == "json_schema"
    schema = kwargs["output_config"]["format"]["schema"]
    assert schema["additionalProperties"] is False
    assert schema["properties"]["narrative"]["minLength"] == 1
    assert schema["properties"]["what_to_watch"]["maxItems"] == 3
    assert "effort" not in kwargs["output_config"]
    assert "temperature" not in kwargs
    assert "top_p" not in kwargs
    assert '"weight_delta_kg": -1.0' in kwargs["messages"][0]["content"]
    assert "felt well" in kwargs["messages"][0]["content"]


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "payload",
    [
        {"what_to_watch": [], "provider_questions": []},
        {"narrative": "   ", "what_to_watch": [], "provider_questions": []},
        {"narrative": "Valid", "what_to_watch": "bad", "provider_questions": []},
        {
            "narrative": "Valid",
            "what_to_watch": [{"title": "Missing detail"}],
            "provider_questions": [],
        },
        {
            "narrative": "Valid",
            "what_to_watch": [{"title": "Valid", "detail": "   "}],
            "provider_questions": [],
        },
        {
            "narrative": "Valid",
            "what_to_watch": [],
            "provider_questions": [""],
        },
        {
            "narrative": "Valid",
            "what_to_watch": [],
            "provider_questions": [],
            "extra": "not allowed",
        },
        {
            "narrative": "Valid",
            "what_to_watch": [{"title": f"Item {index}", "detail": "Detail"} for index in range(4)],
            "provider_questions": [],
        },
        {
            "narrative": "Valid",
            "what_to_watch": [],
            "provider_questions": [f"Question {index}?" for index in range(4)],
        },
    ],
)
async def test_summary_falls_back_on_schema_invalid_payload(payload):
    narrator = Narrator(settings=_settings(), client=_fake_client(payload))

    assert await narrator.write_summary_narrative({}, {}) is None


@pytest.mark.asyncio
async def test_summary_falls_back_on_api_error():
    client = SimpleNamespace(
        messages=SimpleNamespace(create=AsyncMock(side_effect=RuntimeError("boom")))
    )
    narrator = Narrator(settings=_settings(), client=client)

    assert await narrator.write_summary_narrative({}, {}) is None


@pytest.mark.asyncio
async def test_summary_falls_back_on_malformed_json():
    narrator = Narrator(settings=_settings(), client=_fake_text_client("not-json"))

    assert await narrator.write_summary_narrative({}, {}) is None


@pytest.mark.asyncio
async def test_summary_falls_back_when_response_is_truncated():
    narrator = Narrator(
        settings=_settings(),
        client=_fake_client(
            {"narrative": "Incomplete", "what_to_watch": [], "provider_questions": []},
            stop_reason="max_tokens",
        ),
    )

    assert await narrator.write_summary_narrative({}, {}) is None


@pytest.mark.asyncio
async def test_summary_falls_back_on_non_serializable_input_without_calling_api():
    client = _fake_client({"narrative": "unused", "what_to_watch": [], "provider_questions": []})
    narrator = Narrator(settings=_settings(), client=client)

    output = await narrator.write_summary_narrative(
        {"invalid": object()},
        {},
    )

    assert output is None
    client.messages.create.assert_not_awaited()
