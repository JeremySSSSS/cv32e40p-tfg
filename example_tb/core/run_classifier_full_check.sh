#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LOG_DIR=${LOG_DIR:-"${SCRIPT_DIR}/xsim_classifier_full_check_logs"}

mkdir -p "${LOG_DIR}"

echo "==> Sanity check: hello_world + regression base"
(
  cd "${SCRIPT_DIR}"
  LOG_DIR="${LOG_DIR}/regression" ./run_category_regression_xsim.sh
)

echo "==> Functional check: all instruction categories"
(
  cd "${SCRIPT_DIR}"
  LOG_DIR="${LOG_DIR}/all_types" ./run_category_all_types_xsim.sh
)

echo "==> Full classifier check passed"
echo "Logs: ${LOG_DIR}"
