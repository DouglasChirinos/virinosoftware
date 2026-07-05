"""Serializable garment definitions for the initial patternmaking DSL."""

from .definition import (
    SerializableGarmentDefinition,
    SerializableLineDefinition,
    SerializableMeasurementDefinition,
    SerializablePieceDefinition,
    SerializablePointDefinition,
)
from .loader import load_garment_definition_from_dict, load_garment_definition_from_json
from .formula import FormulaEvaluationError, evaluate_formula, resolve_formula_value
from .geometry import (
    GeneratedSerializableLine,
    GeneratedSerializablePattern,
    GeneratedSerializablePiece,
    GeneratedSerializablePoint,
    SerializableGeometryGenerationError,
    build_formula_context,
    generate_geometry_from_definition,
)
from .validation import SerializableGarmentValidationError
from .catalog_quality import (
    CatalogDefinitionReport,
    CatalogQualityReport,
    SerializableCatalogQualityError,
    discover_garment_definition_files,
    validate_serializable_catalog,
    validate_serializable_catalog_files,
)
from .semantic_validation import (
    GarmentSemanticReport,
    PieceSemanticReport,
    SerializableGarmentSemanticValidationError,
    validate_garment_definition_file,
    validate_garment_definition_files,
    validate_garment_definition_semantics,
)

__all__ = [
    "SerializableGarmentDefinition",
    "SerializableLineDefinition",
    "SerializableMeasurementDefinition",
    "SerializablePieceDefinition",
    "SerializablePointDefinition",
    "SerializableGarmentValidationError",
    "load_garment_definition_from_dict",
    "load_garment_definition_from_json",
    "FormulaEvaluationError",
    "evaluate_formula",
    "resolve_formula_value",
    "SerializableGeometryGenerationError",
    "GeneratedSerializablePoint",
    "GeneratedSerializableLine",
    "GeneratedSerializablePiece",
    "GeneratedSerializablePattern",
    "build_formula_context",
    "generate_geometry_from_definition",
    "SerializableGarmentSemanticValidationError",
    "PieceSemanticReport",
    "GarmentSemanticReport",
    "validate_garment_definition_semantics",
    "validate_garment_definition_file",
    "validate_garment_definition_files",
    "SerializableCatalogQualityError",
    "CatalogDefinitionReport",
    "CatalogQualityReport",
    "discover_garment_definition_files",
    "validate_serializable_catalog",
    "validate_serializable_catalog_files",
]
