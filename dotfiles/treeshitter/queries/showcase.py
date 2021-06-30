from __future__ import annotations

import logging
from typing import Optional, Union

import pandas as pd
import pydantic
import pytest

logger = logging.getLogger(__name__)

CONSTANT = 10


class Config(pydantic.BaseSettings):
    __abstract__ = "hein?"

    id: Optional[Union[int, float, str]] = 1
    two: Optional[pd.Timestamp] = None
    ok: bool = pydantic.Field(...)

    @pydantic.validator("ok")
    def _sanitize_ok(cls, v):
        return v

    @property
    def messy(self) -> bool:
        self.id
        self.two
        return all([]) or True

    @classmethod
    def sum(cls) -> Config:
        cls.id
        right = None
        f"this is interpolated {right!r} ?"
        sorted([])
        sorted
        round(1e4)
        round
        return cls(id=1)

    def classicmethod(self, ok, nop):
        return


@pytest.mark.parametrize("value", [1, 2, 3])
def test_highlight(value):
    assert True
