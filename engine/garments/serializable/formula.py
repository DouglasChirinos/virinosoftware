"""Safe formula interpreter for the serializable patternmaking DSL.

The interpreter evaluates arithmetic expressions such as:

- waist / 4
- hip / 4 + ease
- outseam

It intentionally avoids Python eval/exec. Only a small AST subset is allowed.
"""

from __future__ import annotations

import ast
from dataclasses import dataclass
from typing import Mapping


Number = int | float
FormulaValue = Number | str


class FormulaEvaluationError(ValueError):
    """Raised when a DSL formula cannot be evaluated safely."""


@dataclass(frozen=True)
class FormulaEvaluationResult:
    """Result of evaluating one formula expression."""

    expression: str
    value: float


_ALLOWED_BINARY_OPERATORS: tuple[type[ast.operator], ...] = (
    ast.Add,
    ast.Sub,
    ast.Mult,
    ast.Div,
)
_ALLOWED_UNARY_OPERATORS: tuple[type[ast.unaryop], ...] = (ast.UAdd, ast.USub)


def evaluate_formula(expression: str, variables: Mapping[str, Number]) -> float:
    """Evaluate a safe arithmetic formula using a variable context.

    Parameters
    ----------
    expression:
        Arithmetic DSL expression. Example: ``"hip / 4 + ease"``.
    variables:
        Mapping of allowed variable names to numeric values.

    Returns
    -------
    float
        Numeric result.

    Raises
    ------
    FormulaEvaluationError
        If the expression is unsafe, invalid, references unknown variables, or
        does not evaluate to a numeric value.
    """

    if not isinstance(expression, str) or not expression.strip():
        raise FormulaEvaluationError("formula expression must be a non-empty string")

    try:
        tree = ast.parse(expression, mode="eval")
    except SyntaxError as exc:
        raise FormulaEvaluationError(f"invalid formula syntax: {expression}") from exc

    value = _evaluate_node(tree.body, variables, expression)
    if not isinstance(value, (int, float)):
        raise FormulaEvaluationError(f"formula did not return a numeric value: {expression}")
    return float(value)


def resolve_formula_value(value: FormulaValue, variables: Mapping[str, Number]) -> float:
    """Resolve a numeric coordinate or formula string into a float."""

    if isinstance(value, bool):
        raise FormulaEvaluationError("boolean values are not valid formula numbers")
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        return evaluate_formula(value, variables)
    raise FormulaEvaluationError("formula value must be numeric or string expression")


def _evaluate_node(node: ast.AST, variables: Mapping[str, Number], expression: str) -> Number:
    if isinstance(node, ast.Constant):
        if isinstance(node.value, bool) or not isinstance(node.value, (int, float)):
            raise FormulaEvaluationError(f"invalid constant in formula: {expression}")
        return node.value

    if isinstance(node, ast.Name):
        if node.id not in variables:
            raise FormulaEvaluationError(f"unknown variable '{node.id}' in formula: {expression}")
        variable_value = variables[node.id]
        if isinstance(variable_value, bool) or not isinstance(variable_value, (int, float)):
            raise FormulaEvaluationError(f"variable '{node.id}' must be numeric")
        return variable_value

    if isinstance(node, ast.UnaryOp):
        if not isinstance(node.op, _ALLOWED_UNARY_OPERATORS):
            raise FormulaEvaluationError(f"unsupported unary operator in formula: {expression}")
        operand = _evaluate_node(node.operand, variables, expression)
        if isinstance(node.op, ast.USub):
            return -operand
        return +operand

    if isinstance(node, ast.BinOp):
        if not isinstance(node.op, _ALLOWED_BINARY_OPERATORS):
            raise FormulaEvaluationError(f"unsupported operator in formula: {expression}")
        left = _evaluate_node(node.left, variables, expression)
        right = _evaluate_node(node.right, variables, expression)
        if isinstance(node.op, ast.Add):
            return left + right
        if isinstance(node.op, ast.Sub):
            return left - right
        if isinstance(node.op, ast.Mult):
            return left * right
        if isinstance(node.op, ast.Div):
            if right == 0:
                raise FormulaEvaluationError(f"division by zero in formula: {expression}")
            return left / right

    raise FormulaEvaluationError(f"unsupported expression in formula: {expression}")
