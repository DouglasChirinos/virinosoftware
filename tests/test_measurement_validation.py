import pytest

from engine.measurements.body import BodyMeasurements
from engine.measurements.validation import MeasurementValidationError


def test_measurements_unit_is_cm() -> None:
    measurements = BodyMeasurements(waist=72, hip=98, skirt_length=60)
    assert measurements.unit == "cm"


def test_invalid_measurements_raise_domain_error() -> None:
    with pytest.raises(MeasurementValidationError):
        BodyMeasurements(waist=20, hip=98, skirt_length=60)


def test_reject_non_cm_unit() -> None:
    with pytest.raises(ValueError, match="cm"):
        BodyMeasurements(waist=72, hip=98, skirt_length=60, unit="mm")
