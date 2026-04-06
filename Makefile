# ******************************************************************************
# n6502 CPU Makefile
#
# Usage:
#   make lint              - Run Verilator lint checks
#   make sim_alu           - Run ALU unit tests
#   make sim_decoder       - Run Decoder unit tests
#   make sim_core          - Run Core functional tests
#   make sim_dormann       - Run Klaus Dormann functional tests
#   make clean             - Remove build artifacts
# ******************************************************************************

# Tools
VERILATOR = verilator
IVERILOG  = iverilog
VVP       = vvp

# Directories
RTL_CORE  = rtl/core
SIM_DIR   = sim
BUILD_DIR = build

# Source files
ALU_SRC     = $(RTL_CORE)/n6502_alu.v
DECODER_SRC = $(RTL_CORE)/n6502_decoder.v
CONTROL_SRC = $(RTL_CORE)/n6502_control.v
CORE_SRC    = $(RTL_CORE)/n6502_core.v $(ALU_SRC) $(DECODER_SRC) $(CONTROL_SRC)

# SoC files
SOC_SRC     = rtl/soc/ram.v rtl/soc/rom.v rtl/soc/gpio.v rtl/soc/n6502_soc.v

# Verilog flags (-I for n6502_consts.vh include path)
VFLAGS    = -g2005 -Wall -I $(RTL_CORE)

# ******************************************************************************
# Targets
# ******************************************************************************

.PHONY: all clean lint sim_alu sim_decoder sim_core sim_dormann sim_soc

all: lint sim_alu sim_decoder sim_core sim_dormann sim_soc

# Build directory
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

lint: $(BUILD_DIR)
	$(VERILATOR) --lint-only -Wall -I$(RTL_CORE) $(CORE_SRC) > \
	$(BUILD_DIR)/lint.log 2>&1 || (cat $(BUILD_DIR)/lint.log; exit 1)

sim_alu: $(BUILD_DIR)
	$(IVERILOG) $(VFLAGS) -o $(BUILD_DIR)/tb_alu.vvp \
		$(ALU_SRC) $(SIM_DIR)/tb_n6502_alu.v
	$(VVP) $(BUILD_DIR)/tb_alu.vvp

sim_decoder: $(BUILD_DIR)
	$(IVERILOG) $(VFLAGS) -o $(BUILD_DIR)/tb_decoder.vvp \
		$(DECODER_SRC) $(SIM_DIR)/tb_n6502_decoder.v
	$(VVP) $(BUILD_DIR)/tb_decoder.vvp

sim_core: $(BUILD_DIR)
	$(IVERILOG) $(VFLAGS) -o $(BUILD_DIR)/tb_core.vvp \
		$(CORE_SRC) $(SIM_DIR)/tb_n6502_core.v
	$(VVP) $(BUILD_DIR)/tb_core.vvp

sim_dormann: $(BUILD_DIR)
	$(IVERILOG) $(VFLAGS) -o $(BUILD_DIR)/tb_dormann.vvp \
		$(CORE_SRC) $(SIM_DIR)/tb_n6502_dormann.v
	$(VVP) $(BUILD_DIR)/tb_dormann.vvp

sim_soc: $(BUILD_DIR)
	$(IVERILOG) $(VFLAGS) -o $(BUILD_DIR)/tb_soc.vvp \
		$(CORE_SRC) $(SOC_SRC) $(SIM_DIR)/tb_n6502_soc.v
	$(VVP) $(BUILD_DIR)/tb_soc.vvp

clean:
	rm -rf $(BUILD_DIR)
	rm -f *.vcd
