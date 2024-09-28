from __future__ import annotations

import logging
from typing import Optional, Union

import pandas as pd
import pydantic
import pytest
from unittest import mock

logger = logging.getLogger(__name__)

CONSTANT = (10, 10. + 40)

round(20)


class Config(pydantic.BaseSettings):
    __abstract__ = "hein?"

    id: Optional[Union[int, float, str]] = 1
    two: Optional[pd.Timestamp] = None
    ok: bool = pydantic.Field(...)

    @pydantic.validator("ok")
    def _sanitize_ok(cls, v):
        try:
            return v
        except ValueError:
            return "ok"

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
        lambda x: x
        return


@pytest.mark.parametrize("value", [1, 2, 3])
def test_highlight(value):
    """Docstring really

    Note:
        ..longer
    """
    assert True


Config().classicmethod()

# Can't query it, parser is wrong
read_qry = target_tsdata = joined_conditions = mock.MagicMock()
read_sql = f"""
    SELECT ts, {read_qry.tsmeta.column_name}::double precision as "{read_qry.tsmeta.tablename}"
    FROM {target_tsdata}
    {joined_conditions}
    ORDER BY ts ASC
"""

isinstance(read_sql, int | bool | float | str)


interp = f"{test_highlight()}"


class TypeHintBinaryOperator:
    def fna(self) -> list[str]:
        return []

    def fnb(self) -> list[dict[str, None]]:
        return []

    def fnc(self) -> str | None: ...

    def fnd(self) -> list[str] | None: ...

    def fne(self) -> str | int: ...

    def fn2(self) -> list[dict[str, str]] | None: ...

    def fn3(self) -> None | list[dict[str, str]] | None: ...

    def fn4(self) -> None | list[dict[str, str]]: ...
