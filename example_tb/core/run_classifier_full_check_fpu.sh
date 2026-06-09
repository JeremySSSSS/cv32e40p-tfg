#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
RISCV=${RISCV:-/home/jjsotoch/pulp/toolchain/v1.0.16-pulp-riscv-gcc-ubuntu-18}
VIVADO_SETTINGS=${VIVADO_SETTINGS:-/home/jjsotoch/Documents/viv/Vivado/2022.1/settings64.sh}
CORE_ROOT=${CORE_ROOT:-/home/jjsotoch/pulp/tfg-power/cv32e40p_direct}
DESIGN_RTL_DIR=${DESIGN_RTL_DIR:-${CORE_ROOT}/rtl}
LOG_DIR=${LOG_DIR:-"${SCRIPT_DIR}/xsim_classifier_full_check_fpu_logs"}
FIRMWARE_HEX=${FIRMWARE_HEX:-custom/category_counter_all_types_test_fp.hex}

if [[ ! -f "${VIVADO_SETTINGS}" ]]; then
  echo "ERROR: Vivado settings file not found: ${VIVADO_SETTINGS}" >&2
  exit 1
fi

source "${VIVADO_SETTINGS}"

mkdir -p "${LOG_DIR}"

echo "==> Building FPU firmware image"
(
  cd "${SCRIPT_DIR}"
  make "${FIRMWARE_HEX}" RISCV="${RISCV}"
)

echo "==> Preparing XSim file list"
sed '/^+incdir/d; s#${DESIGN_RTL_DIR}#'"${DESIGN_RTL_DIR}"'#g' \
  "${CORE_ROOT}/cv32e40p_fpu_manifest.flist" > /tmp/cv32e40p_xsim_fpu.flist

sed 's/\.PULP_XPULP[[:space:]]*(PULP_XPULP)/.COREV_PULP      (PULP_XPULP)/; s/\.PULP_CLUSTER[[:space:]]*(PULP_CLUSTER)/.COREV_CLUSTER   (PULP_CLUSTER)/' \
  cv32e40p_tb_subsystem.sv > /tmp/cv32e40p_tb_subsystem_fpu_xsim.sv

RUN_LOG="${LOG_DIR}/category_all_types_fpu.log"

echo "==> Compiling FPU RTL and testbench"
rm -rf "${SCRIPT_DIR}/xsim.dir" "${SCRIPT_DIR}/xvlog.log" "${SCRIPT_DIR}/xelab.log" "${SCRIPT_DIR}/xsim.log"

xvlog -sv -d XSIM -log "${LOG_DIR}/xvlog.log" \
  -i "${DESIGN_RTL_DIR}/include" \
  -i "${DESIGN_RTL_DIR}/vendor/pulp_platform_common_cells/include" \
  -i "${DESIGN_RTL_DIR}/vendor/pulp_platform_fpnew/src/common_cells/include" \
  -i "${CORE_ROOT}/bhv" \
  -i "${CORE_ROOT}/bhv/include" \
  -i "${CORE_ROOT}/sva" \
  -f /tmp/cv32e40p_xsim_fpu.flist \
  include/perturbation_pkg.sv \
  amo_shim.sv \
  cv32e40p_random_interrupt_generator.sv \
  /tmp/cv32e40p_tb_subsystem_fpu_xsim.sv \
  dp_ram.sv \
  mm_ram.sv \
  riscv_gnt_stall.sv \
  riscv_rvalid_stall.sv \
  tb_top.sv

xelab tb_top -debug typical -s tb_top_fpu_behav -log "${LOG_DIR}/xelab.log" \
  --generic_top "FPU=1"

echo "==> Running FPU simulator flow"
xsim tb_top_fpu_behav -R -log "${RUN_LOG}" \
  --testplusarg firmware="${FIRMWARE_HEX}" \
  --testplusarg maxcycles=300000

if ! grep -q "EXIT SUCCESS" "${RUN_LOG}"; then
  echo "FAIL: EXIT SUCCESS not found. See ${RUN_LOG}"
  exit 1
fi

if grep -Eq "EXIT FAILURE|ALL TYPES TEST FAIL|FAIL " "${RUN_LOG}"; then
  echo "FAIL: failure marker found. See ${RUN_LOG}"
  exit 1
fi

if ! grep -q "PASS float:" "${RUN_LOG}"; then
  echo "FAIL: float pass marker not found. See ${RUN_LOG}"
  exit 1
fi

if ! grep -q "ALL TYPES TEST PASS" "${RUN_LOG}"; then
  echo "FAIL: pass marker not found. See ${RUN_LOG}"
  exit 1
fi

echo "PASS: FPU instruction-category checks completed"
echo "Log: ${RUN_LOG}"
