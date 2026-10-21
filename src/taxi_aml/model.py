"""Pure logic: pandas + scikit-learn only (no Azure, no MLflow). Unit-tested locally."""

from __future__ import annotations

import numpy as np
import pandas as pd
from sklearn.ensemble import HistGradientBoostingRegressor
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from sklearn.model_selection import train_test_split

# Raw Azure Open Datasets column -> our name.
RAW_COLUMNS = {
    "lpepPickupDatetime": "pickup_ts",
    "tripDistance": "trip_distance",
    "passengerCount": "passenger_count",
    "fareAmount": "fare_amount",
}
FEATURES = ["trip_distance", "pickup_hour", "pickup_dow", "passenger_count"]
TARGET = "fare_amount"
CHAMPION_TAG = "champion"
# MLflow 3 saves sklearn models with skops, which rejects types it doesn't know. We train the
# model ourselves, so we trust exactly the one internal type HistGradientBoosting needs.
SKOPS_TRUSTED_TYPES = ["sklearn.ensemble._hist_gradient_boosting.predictor.TreePredictor"]

# Data tests: a row must pass all of these to be used.
RULES = {
    "valid_fare": lambda d: d["fare_amount"].between(2.5, 200),
    "valid_distance": lambda d: d["trip_distance"].between(0.1, 100),
    "valid_passengers": lambda d: d["passenger_count"].between(1, 6),
}


def clean(raw: pd.DataFrame) -> tuple[pd.DataFrame, dict[str, int]]:
    """Rename columns, apply the data-test rules. Returns (clean rows, how many rows each rule dropped)."""
    missing = set(RAW_COLUMNS) - set(raw.columns)
    if missing:
        raise ValueError(f"Data test failed: missing columns {sorted(missing)}")
    df = raw[list(RAW_COLUMNS)].rename(columns=RAW_COLUMNS).dropna()
    report = {"rows_in": len(raw), "rows_null": len(raw) - len(df)}
    keep = pd.Series(True, index=df.index)
    for name, rule in RULES.items():
        ok = rule(df)
        report[f"dropped_{name}"] = int((~ok).sum())
        keep &= ok
    df = df[keep]
    report["rows_out"] = len(df)
    return df, report


def check_quality(report: dict[str, int], max_bad_share: float, min_rows: int) -> None:
    """Fail the pipeline when the data is too bad to train on."""
    bad_share = 1 - report["rows_out"] / max(report["rows_in"], 1)
    if bad_share > max_bad_share:
        raise ValueError(f"Data test failed: {bad_share:.1%} bad rows > {max_bad_share:.0%}")
    if report["rows_out"] < min_rows:
        raise ValueError(f"Data test failed: only {report['rows_out']} rows < {min_rows}")


def add_features(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()
    ts = pd.to_datetime(out["pickup_ts"])
    out["pickup_hour"] = ts.dt.hour.astype("float64")
    out["pickup_dow"] = ts.dt.dayofweek.astype("float64")
    out["trip_distance"] = out["trip_distance"].astype("float64")
    out["passenger_count"] = out["passenger_count"].astype("float64")
    out[TARGET] = out[TARGET].astype("float64")
    return out


def split_by_date(df: pd.DataFrame, split_date: str) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Before split_date = training data, from split_date = 'new' data for evaluation/monitoring."""
    ts = pd.to_datetime(df["pickup_ts"])
    return df[ts < split_date], df[ts >= split_date]


def build_model(seed: int = 42) -> HistGradientBoostingRegressor:
    # Small and fast on purpose: the project is about MLOps, not accuracy.
    return HistGradientBoostingRegressor(max_iter=100, learning_rate=0.1, random_state=seed)


def holdout_split(df: pd.DataFrame, seed: int = 42):
    return train_test_split(df[FEATURES], df[TARGET], test_size=0.2, random_state=seed)


def evaluate(model, X: pd.DataFrame, y: pd.Series) -> dict[str, float]:
    pred = np.asarray(model.predict(X[FEATURES]), dtype="float64").ravel()
    return {
        "rmse": float(np.sqrt(mean_squared_error(y, pred))),
        "mae": float(mean_absolute_error(y, pred)),
        "r2": float(r2_score(y, pred)),
    }


def promotion_decision(
    candidate_rmse: float, champion_rmse: float | None, max_rmse: float
) -> tuple[bool, str]:
    """Returns (promote, reason). Same rule as the Databricks project."""
    if not np.isfinite(candidate_rmse) or candidate_rmse > max_rmse:
        return False, f"candidate rmse {candidate_rmse:.3f} > max_rmse {max_rmse:.3f}"
    if champion_rmse is None:
        return True, "no champion yet"
    if candidate_rmse <= champion_rmse:
        return True, f"candidate {candidate_rmse:.3f} <= champion {champion_rmse:.3f}"
    return False, f"candidate {candidate_rmse:.3f} worse than champion {champion_rmse:.3f}"


def psi(expected: pd.Series, actual: pd.Series, bins: int = 10) -> float:
    """Population Stability Index. < 0.1 stable, 0.1-0.2 moderate, > 0.2 drift."""
    expected, actual = expected.dropna().astype(float), actual.dropna().astype(float)
    if expected.empty or actual.empty:
        return float("nan")
    edges = np.unique(np.quantile(expected, np.linspace(0, 1, bins + 1)))
    edges[0], edges[-1] = -np.inf, np.inf
    e = np.histogram(expected, edges)[0] / len(expected)
    a = np.histogram(actual, edges)[0] / len(actual)
    e, a = np.clip(e, 1e-6, None), np.clip(a, 1e-6, None)
    return float(np.sum((a - e) * np.log(a / e)))
