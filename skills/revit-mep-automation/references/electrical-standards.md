# Electrical Design Standards for Revit MEP

## Lighting Power Density (W/m²)

| Room Type | IEC/TCVN 9206 | ASHRAE 90.1 | Target Lux |
|-----------|:------------:|:-----------:|:----------:|
| Office (open) | 12 | 10.8 | 500 |
| Office (private) | 15 | 11.8 | 500 |
| Meeting room | 15 | 13.0 | 300 |
| Corridor | 5 | 6.6 | 100 |
| Lobby | 10 | 13.0 | 200 |
| Toilet/WC | 8 | 9.7 | 200 |
| Parking | 3 | 2.0 | 75 |
| Server room | 5 | 12.0 | 300 |
| Kitchen | 15 | 12.0 | 500 |
| Warehouse | 8 | 7.6 | 200 |
| Retail | 15 | 15.0 | 500 |
| Hospital ward | 10 | 7.0 | 300 |
| Classroom | 12 | 12.0 | 500 |

## Power Density (W/m²)

| Room Type | Small Power | HVAC Power | Total |
|-----------|:----------:|:----------:|:-----:|
| Office | 25 | 80-120 | 105-145 |
| Server room | 500-2000 | 500-1500 | 1000-3500 |
| Retail | 15 | 60-80 | 75-95 |
| Hospital | 30 | 80-100 | 110-130 |
| Hotel room | 15 | 50-70 | 65-85 |

## Cable Sizing per IEC 60228 / TCVN 6612

| Cross-section (mm²) | Current Rating (A) - PVC | Current Rating (A) - XLPE |
|:-------------------:|:------------------------:|:-------------------------:|
| 1.5 | 15 | 20 |
| 2.5 | 21 | 28 |
| 4 | 28 | 37 |
| 6 | 36 | 48 |
| 10 | 50 | 66 |
| 16 | 66 | 88 |
| 25 | 84 | 110 |
| 35 | 104 | 135 |
| 50 | 125 | 164 |
| 70 | 160 | 207 |
| 95 | 194 | 250 |
| 120 | 225 | 290 |
| 150 | 260 | 335 |
| 185 | 297 | 382 |
| 240 | 350 | 450 |
| 300 | 400 | 510 |

## Circuit Breaker Selection

| Load Current (A) | Standard MCB Size | Type |
|:-----------------:|:-----------------:|:----:|
| ≤ 5 | 6A | B/C |
| ≤ 8 | 10A | B/C |
| ≤ 13 | 16A | B/C |
| ≤ 16 | 20A | C |
| ≤ 20 | 25A | C |
| ≤ 25 | 32A | C |
| ≤ 32 | 40A | C |
| ≤ 40 | 50A | C/D |
| ≤ 50 | 63A | C/D |
| ≤ 63 | 80A | MCCB |
| ≤ 80 | 100A | MCCB |
| ≤ 100 | 125A | MCCB |
| ≤ 125 | 160A | MCCB |
| ≤ 160 | 200A | MCCB |
| ≤ 200 | 250A | MCCB |

## Voltage Drop Limits

| Circuit Type | Max Voltage Drop |
|-------------|:----------------:|
| Lighting | 3% |
| Power | 5% |
| Motor | 5% (starting: 15%) |
| Combined (source to load) | 4% |

## Outlet Spacing (per TCVN / NEC)

| Location | Max Spacing | Height (mm) |
|----------|:-----------:|:-----------:|
| Office wall outlets | 3.6m (12ft) | 300 |
| Kitchen countertop | 1.2m (4ft) | 1100 |
| Corridor | 7.5m (25ft) | 300 |
| Wet areas (GFCI) | 1.8m (6ft) | 1100 |
| Floor outlets | 5.4m (18ft) | 0 |

## Protection Devices

| Protection | Standard | Application |
|-----------|---------|-------------|
| RCD/RCCB 30mA | IEC 61008 | Socket outlets, wet areas |
| RCD 100mA | IEC 61008 | Sub-distribution |
| RCD 300mA | IEC 61008 | Main distribution, fire protection |
| SPD Type 1 | IEC 61643 | Main incoming |
| SPD Type 2 | IEC 61643 | Sub-distribution |
| SPD Type 3 | IEC 61643 | Sensitive equipment |
