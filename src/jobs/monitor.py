"""Monitoring: score 'new' trips with the champion, log quality + drift to MLflow, write a report."""

import argparse
import json
from pathlib import Path

import mlflow
import pandas as pd
from mlflow import MlflowClient

from jobs.evaluate_register import find_champion
from taxi_aml.model import TARGET, evaluate, psi


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--train_data", required=True)
    p.add_argument("--scoring_data", required=True)
    p.add_argument("--model_name", default="taxi-fare-model")
    p.add_argument("--max_psi", type=float, default=0.2)
    p.add_argument("--report", required=True)
    args = p.parse_args()

    train = pd.read_parquet(Path(args.train_data) / "data.parquet")
    scoring = pd.read_parquet(Path(args.scoring_data) / "data.parquet")

    champ = find_champion(MlflowClient(), args.model_name)
    if champ is None:
        raise SystemExit("No champion yet - deploy a model first")
    model = mlflow.pyfunc.load_model(f"models:/{args.model_name}/{champ.version}")

    report = {"model_version": champ.version, "rows": len(scoring)}
    report |= evaluate(model, scoring, scoring[TARGET])
    report |= {f"psi_{c}": psi(train[c], scoring[c]) for c in ["trip_distance", "pickup_hour"]}
    report["drift"] = max(report["psi_trip_distance"], report["psi_pickup_hour"]) > args.max_psi

    mlflow.log_metrics({k: float(v) for k, v in report.items() if k != "model_version"})
    mlflow.set_tag("model_version", champ.version)
    Path(args.report).mkdir(parents=True, exist_ok=True)
    (Path(args.report) / "report.json").write_text(json.dumps(report, indent=2))
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
