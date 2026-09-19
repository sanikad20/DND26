from functools import lru_cache

from ml.occupational_model import OccupationalStressModel


@lru_cache(maxsize=1)
def get_occupational_model() -> OccupationalStressModel:
    return OccupationalStressModel()
