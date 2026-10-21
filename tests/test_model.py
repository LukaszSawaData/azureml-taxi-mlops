import sys
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

from taxi_aml.model import (
    FEATURES,
    TARGET,
    add_features,
    build_model,
    check_quality,
    clean,
    evaluate,
    holdout_split,
    promotion_decision,
    psi,
    split_by_date,
)

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from check_predictions import check  # noqa: E402


@pytest.fixture
def raw() -> pd.DataFrame:
    """Shape of the Azure Open Datasets green taxi file, incl. bad rows."""
    rng = np.random.default_rng(0)
    n = 1000
    dist = rng.uniform(0.2, 20, n)
    df = pd.DataFrame(
        {
            "lpepPickupDatetime": pd.Timestamp("2016-01-01")
            + pd.to_timedelta(rng.integers(0, 31 * 24 * 3600, n), unit="s"),
            "tripDistance": dist,
            "passengerCount": rng.integers(1, 5, n),
            "fareAmount": 4.0 + 2.5 * dist + rng.normal(0, 0.3, n),  # always >= 2.5
            "extraColumn": 0,
        }
    )
    df.loc[:9, "fareAmount"] = -5.0  # 10 negative fares
    df.loc[10:14, "tripDistance"] = 0.0  # 5 zero distances
    return df


def test_clean_drops_bad_rows_and_reports(raw):
    df, report = clean(raw)
    assert report["dropped_valid_fare"] == 10
    assert report["dropped_valid_distance"] == 5
    assert report["rows_out"] == len(df) == 985
    assert set(df.columns) == {"pickup_ts", "trip_distance", "passenger_count", "fare_amount"}


def test_clean_fails_on_missing_column(raw):
    with pytest.raises(ValueError, match="missing columns"):
        clean(raw.drop(columns=["fareAmount"]))


def test_check_quality_fails_on_too_many_bad_rows():
    check_quality({"rows_in": 100, "rows_out": 90}, max_bad_share=0.2, min_rows=50)
    with pytest.raises(ValueError, match="bad rows"):
        check_quality({"rows_in": 100, "rows_out": 70}, max_bad_share=0.2, min_rows=50)
    with pytest.raises(ValueError, match="only"):
        check_quality({"rows_in": 100, "rows_out": 90}, max_bad_share=0.2, min_rows=95)


def test_model_learns_on_train_split(raw):
    df = add_features(clean(raw)[0])
    train, scoring = split_by_date(df, "2016-01-25")
    assert len(train) > 0 and len(scoring) > 0
    assert pd.to_datetime(train["pickup_ts"]).max() < pd.Timestamp("2016-01-25")
    X_train, _, y_train, _ = holdout_split(train)
    model = build_model().fit(X_train[FEATURES], y_train)
    metrics = evaluate(model, scoring, scoring[TARGET])
    assert metrics["rmse"] < 3.0 and metrics["r2"] > 0.9


@pytest.mark.parametrize(
    ("candidate", "champion", "promote"),
    [(3.0, None, True), (3.0, 3.5, True), (3.5, 3.5, True), (4.0, 3.5, False), (9.0, None, False)],
)
def test_promotion_decision(candidate, champion, promote):
    assert promotion_decision(candidate, champion, max_rmse=6.0)[0] is promote


def test_psi_detects_shift():
    rng = np.random.default_rng(1)
    base = pd.Series(rng.normal(3, 1, 5000))
    assert psi(base, pd.Series(rng.normal(3, 1, 5000))) < 0.1
    assert psi(base, pd.Series(rng.normal(5, 1, 5000))) > 0.2


@pytest.mark.parametrize(
    "raw_response",
    ["[8.1, 29.5, 11.2]", '"[8.1, 29.5, 11.2]"', '{"predictions": [8.1, 29.5, 11.2]}'],
)
def test_check_predictions_accepts_endpoint_formats(raw_response):
    assert check(raw_response) == [8.1, 29.5, 11.2]


def test_check_predictions_rejects_nonsense():
    with pytest.raises(SystemExit):
        check("[30.0, 5.0, 10.0]")
