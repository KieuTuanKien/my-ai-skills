---
name: excel-report-builder
description: Tạo file Excel chuyên nghiệp bằng openpyxl với format đẹp, công thức thực, mã màu, bảng so sánh, dòng tiền tài chính. Dùng khi cần tạo bảng tính, báo cáo Excel, BOQ, phân tích tài chính, hoặc so sánh kỹ thuật dạng bảng.
---

# Excel Report Builder

## Nguyên tắc
- Dùng openpyxl, KHÔNG hardcode giá trị → dùng công thức Excel thực (`=SUM`, `=IF`, tham chiếu sheet)
- Ô nhập tay: nền vàng (`FFFFCC`), font xanh đậm → người dùng biết chỗ nào sửa
- Ô tự tính: nền xanh lá nhạt (`E2EFDA`), font xanh đậm
- Header: nền xanh đậm (`1F3864`), font trắng, bold
- Section row: nền xanh nhạt (`D6E4F0`), font xanh đậm
- Kết quả ĐẠT: nền `C6EFCE`, font `006100`
- Cần xác nhận: nền `FFEB9C`, font `9C6500`
- THIẾU/LỖI: nền `FFC7CE`, font `9C0006`

## Template code

```python
import openpyxl
from openpyxl.styles import Font, Alignment, PatternFill, Border, Side

# Quick helpers
def S(ws, r, c, v, font, fill, align):
    cl = ws.cell(r, c, v)
    cl.font = font; cl.fill = fill; cl.alignment = align
    cl.border = Border(left=Side("thin","B4C6E7"), ...)
```

## Checklist
- [ ] Freeze panes tại A4
- [ ] Column widths phù hợp nội dung
- [ ] Number format (#,##0 hoặc #,##0.0)
- [ ] Page setup: landscape, A3, fitToWidth=1
- [ ] Cột TỔNG luôn dùng `=SUM()`, KHÔNG hardcode
- [ ] row_dimensions height cho header và data
- [ ] sys.stdout UTF-8 wrapper cho print tiếng Việt
