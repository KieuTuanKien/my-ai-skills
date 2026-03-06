---
name: document-analyst-vn
description: Đọc và phân tích tài liệu kỹ thuật tiếng Việt và tiếng Anh (PDF, DOCX, XLSX). Trích xuất thông số, bóc khối lượng từ HSMT, so sánh datasheet, tổng hợp chứng chỉ. Dùng khi cần đọc hồ sơ mời thầu, datasheet, test report, hoặc tổng hợp thông tin từ nhiều file.
---

# Document Analyst

## Khả năng
- Đọc PDF (text-based): trích xuất bảng, thông số kỹ thuật, chứng chỉ
- Đọc DOCX (python-docx): paragraphs + tables, search keywords
- Đọc XLSX (openpyxl): multi-sheet, formulas, data extraction
- DOC (old format): chuyển đổi qua python-docx hoặc antiword

## Quy trình đọc HSMT
1. Tìm file Chương V (V.2.1, V.2.2, V.2.3, V.2.4)
2. V.2.4 (XLSX): bảng CKKT - đọc tất cả sheet
3. HSMT chính (DOCX): tables 49+ chứa BOQ từng trạm
4. Tìm keywords: MW, MWh, container, PCS, MBA, RMU, cáp, móng, camera
5. Lập bảng tổng hợp khối lượng có công thức SUM

## Quy trình đọc chứng chỉ
1. Xác định tiêu chuẩn (IEC, UL, NFPA, IEEE, EN...)
2. Kiểm tra: Cert (chứng nhận) vs TRF (test report) vs TSF (test summary)
3. Xác nhận lab: STL member? ISO 17025?
4. Đối chiếu model/serial number với thiết bị chào thầu
5. Phân loại: Cell / Rack / System / PCS / NSX level

## Output
- Bảng so sánh Excel với mã màu ĐẠT/THIẾU
- Danh sách chứng chỉ kèm file reference
- Gap analysis chi tiết
