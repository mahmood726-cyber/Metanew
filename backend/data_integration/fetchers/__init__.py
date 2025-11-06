"""Data Fetchers for External APIs"""

from .who_gho import WHOGHOFetcher
from .world_bank import WorldBankFetcher

__all__ = ["WHOGHOFetcher", "WorldBankFetcher"]
