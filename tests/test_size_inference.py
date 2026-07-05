import pytest

from engine.measurements.body import BodyMeasurements
from engine.measurements.size_inference import (
    SizeInferenceResult,
    infer_size_from_measurements,
)


def test_infer_exact_m_size() -> None:
    result = infer_size_from_measurements(waist=72, hip=98)

    assert isinstance(result, SizeInferenceResult)
    assert result.recommended_size == "M"
    assert result.score == 0
    assert result.difference_for("waist").difference == 0
    assert result.difference_for("hip").difference == 0


def test_infer_near_m_size() -> None:
    result = infer_size_from_measurements(waist=73, hip=99)

    assert result.recommended_size == "M"
    assert result.difference_for("waist").difference == 1
    assert result.difference_for("hip").difference == 1


def test_infer_l_size() -> None:
    result = infer_size_from_measurements(waist=79, hip=105)

    assert result.recommended_size == "L"


def test_infer_from_body_measurements() -> None:
    measurements = BodyMeasurements(waist=84, hip=110, skirt_length=60)
    result = infer_size_from_measurements(measurements=measurements)

    assert result.recommended_size == "XL"


def test_between_sizes_detection() -> None:
    result = infer_size_from_measurements(waist=75, hip=101, between_threshold_cm=2.0)

    assert result.recommended_size in {"M", "L"}
    assert result.is_between_sizes


def test_inference_rejects_missing_values() -> None:
    with pytest.raises(ValueError, match="waist y hip"):
        infer_size_from_measurements()


def test_inference_rejects_invalid_values() -> None:
    with pytest.raises(ValueError, match="waist"):
        infer_size_from_measurements(waist=0, hip=98)

    with pytest.raises(ValueError, match="hip"):
        infer_size_from_measurements(waist=72, hip=0)
