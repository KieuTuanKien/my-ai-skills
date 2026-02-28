---
name: plc-scada-automation
description: Industrial automation with PLC programming (Structured Text, Ladder Logic), SCADA/HMI development, Modbus/OPC-UA communication, PID control, and Python-based automation. Covers Siemens TIA Portal, Allen-Bradley, Codesys, and open-source alternatives (OpenPLC, pyModbus, opcua). Use when programming PLCs, building SCADA systems, implementing control algorithms, or automating industrial processes.
version: 1.0.0
author: Custom Skills
license: MIT
tags: [PLC, SCADA, Automation, Modbus, OPC-UA, PID Control, Ladder Logic, Structured Text, Industrial, IoT]
dependencies: [pymodbus, opcua, asyncua, matplotlib, influxdb-client]
---

# PLC & SCADA Automation

## When to Use

- Programming PLCs (Structured Text, Ladder Logic, Function Block)
- Building SCADA/HMI monitoring systems
- Modbus TCP/RTU communication with devices
- OPC-UA client/server for industrial data
- PID control loop implementation
- Python-based industrial automation & data acquisition

## PLC Programming Languages (IEC 61131-3)

### Structured Text (ST) - Most Versatile

```pascal
// Motor Start/Stop with Interlock
PROGRAM MotorControl
VAR
    StartBtn : BOOL;
    StopBtn : BOOL;
    EmergencyStop : BOOL;
    MotorRunning : BOOL;
    Overload : BOOL;
    RunTimer : TON;  // On-delay timer
    RunHours : REAL;
END_VAR

// Safety interlock first
IF EmergencyStop OR Overload THEN
    MotorRunning := FALSE;
ELSIF StartBtn AND NOT StopBtn THEN
    MotorRunning := TRUE;
ELSIF StopBtn THEN
    MotorRunning := FALSE;
END_IF;

// Track run hours
RunTimer(IN := MotorRunning, PT := T#1H);
IF RunTimer.Q THEN
    RunHours := RunHours + 1.0;
    RunTimer(IN := FALSE);  // Reset
END_IF;
END_PROGRAM
```

### PID Control in Structured Text

```pascal
FUNCTION_BLOCK PID_Controller
VAR_INPUT
    Setpoint : REAL;
    ProcessValue : REAL;
    Kp : REAL := 1.0;     // Proportional gain
    Ki : REAL := 0.1;     // Integral gain
    Kd : REAL := 0.05;    // Derivative gain
    dt : REAL := 0.1;     // Sample time (seconds)
    OutMin : REAL := 0.0;
    OutMax : REAL := 100.0;
END_VAR
VAR_OUTPUT
    Output : REAL;
END_VAR
VAR
    Error : REAL;
    PrevError : REAL;
    Integral : REAL;
    Derivative : REAL;
END_VAR

Error := Setpoint - ProcessValue;
Integral := Integral + Error * dt;

// Anti-windup
IF Integral * Ki > OutMax THEN Integral := OutMax / Ki; END_IF;
IF Integral * Ki < OutMin THEN Integral := OutMin / Ki; END_IF;

Derivative := (Error - PrevError) / dt;
Output := Kp * Error + Ki * Integral + Kd * Derivative;

// Clamp output
IF Output > OutMax THEN Output := OutMax;
ELSIF Output < OutMin THEN Output := OutMin;
END_IF;

PrevError := Error;
END_FUNCTION_BLOCK
```

### Ladder Logic Patterns

```
// Motor Start-Stop (Latching Circuit)
     |--[ StartBtn ]--+--[/StopBtn]--[/E-Stop]--(MotorRun)--|
     |                |                                       |
     |--[ MotorRun ]--+                                       |

// Timer ON-Delay (Star-Delta Starter)
     |--[ MotorRun ]--[TON T1, PT=5s]--(SwitchToDelta)--|

// Counter (Production Count)
     |--[ SensorPulse ]--[CTU C1, PV=100]--(BatchComplete)--|

// Analog Comparison
     |--[ Temperature > 80.0 ]--[TON T2, PT=3s]--(CoolingFanON)--|
```

## Python Modbus Communication

```bash
pip install pymodbus
```

### Modbus TCP Client

```python
from pymodbus.client import ModbusTcpClient

client = ModbusTcpClient('192.168.1.100', port=502)
client.connect()

# Read holding registers (analog values)
result = client.read_holding_registers(address=0, count=10, slave=1)
temperature = result.registers[0] / 10.0  # Scale factor
pressure = result.registers[1] / 100.0

# Read coils (digital I/O)
coils = client.read_coils(address=0, count=8, slave=1)
motor_status = coils.bits[0]

# Write single register (setpoint)
client.write_register(address=100, value=int(75.0 * 10), slave=1)

# Write coil (start motor)
client.write_coil(address=0, value=True, slave=1)
client.close()
```

### Modbus Data Logger

```python
import time
import csv
from datetime import datetime
from pymodbus.client import ModbusTcpClient

def log_modbus_data(host, registers_map, interval=5, output_file="data_log.csv"):
    """
    registers_map: {name: (address, count, scale_factor)}
    """
    client = ModbusTcpClient(host, port=502)
    client.connect()

    with open(output_file, 'w', newline='') as f:
        writer = csv.writer(f)
        headers = ['timestamp'] + list(registers_map.keys())
        writer.writerow(headers)

        while True:
            row = [datetime.now().isoformat()]
            for name, (addr, count, scale) in registers_map.items():
                result = client.read_holding_registers(addr, count, slave=1)
                value = result.registers[0] * scale
                row.append(round(value, 2))
            writer.writerow(row)
            f.flush()
            time.sleep(interval)

REGISTERS = {
    'temperature': (0, 1, 0.1),
    'pressure': (1, 1, 0.01),
    'flow_rate': (2, 1, 0.001),
    'motor_speed': (3, 1, 1.0),
}
log_modbus_data('192.168.1.100', REGISTERS, interval=5)
```

## OPC-UA Communication

```bash
pip install asyncua
```

```python
import asyncio
from asyncua import Client

async def read_opc_ua():
    async with Client("opc.tcp://192.168.1.100:4840") as client:
        # Browse available nodes
        root = client.nodes.root
        objects = await root.get_children()

        # Read specific node
        node = client.get_node("ns=2;s=Temperature.PV")
        value = await node.read_value()
        print(f"Temperature: {value}°C")

        # Write setpoint
        sp_node = client.get_node("ns=2;s=Temperature.SP")
        await sp_node.write_value(75.0)

        # Subscribe to changes
        handler = SubHandler()
        sub = await client.create_subscription(500, handler)
        await sub.subscribe_data_change(node)
        await asyncio.sleep(60)

class SubHandler:
    def datachange_notification(self, node, val, data):
        print(f"Value changed: {val}")

asyncio.run(read_opc_ua())
```

## SCADA Dashboard (Python + Web)

```python
from flask import Flask, render_template, jsonify
from pymodbus.client import ModbusTcpClient
import threading, time

app = Flask(__name__)
live_data = {}

def poll_plc():
    client = ModbusTcpClient('192.168.1.100')
    client.connect()
    while True:
        regs = client.read_holding_registers(0, 10, slave=1)
        live_data.update({
            'temperature': regs.registers[0] / 10.0,
            'pressure': regs.registers[1] / 100.0,
            'motor_rpm': regs.registers[2],
            'valve_pos': regs.registers[3] / 10.0,
        })
        time.sleep(1)

@app.route('/api/data')
def get_data():
    return jsonify(live_data)

threading.Thread(target=poll_plc, daemon=True).start()
app.run(host='0.0.0.0', port=5000)
```

## Common PLC Platforms

| Platform | Language | Communication | Notes |
|----------|----------|---------------|-------|
| Siemens TIA Portal | ST, LAD, FBD | Profinet, Modbus, OPC-UA | S7-1200/1500 |
| Allen-Bradley Studio 5000 | ST, LAD | EtherNet/IP, Modbus | CompactLogix, ControlLogix |
| Codesys | ST, LAD, FBD, SFC | Modbus, EtherCAT, OPC-UA | Open platform |
| OpenPLC | ST, LAD | Modbus TCP | Open-source, runs on Raspberry Pi |
| Beckhoff TwinCAT | ST | EtherCAT, ADS | PC-based control |

## Industrial Protocols Reference

| Protocol | Speed | Distance | Use Case |
|----------|-------|----------|----------|
| Modbus TCP | 100 Mbps | LAN | Simple read/write, legacy |
| Modbus RTU | 115200 baud | 1200m (RS-485) | Serial devices |
| OPC-UA | Varies | TCP/IP | Modern unified access |
| EtherCAT | 100 Mbps | 100m | Real-time motion |
| Profinet | 1 Gbps | 100m | Siemens ecosystem |
| MQTT | Varies | Internet | IoT, cloud integration |
