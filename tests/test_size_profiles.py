import pytest

from engine.measurements import DEFAULT_SKIRT_SIZE_CHART, SizeChart, SizeProfile
from engine.measurements.body import BodyMeasurements


def test_default_size_chart_has_expected_codes() -> None:
    assert DEFAULT_SKIRT_SIZE_CHART.list_codes() == ["XS", "S", "M", "L", "XL"]


def test_get_size_profile_returns_m() -> None:
    profile = DEFAULT_SKIRT_SIZE_CHART.get("m")

    assert profile.code == "M"
    assert profile.waist == 72.0
    assert profile.hip == 98.0


def test_size_profile_to_body_measurements() -> None:
    profile = DEFAULT_SKIRT_SIZE_CHART.get("M")
    measurements = profile.to_body_measurements(skirt_length=60)

    assert isinstance(measurements, BodyMeasurements)
    assert measurements.unit == "cm"
    assert measurements.waist == 72.0
    assert measurements.hip == 98.0
    assert measurements.skirt_length == 60


def test_size_profile_rejects_non_cm() -> None:
    with pytest.raises(ValueError, match="cm"):
        SizeProfile(code="BAD", label="Bad", waist=70, hip=90, unit="mm")


def test_size_chart_rejects_duplicate_codes() -> None:
    with pytest.raises(ValueError, match="duplicados"):
        SizeChart(
            name="Duplicada",
            profiles=(
                SizeProfile(code="M", label="M1", waist=72, hip=98),
                SizeProfile(code="M", label="M2", waist=74, hip=100),
            ),
        )


def test_unknown_size_raises_key_error() -> None:
    with pytest.raises(KeyError):
        DEFAULT_SKIRT_SIZE_CHART.get("XXL")
