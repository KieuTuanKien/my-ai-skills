---
name: pv-bess-financial-analyst
description: Phân tích tài chính dự án PV + BESS + Trạm sạc xe điện. Tính toán sản lượng PV theo PSH vùng miền, BESS arbitrage, franchise fee, dòng tiền 20 năm, NPV, IRR, payback. Dùng khi phân tích đầu tư năng lượng, trạm sạc VinFast, solar rooftop, battery storage, hoặc khả thi tài chính.
---

# PV + BESS Financial Analyst

## Kiến thức
- PSH (Peak Sun Hours) Việt Nam: Hà Nội 3.8h, Yên Bái 3.6h, Đà Nẵng 4.5h, HCM 4.5h, Ninh Thuận 5.0h
- Performance Ratio: 75-85%, suy giảm 0.5%/năm
- BESS: LFP, DoD 80-90%, RTE 90-95%, 2 cycles/day optimal
- Giá điện EVN 2025: Kinh doanh <6kV: thấp 1830, BT 3007, cao 5174 VNĐ/kWh
- Thuật toán: PV-First → BESS Peak-Shifting → Grid Backup
- Kịch bản thời tiết: nắng/mây/mưa, tỷ lệ PSH mỗi loại

## Mô hình doanh thu
1. PV trực tiếp → bán/tự dùng giá BT
2. BESS C1: PV→BESS→xả cao điểm (chi phí nạp = 0)
3. BESS C2: Lưới thấp điểm→BESS→xả cao điểm (spread arbitrage)
4. Franchise fee (VinFast): VNĐ/kWh trên toàn bộ sản lượng sạc
5. Bán điện PV/BESS cho VinFast: giá EVN × (1 - chiết khấu%)

## Chi phí
- O&M PV+BESS, O&M trạm sạc, thuê mặt bằng
- Escalation O&M 3%/năm, tăng giá điện 5%/năm
- Thay BESS năm 10-12 (70% giá gốc)

## Output
- File Excel template với ô INPUT thay đổi được
- Tất cả công thức Excel thực (không hardcode)
- Dòng tiền 20 năm, NPV, Payback tự tính
- Kịch bản thời tiết weighted average
