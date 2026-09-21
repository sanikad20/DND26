import os
from pathlib import Path


class Settings:
    backend_dir = Path(__file__).resolve().parents[1]

    environment = os.getenv("APP_ENV", "development")
    database_url = os.getenv("DATABASE_URL", "sqlite:///./users.db")
    cors_origins = [
        origin.strip()
        for origin in os.getenv("CORS_ORIGINS", "*").split(",")
        if origin.strip()
    ]
    firebase_service_account_json = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")
    firebase_service_account_json_base64 = os.getenv(
        "FIREBASE_SERVICE_ACCOUNT_JSON_BASE64"
    )
    firebase_project_id = os.getenv("FIREBASE_PROJECT_ID")

    occupational_model_version = "lr-day2-v1"
    occupational_model_path = backend_dir / "occupational_lr_model.pkl"
    occupational_scaler_path = backend_dir / "occupational_scaler.pkl"
    occupational_feature_anchors_path = (
        backend_dir / "occupational_feature_anchors.pkl"
    )
    occupational_feature_cols_path = backend_dir / "occupational_feature_cols.pkl"

    manual_feature_cols_path = backend_dir / "manual_feature_cols.pkl"
    burnout_scaler_path = backend_dir / "burnout_scaler.pkl"
    burnout_model_path = backend_dir / "best_burnout_model.pt"
    lstm_saved_model_path = backend_dir / "burnout_lstm_savedmodel"
    lstm_day_scaler_path = backend_dir / "lstm_day_scaler.pkl"
    lstm_today_scaler_path = backend_dir / "lstm_today_scaler.pkl"
    lstm_day_features_path = backend_dir / "lstm_day_features.pkl"
    lstm_today_features_path = backend_dir / "lstm_today_features.pkl"
    lstm_seq_len_path = backend_dir / "lstm_seq_len.pkl"


settings = Settings()
