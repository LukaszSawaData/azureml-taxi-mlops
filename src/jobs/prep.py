"""Step 1 - prep: raw taxi file -> data tests -> features -> train.parquet + scoring.parquet."""

import argparse
from pathlib import Path

import mlflow
import pandas as pd

from taxi_aml.model import RAW_COLUMNS, add_features, check_quality, clean, split_by_date

def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--raw_data", required=True)
    p.add_argument("--max_rows", type=int, default=3000)
    p.add_argument("--split_date", default="2016-01-25")
    p.add_argument("--max_bad_share", type=float, default=0.2)
    p.add_argument("--train_data", required=True)
    p.add_argument("--scoring_data", required=True)
    args = p.parse_args()

    raw = pd.read_parquet(args.raw_data, columns=list(RAW_COLUMNS))
    df, report = clean(raw)
    mlflow.log_metrics({k: float(v) for k, v in report.items()})  # visible in the job's Metrics tab
    print(f"data tests: {report}")
    check_quality(report, args.max_bad_share, min_rows=args.max_rows)

    # Same rows on every run (fixed seed) -> metrics are comparable between runs.
    df = add_features(df.sample(n=args.max_rows, random_state=42))
    train, scoring = split_by_date(df, args.split_date)
    print(f"train={len(train)} scoring={len(scoring)} (split {args.split_date})")

    for frame, out in ((train, args.train_data), (scoring, args.scoring_data)):
        Path(out).mkdir(parents=True, exist_ok=True)
        frame.to_parquet(Path(out) / "data.parquet", index=False)


if __name__ == "__main__":
    main()
