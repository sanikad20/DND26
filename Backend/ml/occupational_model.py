from dataclasses import dataclass

import joblib
import numpy as np

from core.config import settings
from schemas.occupational import OccupationalAnswers


@dataclass(frozen=True)
class OccupationalModelOutput:
    risk_level: str
    base_score: float


class OccupationalStressModel:
    _bucket_midpoint = {"Low": 17, "Moderate": 50, "High": 83}

    def __init__(self):
        self._model = joblib.load(settings.occupational_model_path)
        self._scaler = joblib.load(settings.occupational_scaler_path)
        self._feature_anchors = joblib.load(
            settings.occupational_feature_anchors_path
        )
        self._feature_cols = joblib.load(settings.occupational_feature_cols_path)

    @property
    def model_version(self) -> str:
        return settings.occupational_model_version

    def predict(self, answers: OccupationalAnswers) -> OccupationalModelOutput:
        x_raw = np.array(
            [
                [
                    self._likert_to_dcs_eri(
                        self._likert_value_for_feature(answers, feature),
                        feature,
                    )
                    for feature in self._feature_cols
                ]
            ]
        )
        x_scaled = self._scaler.transform(x_raw)

        predicted_class = self._model.predict(x_scaled)[0]
        proba = dict(zip(self._model.classes_, self._model.predict_proba(x_scaled)[0]))
        base_score = sum(
            proba[class_name] * self._bucket_midpoint[class_name]
            for class_name in proba
        )

        return OccupationalModelOutput(
            risk_level=predicted_class,
            base_score=max(0.0, min(100.0, base_score)),
        )

    def _likert_to_dcs_eri(self, value: int, feature: str) -> float:
        p5, p25, p50, p75, p95 = self._feature_anchors[feature]
        return float(np.interp(value, [1, 2, 3, 4, 5], [p5, p25, p50, p75, p95]))

    @staticmethod
    def _likert_value_for_feature(
        answers: OccupationalAnswers,
        feature: str,
    ) -> int:
        values = {
            "demandmedia": answers.demand,
            "controlmedia": answers.control,
            "supportmedia": answers.support,
            "effortmedia": answers.effort,
            "rewardmedia": answers.reward,
        }
        return values[feature]
