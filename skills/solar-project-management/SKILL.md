---
name: solar-project-management
description: Solar PV+BESS project management - BOQ and cost estimation, construction method statements, hardware/software selection guide, installation procedures, commissioning checklist, O&M planning, ROI/LCOE/payback calculation, procurement specifications, and vendor comparison. Use when estimating project costs, planning construction, selecting equipment vendors, writing method statements, or calculating financial returns for solar projects.
version: 1.0.0
author: Custom Skills
license: MIT
tags: [Solar Project, BOQ, Cost Estimation, Construction, Method Statement, Hardware Selection, ROI, LCOE, Commissioning, O&M]
dependencies: [pandas, numpy, openpyxl, matplotlib]
---

# Solar PV+BESS Project Management

## When to Use

- Creating BOQ and cost estimation for PV+BESS projects
- Writing construction method statements
- Selecting hardware (modules, inverters, BESS, cables, structures)
- Selecting software/communication platforms (SCADA, EMS, monitoring)
- Installation procedure and quality control
- Commissioning checklist
- O&M planning and performance monitoring
- Financial analysis (ROI, LCOE, IRR, payback period)

## BOQ Generator

```python
import pandas as pd
import numpy as np

def generate_pv_bess_boq(pv_kwp: float, bess_kwh: float, bess_kw: float,
                           system_type: str = 'rooftop',
                           module_wp: int = 580,
                           inverter_kw: int = 100) -> pd.DataFrame:
    """Generate detailed Bill of Quantities for PV+BESS project."""
    num_modules = int(np.ceil(pv_kwp * 1000 / module_wp))
    num_inverters = int(np.ceil(pv_kwp / (inverter_kw * 1.2)))
    num_bess_racks = int(np.ceil(bess_kwh / 200))

    items = [
        # === PV Modules ===
        {'category': 'PV Modules', 'item': f'PV Module {module_wp}W Mono PERC/TOPCon Tier 1',
         'unit': 'pc', 'qty': num_modules, 'unit_price': module_wp * 0.20, 'supplier': 'LONGi/Jinko/Canadian'},

        # === Inverters ===
        {'category': 'Inverters', 'item': f'String Inverter {inverter_kw}kW',
         'unit': 'pc', 'qty': num_inverters, 'unit_price': inverter_kw * 45, 'supplier': 'Huawei/SMA/Sungrow'},

        # === BESS ===
        {'category': 'BESS', 'item': f'LFP Battery Rack 200kWh',
         'unit': 'set', 'qty': num_bess_racks, 'unit_price': 200 * 130, 'supplier': 'BYD/CATL/EVE'},
        {'category': 'BESS', 'item': f'Battery PCS {bess_kw}kW',
         'unit': 'set', 'qty': 1, 'unit_price': bess_kw * 80, 'supplier': 'Sungrow/Huawei'},
        {'category': 'BESS', 'item': 'BMS Controller',
         'unit': 'set', 'qty': 1, 'unit_price': 5000, 'supplier': 'BYD/custom'},
        {'category': 'BESS', 'item': 'Battery Container 20ft (with HVAC, fire suppression)',
         'unit': 'set', 'qty': max(1, int(np.ceil(bess_kwh / 1000))), 'unit_price': 25000, 'supplier': 'Custom'},

        # === Mounting Structure ===
        {'category': 'Structure', 'item': f'Mounting Structure ({"rooftop" if system_type == "rooftop" else "ground-mount"})',
         'unit': 'kWp', 'qty': pv_kwp, 'unit_price': 35 if system_type == 'rooftop' else 55, 'supplier': 'Local'},

        # === Electrical ===
        {'category': 'Electrical', 'item': 'DC Cable PV1-F 4mm² (PV string)',
         'unit': 'm', 'qty': num_modules * 3, 'unit_price': 1.5, 'supplier': 'Local'},
        {'category': 'Electrical', 'item': 'AC Cable (inverter to switchboard)',
         'unit': 'm', 'qty': num_inverters * 50, 'unit_price': 15, 'supplier': 'Local'},
        {'category': 'Electrical', 'item': 'DC Combiner Box',
         'unit': 'pc', 'qty': int(np.ceil(num_modules / 24)), 'unit_price': 200, 'supplier': 'Local'},
        {'category': 'Electrical', 'item': 'AC Switchboard (MDB/SMDB)',
         'unit': 'set', 'qty': 1, 'unit_price': pv_kwp * 8, 'supplier': 'Local'},
        {'category': 'Electrical', 'item': 'Transformer (if required)',
         'unit': 'set', 'qty': 1 if pv_kwp > 500 else 0,
         'unit_price': pv_kwp * 15 if pv_kwp > 500 else 0, 'supplier': 'ABB/Schneider'},
        {'category': 'Electrical', 'item': 'SPD (DC + AC)',
         'unit': 'set', 'qty': num_inverters * 2, 'unit_price': 150, 'supplier': 'ABB/Schneider'},
        {'category': 'Electrical', 'item': 'Grounding System',
         'unit': 'lot', 'qty': 1, 'unit_price': pv_kwp * 3, 'supplier': 'Local'},
        {'category': 'Electrical', 'item': 'Energy Meter (bidirectional)',
         'unit': 'pc', 'qty': 2, 'unit_price': 500, 'supplier': 'Schneider/ABB'},

        # === Communication & Monitoring ===
        {'category': 'Communication', 'item': 'EMS Controller / Gateway',
         'unit': 'set', 'qty': 1, 'unit_price': 3000, 'supplier': 'Huawei/custom'},
        {'category': 'Communication', 'item': 'Weather Station (irradiance, temp, wind)',
         'unit': 'set', 'qty': 1, 'unit_price': 2500, 'supplier': 'Kipp & Zonen/local'},
        {'category': 'Communication', 'item': 'SCADA Software License',
         'unit': 'set', 'qty': 1, 'unit_price': 5000, 'supplier': 'Custom/Huawei'},
        {'category': 'Communication', 'item': 'Network Switch + Router + 4G Modem',
         'unit': 'set', 'qty': 1, 'unit_price': 1500, 'supplier': 'Cisco/TP-Link'},

        # === Installation ===
        {'category': 'Installation', 'item': 'Mechanical Installation (structure + modules)',
         'unit': 'kWp', 'qty': pv_kwp, 'unit_price': 25, 'supplier': 'Contractor'},
        {'category': 'Installation', 'item': 'Electrical Installation (DC+AC wiring)',
         'unit': 'kWp', 'qty': pv_kwp, 'unit_price': 20, 'supplier': 'Contractor'},
        {'category': 'Installation', 'item': 'BESS Installation & Commissioning',
         'unit': 'kWh', 'qty': bess_kwh, 'unit_price': 15, 'supplier': 'Contractor'},
        {'category': 'Installation', 'item': 'Testing & Commissioning',
         'unit': 'lot', 'qty': 1, 'unit_price': pv_kwp * 5, 'supplier': 'Contractor'},

        # === Others ===
        {'category': 'Others', 'item': 'Engineering & Design',
         'unit': 'lot', 'qty': 1, 'unit_price': pv_kwp * 10, 'supplier': 'In-house'},
        {'category': 'Others', 'item': 'Permits & Approvals',
         'unit': 'lot', 'qty': 1, 'unit_price': 3000, 'supplier': 'Local authority'},
        {'category': 'Others', 'item': 'Transportation & Logistics',
         'unit': 'lot', 'qty': 1, 'unit_price': pv_kwp * 5, 'supplier': 'Logistics'},
        {'category': 'Others', 'item': 'Insurance (CAR)',
         'unit': 'lot', 'qty': 1, 'unit_price': pv_kwp * 2, 'supplier': 'Insurance'},
    ]

    df = pd.DataFrame(items)
    df['amount'] = df['qty'] * df['unit_price']
    df = df[df['qty'] > 0]

    subtotal = df['amount'].sum()
    contingency = subtotal * 0.05

    summary = df.groupby('category')['amount'].sum().reset_index()
    summary.columns = ['Category', 'Amount (USD)']

    return {
        'boq_detail': df,
        'summary': summary,
        'subtotal': round(subtotal, 0),
        'contingency_5pct': round(contingency, 0),
        'total': round(subtotal + contingency, 0),
        'cost_per_wp': round((subtotal + contingency) / (pv_kwp * 1000), 3),
    }

boq = generate_pv_bess_boq(pv_kwp=1000, bess_kwh=500, bess_kw=250, system_type='rooftop')
```

## Hardware Selection Guide

```python
HARDWARE_RECOMMENDATIONS = {
    'pv_modules': {
        'tier1_residential': ['LONGi Hi-MO 6', 'JinkoSolar Tiger Neo', 'Trina Vertex S+'],
        'tier1_commercial': ['Canadian Solar HiKu7', 'JA Solar DeepBlue 4.0', 'Risen HJT'],
        'tier1_utility': ['LONGi Hi-MO 7', 'Trina Vertex N', 'JinkoSolar Tiger Neo 78'],
        'selection_criteria': ['Tier 1 bankability', 'PVEL/DNV reliability', 'local warranty'],
    },
    'inverters': {
        'string_commercial': {'Huawei SUN2000': '3-215kW, 10 MPPT', 'Sungrow SG': '3-350kW',
                              'SMA Sunny Tripower': '15-110kW', 'GoodWe': '5-100kW'},
        'central_utility': {'Huawei SUN2000-330KTL': '330kW', 'Sungrow SG3125HV': '3.125MW',
                            'SMA Sunny Central': '2-4.6MW'},
        'hybrid_residential': {'Huawei LUNA': '5-15kW+BESS', 'SolarEdge': '3-10kW',
                               'Sungrow SH': '3-15kW hybrid'},
    },
    'bess': {
        'residential': {'BYD HVS/HVM': '5-32kWh', 'Tesla Powerwall 3': '13.5kWh',
                        'Huawei LUNA 2000': '5-30kWh'},
        'commercial': {'BYD Battery-Box C': '100-500kWh', 'Sungrow PowerTitan': '2.5MWh',
                       'CATL EnerOne': '3.35MWh'},
        'utility': {'Tesla Megapack': '3.9MWh', 'BYD MC Cube': '2.8MWh',
                    'Sungrow PowerTitan 2.0': '5MWh'},
    },
    'communication': {
        'scada': ['Huawei FusionSolar', 'SolarEdge Designer', 'Sungrow iSolarCloud',
                  'Custom (Node-RED + Grafana + InfluxDB)'],
        'protocols': ['Modbus TCP/RTU', 'MQTT', 'SunSpec', 'IEC 61850'],
        'ems_platforms': ['Huawei SmartPVMS', 'Schneider EcoStruxure Microgrid',
                          'Custom Python EMS', 'OpenEMS (open-source)'],
        'networking': ['Ethernet (primary)', '4G/5G (backup)', 'RS-485 (legacy)', 'WiFi (monitoring)'],
    },
}
```

## Construction Method Statement

```python
def generate_method_statement(project: dict) -> dict:
    """Generate construction method statement for PV+BESS project."""
    return {
        'project_name': project['name'],
        'phases': [
            {
                'phase': 'Phase 1: Site Preparation',
                'duration_days': 7,
                'activities': [
                    'Site survey and as-built verification',
                    'Roof structural assessment (rooftop) / land clearing (ground-mount)',
                    'Establish safety perimeter and signage',
                    'Material staging area setup',
                    'Temporary power and water supply',
                ],
                'safety': ['Fall protection plan', 'PPE enforcement', 'Hot work permit if needed'],
            },
            {
                'phase': 'Phase 2: Structure Installation',
                'duration_days': 14,
                'activities': [
                    'Install roof anchors / ground pile driving',
                    'Mount rails and clamps',
                    'Torque verification on all fasteners',
                    'Waterproofing at roof penetrations',
                    'Quality check: alignment, levelness',
                ],
                'tools': ['Pile driver (ground)', 'Torque wrench', 'Laser level'],
            },
            {
                'phase': 'Phase 3: PV Module Installation',
                'duration_days': 14,
                'activities': [
                    'Module unpacking and visual inspection',
                    'Mount modules on rails (bottom-up for rooftop)',
                    'Secure mid-clamps and end-clamps',
                    'Label each string (string ID tag)',
                    'Grounding conductor on each module frame',
                ],
                'rate': f'{project["pv_kwp"] / 14:.0f} kWp/day',
            },
            {
                'phase': 'Phase 4: DC Wiring',
                'duration_days': 10,
                'activities': [
                    'Install DC conduit/trunking',
                    'Run PV string cables (PV1-F solar cable)',
                    'Connect MC4 connectors (tool-crimped only)',
                    'Label all cables (string number, polarity)',
                    'Install DC combiner boxes',
                    'Install DC SPD at combiner boxes',
                    'Voc measurement per string (±5% of nameplate)',
                ],
            },
            {
                'phase': 'Phase 5: Inverter & AC Wiring',
                'duration_days': 7,
                'activities': [
                    'Mount inverters (ventilation clearance per spec)',
                    'AC cable installation to switchboard',
                    'Install AC breakers, contactors, meter',
                    'Install AC SPD',
                    'Grounding system (ground rod, equipotential bonding)',
                ],
            },
            {
                'phase': 'Phase 6: BESS Installation',
                'duration_days': 7,
                'activities': [
                    'Position battery container/rack',
                    'Connect battery modules (per BMS configuration)',
                    'DC bus connection to PCS',
                    'BMS commissioning (cell voltage verification)',
                    'HVAC and fire suppression system check',
                    'AC connection PCS to switchboard',
                ],
                'safety': ['High voltage DC awareness', 'Arc flash PPE', 'No hot-swap of battery modules'],
            },
            {
                'phase': 'Phase 7: Communication & EMS',
                'duration_days': 5,
                'activities': [
                    'Install Ethernet/RS-485 cables',
                    'Configure Modbus addresses (inverter, meter, BMS)',
                    'Install EMS gateway/controller',
                    'Configure SCADA/monitoring platform',
                    'Test data acquisition from all devices',
                    'Configure EMS dispatch rules',
                    'Install weather station',
                ],
            },
            {
                'phase': 'Phase 8: Testing & Commissioning',
                'duration_days': 5,
                'activities': [
                    'Insulation resistance test (DC strings > 1MΩ)',
                    'Polarity check all strings',
                    'Voc and Isc measurement per string',
                    'I-V curve tracing (sample 10%)',
                    'Grid protection relay test (anti-islanding)',
                    'BESS charge/discharge cycle test',
                    'EMS operation mode test',
                    'Performance ratio verification',
                    'Handover documentation package',
                ],
            },
        ],
        'total_duration_days': 69,
        'documentation': [
            'As-built drawings (SLD, layout, cable schedule)',
            'Test reports (insulation, Voc, Isc, I-V curve)',
            'Equipment datasheets and warranties',
            'O&M manual',
            'Commissioning report',
            'Grid connection agreement',
        ],
    }
```

## Financial Analysis

```python
def financial_analysis(total_investment: float, annual_yield_kwh: float,
                        electricity_price: float, feed_in_tariff: float = 0,
                        self_consumption_pct: float = 0.80,
                        annual_om_pct: float = 1.5,
                        price_escalation: float = 3.0,
                        discount_rate: float = 8.0,
                        project_life: int = 25,
                        degradation: float = 0.5) -> dict:
    """Calculate financial metrics for PV+BESS project."""
    cash_flows = [-total_investment]
    cumulative = -total_investment
    payback_year = None

    for year in range(1, project_life + 1):
        yield_kwh = annual_yield_kwh * (1 - degradation / 100) ** (year - 1)
        price = electricity_price * (1 + price_escalation / 100) ** (year - 1)
        fit = feed_in_tariff * (1 + price_escalation / 100 * 0.5) ** (year - 1)

        savings = yield_kwh * self_consumption_pct * price
        export_revenue = yield_kwh * (1 - self_consumption_pct) * fit
        om_cost = total_investment * annual_om_pct / 100
        net_cf = savings + export_revenue - om_cost

        cash_flows.append(net_cf)
        cumulative += net_cf
        if payback_year is None and cumulative > 0:
            payback_year = year

    # NPV
    npv = sum(cf / (1 + discount_rate / 100) ** t for t, cf in enumerate(cash_flows))

    # IRR (Newton's method)
    def npv_at_rate(r):
        return sum(cf / (1 + r) ** t for t, cf in enumerate(cash_flows))

    irr = 0.10
    for _ in range(100):
        f = npv_at_rate(irr)
        df = sum(-t * cf / (1 + irr) ** (t + 1) for t, cf in enumerate(cash_flows))
        if abs(df) < 1e-10:
            break
        irr -= f / df

    # LCOE
    total_energy = sum(annual_yield_kwh * (1 - degradation / 100) ** y
                       / (1 + discount_rate / 100) ** (y + 1) for y in range(project_life))
    total_cost_pv = total_investment + sum(
        total_investment * annual_om_pct / 100 / (1 + discount_rate / 100) ** (y + 1)
        for y in range(project_life))
    lcoe = total_cost_pv / total_energy

    return {
        'total_investment_usd': total_investment,
        'annual_savings_yr1': round(cash_flows[1], 0),
        'simple_payback_years': payback_year,
        'npv_usd': round(npv, 0),
        'irr_pct': round(irr * 100, 1),
        'lcoe_usd_kwh': round(lcoe, 4),
        'roi_25yr_pct': round((sum(cash_flows[1:]) / total_investment) * 100, 1),
        'cash_flows': [round(cf, 0) for cf in cash_flows],
    }

# 1MWp PV + 500kWh BESS, Vietnam
result = financial_analysis(
    total_investment=650000,
    annual_yield_kwh=1400000,  # 1.4 GWh
    electricity_price=0.08,    # $/kWh
    self_consumption_pct=0.85,
    annual_om_pct=1.5,
    price_escalation=3.0,
    discount_rate=8.0,
)
```

## Commissioning Checklist

```python
COMMISSIONING_CHECKLIST = {
    'visual_inspection': [
        'All modules properly secured, no cracks or damage',
        'Cable management tidy, no exposed conductors',
        'Grounding connections tight and labeled',
        'Inverter ventilation clearance adequate',
        'BESS container doors, ventilation, fire suppression OK',
        'Signage: DC warning, SLD posted, emergency shutoff labeled',
    ],
    'electrical_tests': [
        'Insulation resistance: DC strings > 1MΩ (500V megger)',
        'Insulation resistance: AC cables > 1MΩ',
        'Voc per string: within ±5% of expected',
        'Isc per string: within ±5% of expected',
        'Polarity check: all strings correct',
        'Earth continuity: < 1Ω',
        'Ground rod resistance: < 5Ω (4-point method)',
        'Protection relay trip test (anti-islanding)',
        'BESS: cell voltage balance < 30mV difference',
    ],
    'functional_tests': [
        'Grid synchronization: voltage, frequency, phase sequence',
        'Power ramp-up: 10%/min max',
        'Reactive power control: PF adjustable 0.8 lead to 0.8 lag',
        'BESS charge/discharge at rated power',
        'EMS dispatch modes: self-consumption, peak-shaving, TOU',
        'Communication: all Modbus registers readable',
        'SCADA: real-time data display, alarms functional',
        'Emergency stop: system shutdown < 2 seconds',
        'Islanding detection: disconnect < 2 seconds',
    ],
    'documentation': [
        'As-built single-line diagram',
        'Cable schedule with labels matching physical',
        'Test report signed by engineer',
        'Equipment serial numbers recorded',
        'Warranty certificates collected',
        'O&M manual delivered',
    ],
}
```

## O&M Schedule

| Task | Frequency | Duration |
|------|-----------|----------|
| Visual inspection | Monthly | 2h |
| Module cleaning | Quarterly | 1 day/MWp |
| Inverter log review | Monthly | 1h |
| Thermal imaging (modules) | Annually | 1 day/MWp |
| I-V curve tracing (sample) | Annually | 1 day |
| BESS health check (SOH) | Quarterly | 2h |
| Switchgear inspection | Semi-annually | 4h |
| Grounding test | Annually | 2h |
| Protection relay test | Annually | 4h |
| EMS software update | As needed | 2h |
