"""Regression tests for packaging/config consistency.

Guards two audit fixes:
  * pytest.ini must collect the whole suite (tests/py + backend), not just
    the 9 ETL tests -- otherwise the backend/api and backend/cache tests are
    silently skipped by a bare `pytest` run.
  * The pandas pin in backend/requirements.txt and backend/api/requirements.txt
    must not be mutually exclusive (previously >=2.2.0 vs ==2.1.3), or a fresh
    `pip install` resolves the two contexts to incompatible dependency trees.
"""
import configparser
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]


def _pandas_specs():
    specs = {}
    for rel in ("backend/requirements.txt", "backend/api/requirements.txt"):
        text = (REPO_ROOT / rel).read_text(encoding="utf-8")
        for line in text.splitlines():
            line = line.split("#", 1)[0].strip()
            m = re.match(r"^pandas\s*(==|>=|<=|~=|>|<)\s*([0-9][0-9.]*)", line)
            if m:
                specs[rel] = (m.group(1), tuple(int(p) for p in m.group(2).split(".")))
    return specs


def test_pytest_collects_full_suite():
    cfg = configparser.ConfigParser()
    cfg.read(REPO_ROOT / "pytest.ini")
    testpaths = cfg.get("pytest", "testpaths").split()
    assert "tests/py" in testpaths
    assert "backend" in testpaths, (
        "pytest.ini testpaths must include 'backend' so backend/api and "
        "backend/cache tests are collected by a bare `pytest` run"
    )


def test_pandas_pins_are_compatible():
    specs = _pandas_specs()
    assert "backend/requirements.txt" in specs
    assert "backend/api/requirements.txt" in specs
    lower_bounds = []
    exacts = []
    for op, ver in specs.values():
        if op == "==":
            exacts.append(ver)
        elif op == ">=":
            lower_bounds.append(ver)
    # An exact pin below any declared lower bound is a mutually exclusive conflict.
    for exact in exacts:
        for lb in lower_bounds:
            assert exact >= lb, (
                f"pandas exact pin {exact} conflicts with lower bound {lb} "
                "across the two requirements files"
            )
