"""Modelos de medidas corporales para patronaje."""

from __future__ import annotations

from pydantic import BaseModel, Field


class BodyMeasurements(BaseModel):
    """Medidas base en centimetros."""

    pecho: float = Field(gt=0)
    cintura: float = Field(gt=0)
    cadera: float = Field(gt=0)
    largo_falda: float | None = Field(default=None, gt=0)
    largo_espalda: float | None = Field(default=None, gt=0)
