from __future__ import annotations

import sys
from pathlib import Path

from loguru import logger


def configure_logging(project_root: Path | None = None) -> None:
    """Configura logging operacional del motor.

    Unidad de retencion corregida:
    - Loguru no acepta retention="10 files".
    - Se usa retention=10 para conservar hasta 10 archivos rotados.
    """

    root = project_root or Path.cwd()
    logs_dir = root / "logs"
    logs_dir.mkdir(parents=True, exist_ok=True)

    logger.remove()

    logger.add(
        logs_dir / "motor_patronaje.log",
        rotation="1 MB",
        retention=10,
        level="INFO",
        encoding="utf-8",
        enqueue=False,
        backtrace=False,
        diagnose=False,
    )

    logger.add(
        sys.stdout,
        level="INFO",
        enqueue=False,
        backtrace=False,
        diagnose=False,
    )
