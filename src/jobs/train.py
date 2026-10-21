"""Step 2 - train: fit the model, log metrics to MLflow, save an MLflow model folder."""

import argparse
from pathlib import Path

import mlflow
import pandas as pd
from mlflow.models import infer_signature

from taxi_aml.model import FEATURES, build_model, evaluate, holdout_split


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--train_data", required=True)
    p.add_argument("--model_output", required=True)
    args = p.parse_args()

    df = pd.read_parquet(Path(args.train_data) / "data.parquet")
    X_train, X_test, y_train, y_test = holdout_split(df)

    model = build_model().fit(X_train, y_train)
    metrics = {f"holdout_{k}": v for k, v in evaluate(model, X_test, y_test).items()}
    mlflow.log_params({"rows_train": len(X_train), "rows_test": len(X_test)})
    mlflow.log_metrics(metrics)
    print(f"holdout metrics: {metrics}")

    sample = X_test[FEATURES].head(5)
    mlflow.sklearn.save_model(
        model,
        args.model_output,
        signature=infer_signature(sample, model.predict(sample)),
        input_example=sample,
        pip_requirements=["mlflow==2.22.5", "scikit-learn==1.9.1", "pandas==2.3.3"],
    )


if __name__ == "__main__":
    main()
