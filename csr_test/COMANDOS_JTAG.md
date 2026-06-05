# Comandos JTAG — CV32E40P en PULPissimo / Nexys A7

## Setup previo (una sola vez por sesión)

### Liberar FT232H de ftdi_sio si da LIBUSB_ERROR_BUSY
```bash
sudo bash -c 'for d in /sys/bus/usb/devices/*; do
  [ -f "$d/idVendor" ] && [ "$(cat $d/idVendor)" = "0403" ] && [ "$(cat $d/idProduct)" = "6014" ] && \
  echo "${d##*/}:1.0" > /sys/bus/usb/drivers/ftdi_sio/unbind 2>/dev/null && echo "OK liberado"
done'
```

### Matar procesos zombie de OpenOCD
```bash
ps aux | grep openocd
sudo kill -9 <PID>
```

---

## Flujo completo de debug

### Terminal 1 — OpenOCD
```bash
openocd -f /home/jjsotoch/pulp/pulpissimo/target/fpga/pulpissimo-nexys/openocd-ft232h.cfg
```

### Terminal 2 — UART (opcional, para printf)
```bash
screen /dev/ttyUSB2 115200
```

### Terminal 3 — GDB
```bash
gdb-multiarch <archivo.elf>
```

---

## Dentro de GDB

### Conectar a OpenOCD
```
target remote :3333
```

### Cargar y ejecutar firmware
```
monitor reset halt
load <archivo.elf>
set $pc = 0x1c008000
continue
```

### Leer CSR counters del clasificador (después de ebreak)
```
info registers a0 a1 a2 a3 a4 a5
```
| Registro | CSR   | Categoría |
|----------|-------|-----------|
| a0       | 0xBC0 | ARITH     |
| a1       | 0xBC1 | LOGIC     |
| a2       | 0xBC2 | MEMORY    |
| a3       | 0xBC3 | BRANCH    |
| a4       | 0xBC4 | JUMP      |
| a5       | 0xBC5 | FLOAT     |

---

## Compilar test CSR mínimo (sin runtime)
```bash
cd /home/jjsotoch/pulp/tfg-power/csr_test
/home/jjsotoch/pulp/toolchain/v1.0.16-pulp-riscv-gcc-ubuntu-18/bin/riscv32-unknown-elf-gcc \
  -nostdlib -march=rv32imc -mabi=ilp32 -T csr_test.ld csr_test.S -o csr_test.elf
```

---

## Síntesis FPGA (aliases)
```bash
vclean && vsynth    # limpia runs y re-sintetiza
vlog                # monitorea log en tiempo real
vprogram            # programa la FPGA con el bitstream generado
```

---

## Archivos clave
| Archivo | Descripción |
|---------|-------------|
| `pulpissimo/target/fpga/pulpissimo-nexys/openocd-ft232h.cfg` | Config OpenOCD para FT232H externo |
| `pulpissimo/target/fpga/pulpissimo-nexys/rtl/xilinx_pulpissimo.v` | Top-level FPGA (bug TDO corregido: `inout wire`) |
| `tfg-power/csr_test/csr_test.S` | Test mínimo de contadores CSR |
| `tfg-power/csr_test/csr_test.ld` | Linker script para test mínimo |
