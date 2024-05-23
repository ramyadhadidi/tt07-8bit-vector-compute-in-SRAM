<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works



## How to Test

There are several tests under `test/test.py` that would help anyone to understand how the design works. Due to the limitation of access to the external signals, most of the tests are commented out. Each test also contains its own commented Verilog code since some tests were initially developed to test and verify individual units such as MACs and adders. There are four categories of tests:
- **Single MAC operation test**: This test verifies the basic functionality of a single MAC unit, ensuring that it correctly performs multiplication and stores the result.
- **Multiple MAC units loading weights and activations**: This test checks that multiple MAC units can load weights and activations correctly and simultaneously. It ensures that each MAC unit receives and processes its assigned data independently of the others.
- **Adder tree tests verifying that all levels of adder tree are summing to correct numbers**: These tests validate the correctness of the adder tree at all levels. They ensure that the outputs from the MAC units are correctly summed through the hierarchical adder tree structure, producing accurate intermediate and final sums.
- **Read result tests that would test read out circuit**: These tests focus on the readout circuit, verifying that the `s_adder_tree` result can be correctly read out in multiple 8-bit chunks. This ensures that the readout mechanism accurately reconstructs the full result over several clock cycles.

The last two tests work on several test vectors to ensure correct operation with various numbers. These test vectors include a wide range of values and scenarios to thoroughly exercise the design and confirm its correctness under different conditions.


### OP 00: `LOAD_W`
The `LOAD_W` function is an integral part of the testbench, designed to load weight values into the MAC units. This function is invoked by setting the `LOAD_W` opcode, which corresponds to the value `0b00 << 6`. The opcode is combined with the MAC address to target a specific MAC unit for the weight load operation. The MAC address is specified in the lower bits of the `ui_in` signal, allowing precise selection of the MAC unit.

The process begins by setting the `ui_in` input to the `LOAD_W` opcode combined with the target MAC address. This action signals the DUT to prepare for loading the weight value into the specified MAC unit. Simultaneously, the weight value is provided via the `uio_in` input. To ensure that the command and data are properly registered and processed, the function waits for one clock cycle.

By following these steps, the `LOAD_W` function effectively communicates with the DUT to load weight values into the desired MAC units. This operation is crucial for initializing the MAC units with the appropriate weights for subsequent computations.

---

### OP 00: `LOAD_W` Code Snippet for Reference:

```python
async def write_weight(mac_address, weight):
    # Set the op code to 00 (write weight) and address
    dut.ui_in.value = (0b00 << 6) | mac_address
    # Set the weight data
    dut.uio_in.value = weight
    # Wait for a clock cycle to simulate the write
    await ClockCycles(dut.clk, 1)
```

### OP 01: `LOAD_A`
The `LOAD_A` function is another essential component of the testbench, designed to load activation values into the MAC units. This function is activated by setting the `LOAD_A` opcode, which corresponds to the value `0b01 << 6`. Similar to `LOAD_W`, the opcode is combined with the MAC address to target a specific MAC unit for the activation load operation.

The process starts by setting the `ui_in` input to the `LOAD_A` opcode combined with the target MAC address. This action instructs the DUT to prepare for loading the activation value into the specified MAC unit. Concurrently, the activation value is provided via the `uio_in` input. To ensure the command and data are correctly registered and processed, the function waits for one clock cycle.

By adhering to these steps, the `LOAD_A` function successfully communicates with the DUT to load activation values into the designated MAC units. This operation is vital for initializing the MAC units with the appropriate activation values, enabling accurate computation during the subsequent processing stages.

---

### OP 01: `LOAD_A` Code Snippet for Reference:

```python
async def write_act(mac_address, a_value):
    # Set the op code to 01 (write a value) and address
    dut.ui_in.value = (0b01 << 6) | mac_address
    # Set the a value data
    dut.uio_in.value = a_value
    # Wait for a clock cycle to simulate the write
    await ClockCycles(dut.clk, 1)
```

### OP 10: `read_s`
The `read_s` function is a critical part of the testbench designed to read the final result from the adder tree, known as `s_adder_tree`. Since the output interface of the system can only handle 8 bits at a time, the function retrieves the complete result over multiple clock cycles. The process begins by initializing the `READ_S` command. This is achieved by setting the `ui_in` input to the value corresponding to the `READ_S` opcode (`0b10 << 6`). This command instructs the system to prepare the `s_adder_tree` result for reading. To ensure the command is properly registered and processed by the Device Under Test (DUT), the function waits for one clock cycle.

Following the initialization of the `READ_S` command, the function sets the `ui_in` input to a non-operational value (`0b11 << 6`). This step ensures that the command remains stable and does not interfere with the readout process. Another clock cycle wait is introduced to guarantee that the data is ready to be read.

The core of the `read_s` function involves reading the `s_adder_tree` result in 8-bit chunks. The function initializes a variable, `result`, to store the combined output. It then enters a loop that iterates three times, corresponding to the three 8-bit chunks required to construct the 24-bit result. During each iteration, the function waits for the rising edge of the clock to synchronize with the DUT’s data output. This synchronization is crucial for accurate data retrieval. The function reads the current 8-bit chunk from the `uo_out` output, shifts the previously read data left by 8 bits, and combines it with the new chunk using a bitwise OR operation. This method ensures that the first chunk read corresponds to the most significant bits (MSBs) and the last chunk read corresponds to the least significant bits (LSBs).

After all three chunks have been read and combined, the function returns the complete `result`, which represents the full 19-bit `s_adder_tree` value. This process highlights the importance of synchronization with the clock signal and handling data in multiple cycles due to the 8-bit limitation of the output interface. By following these steps, the `read_s` function effectively reads and reconstructs the adder tree result, ensuring accurate and reliable verification of the system's computation.

---

### OP 10: `read_s` Code Snippet for Reference:

```python
async def read_s():
    # Set the op code to 10 (read s_adder_tree)
    dut.ui_in.value = 0b10 << 6
    await ClockCycles(dut.clk, 1)

    # Set to non-operational value to avoid interference
    dut.ui_in.value = 0b11 << 6
    await ClockCycles(dut.clk, 1)

    result = 0
    for i in range(3):
        await RisingEdge(dut.clk)
        result = (result << 8) | int(dut.uo_out.value)
    return result
```

## External hardware

Currently, the compute in SRAM does not interface with any external hardware components, and in reality in should not! It operates entirely within it own resources with its own defined set of control commands. Some external signals might be needed to orchestrate operation of multiple units with a control processor.
