# SPDX-FileCopyrightText: © 2024 J. R. Petrus
# SPDX-License-Identifier: Apache-2.0

import enum

# Constants
ADDR_W = 8
DATA_W = 16
ADDR_MASK = (1 << ADDR_W) - 1
DATA_MASK = (1 << DATA_W) - 1

SYS_CLK_PERIOD_NS = 20

# Motor controller
# Each motor state is programmed into the table.
STEP_TABLE_OFFSET = 16
TABLE_DEPTH = 16
MC_OUT_WIDTH = 8


class Op(enum.IntEnum):
    NOP = 0
    RD = 1
    WR = 2


class Result(enum.IntEnum):
    BUSY = 0x0
    ACK = 0x1
    ACK_DATA = 0x2


REG_MAP = {
    "id": 0,
    "gpio": 1,
    "step_ctrl": 2,
    "step_stat": 3,
    "step_delay0": 4,
    "step_delay1": 5,
    "step_count0": 6,
    "step_count1": 7,
    "delay_count0": 8,
    "delay_count1": 9,
}

# reg_name: field_name: (bit_offset, n_bits)
BIT_MAP = {
    "id": {
        "idcode": (0, 8),
        "version": (8, 8),
    },
    "gpio": {
        "gpi": (0, 4),
        "gpo": (4, 4),
        "mc_oe": (8, MC_OUT_WIDTH),
    },
    "step_ctrl": {
        "step_size": (0, 5),
        "table_last": (5, 4),
        "step": (14, 1),
        "run": (15, 1),
    },
    "step_stat": {
        "table_idx": (0, 4),
        "state": (4, 4),
    },
}


def get_field_info(name: str, field: str) -> tuple[int, int, int]:
    """Get bit field information if defined."""
    bit_offset = 0
    bit_width = DATA_W
    if field is not None:
        try:
            bit_offset, bit_width = BIT_MAP[name][field]
        except KeyError:
            # Use default full width if not specified
            pass
    bit_mask = (1 << bit_width) - 1
    return bit_offset, bit_width, bit_mask


def get_reg_str(name: str, val: int):
    """Contents of a register as a string."""
    regStr = f"{name}: "
    fields = list(BIT_MAP.get(name, [None]))
    for field in fields:
        if field is None:
            regStr += f"{val}"
        else:
            bit_offset, _, bit_mask = get_field_info(name, field)
            fieldVal = (val >> bit_offset) & bit_mask
            regStr += f"\n\t{field} = {fieldVal}"
    return regStr


def get_next_step_idx(step_idx: int, step_size: int, table_last: int):
    """Model step increments."""
    next_step_idx = step_idx + step_size
    if next_step_idx > table_last:
        return 0
    elif next_step_idx < 0:
        return table_last
    return next_step_idx

