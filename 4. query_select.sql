USE QuanLyHocTap;
GO

-- ============================================================
-- query_select_v4.sql — Query SELECT khớp với schema v4
--
-- Khác biệt so với phiên bản cũ:
--   • Query 4: dùng ISNULL cho học viên chưa có điểm
--   • Query 5: lọc thêm tg.TRANGTHAI = N'Đang học'
--   • Query 6: bản DEMO (theo dữ liệu) + bản PRODUCTION
--   • Query 7: thêm DISTINCT, lọc Đang học, bỏ JOIN LOPHOC thừa
--   • Query 9: cảnh báo có thêm cột NGUONCB (Điểm/Chuyên cần)
-- ============================================================


-- ============================================================
-- 1. Danh sách tất cả người dùng kèm vai trò
-- ============================================================
SELECT
    nd.MAND,
    nd.TENHT       AS [Họ tên],
    nd.EMAIL,
    nd.SDT,
    vt.TENVT       AS [Vai trò],
    nd.TRANGTHAI
FROM NGUOIDUNG nd
JOIN VAITRO vt ON nd.MAVT = vt.MAVT
ORDER BY vt.TENVT, nd.TENHT;
GO


-- ============================================================
-- 2. Danh sách lớp học đang mở, kèm tên môn và tên giáo viên
-- ============================================================
SELECT
    lh.MALH,
    lh.TENLH              AS [Tên lớp],
    mh.TENMH              AS [Môn học],
    nd.TENHT              AS [Giáo viên],
    lh.LOAILH             AS [Hình thức],
    lh.SOSVTOIDA          AS [Sĩ số tối đa],
    lh.NGAYBATDAU         AS [Ngày bắt đầu],
    lh.NGAYKETTHUC        AS [Ngày kết thúc]
FROM LOPHOC lh
JOIN MONHOC    mh ON lh.MAMH = mh.MAMH
JOIN NGUOIDUNG nd ON lh.MAND = nd.MAND
WHERE lh.TRANGTHAI = N'Đang mở'
ORDER BY lh.NGAYBATDAU;
GO


-- ============================================================
-- 3. Số học viên hiện tại trong mỗi lớp
-- ============================================================
SELECT
    lh.MALH,
    lh.TENLH                          AS [Tên lớp],
    lh.SOSVTOIDA                      AS [Sĩ số tối đa],
    COUNT(tg.MATHAMGIA)               AS [Số học viên],
    lh.SOSVTOIDA - COUNT(tg.MATHAMGIA) AS [Còn trống]
FROM LOPHOC lh
LEFT JOIN THAMGIALOP tg
       ON lh.MALH = tg.MALH
      AND tg.TRANGTHAI = N'Đang học'   -- ON, không phải WHERE → giữ LEFT JOIN
GROUP BY lh.MALH, lh.TENLH, lh.SOSVTOIDA
ORDER BY [Số học viên] DESC;
GO


-- ============================================================
-- 4. Điểm trung bình của từng học viên trong một lớp cụ thể
-- ============================================================
SELECT
    nd.TENHT                            AS [Học viên],
    nd.EMAIL,
    bd.DIEM                             AS [Điểm TB],
    ISNULL(bd.XEPLOAI, N'Chưa có điểm') AS [Xếp loại],
    tg.TRANGTHAI                        AS [Trạng thái học]
FROM THAMGIALOP tg
JOIN NGUOIDUNG nd  ON tg.MAND = nd.MAND
LEFT JOIN BANGDIEM bd ON bd.MATHAMGIA = tg.MATHAMGIA
WHERE tg.MALH = 1                       -- thay bằng MALH cần xem
ORDER BY ISNULL(bd.DIEM, -1) DESC;      -- NULL xuống cuối
GO


-- ============================================================
-- 5. Tỷ lệ chuyên cần (chỉ tính học viên đang học)
-- ============================================================
SELECT
    nd.TENHT              AS [Học viên],
    lh.TENLH              AS [Lớp],
    COUNT(hd.MAHD)                                            AS [Tổng buổi],
    SUM(CASE WHEN hd.TRANGTHAI = N'Có mặt'  THEN 1 ELSE 0 END) AS [Có mặt],
    SUM(CASE WHEN hd.TRANGTHAI = N'Vắng mặt' THEN 1 ELSE 0 END) AS [Vắng],
    CONVERT(NVARCHAR(20),
        CAST(
            ROUND(
                100.0 * SUM(CASE WHEN hd.TRANGTHAI = N'Có mặt' THEN 1 ELSE 0 END)
                      / NULLIF(COUNT(hd.MAHD), 0)
            , 1)
        AS DECIMAL(5,1))
    ) + N'%'                                                   AS [Tỷ lệ chuyên cần]
FROM HIENDIEN hd
JOIN THAMGIALOP tg ON hd.MATHAMGIA = tg.MATHAMGIA
JOIN NGUOIDUNG  nd ON tg.MAND = nd.MAND
JOIN LOPHOC     lh ON tg.MALH = lh.MALH
WHERE tg.TRANGTHAI = N'Đang học'    -- chỉ tính học viên đang học
GROUP BY nd.TENHT, lh.TENLH
ORDER BY lh.TENLH,
         100.0 * SUM(CASE WHEN hd.TRANGTHAI = N'Có mặt' THEN 1 ELSE 0 END)
              / NULLIF(COUNT(hd.MAHD), 0) DESC;
GO


-- ============================================================
-- 6. Bài tập sắp hết hạn trong 7 ngày tới
-- ============================================================
-- (A) Bản DEMO: dùng ngày sớm nhất trong BAITAP làm mốc, để
--     vẫn thấy kết quả khi data demo đã cũ.
DECLARE @today DATE = (SELECT MIN(CAST(NGAYTAO AS DATE)) FROM BAITAP);

SELECT
    bt.MABT,
    lh.TENLH                          AS [Lớp],
    bt.TIEUDE                         AS [Bài tập],
    bt.HANNOP                         AS [Hạn nộp],
    bt.DIEMTOIDA                      AS [Điểm tối đa],
    DATEDIFF(DAY, @today, bt.HANNOP)  AS [Còn lại (ngày)]
FROM BAITAP bt
JOIN LOPHOC lh ON bt.MALH = lh.MALH
WHERE bt.HANNOP BETWEEN @today AND DATEADD(DAY, 7, @today)
ORDER BY bt.HANNOP;
GO

-- (B) Bản PRODUCTION: dùng GETDATE() thật. Bỏ comment khi chạy thật.
--
-- SELECT
--     bt.MABT, lh.TENLH AS [Lớp], bt.TIEUDE AS [Bài tập],
--     bt.HANNOP AS [Hạn nộp], bt.DIEMTOIDA AS [Điểm tối đa],
--     DATEDIFF(DAY, CAST(GETDATE() AS DATE), bt.HANNOP) AS [Còn lại (ngày)]
-- FROM BAITAP bt
-- JOIN LOPHOC lh ON bt.MALH = lh.MALH
-- WHERE bt.HANNOP BETWEEN CAST(GETDATE() AS DATE)
--                     AND DATEADD(DAY, 7, CAST(GETDATE() AS DATE))
-- ORDER BY bt.HANNOP;


-- ============================================================
-- 7. Học viên (đang học) chưa nộp bài tập nào
-- ============================================================
SELECT DISTINCT
    nd.TENHT          AS [Học viên],
    lh.TENLH          AS [Lớp],
    bt.TIEUDE         AS [Bài tập chưa nộp],
    bt.HANNOP         AS [Hạn nộp]
FROM THAMGIALOP tg
JOIN NGUOIDUNG nd ON tg.MAND  = nd.MAND
JOIN LOPHOC    lh ON lh.MALH  = tg.MALH
JOIN BAITAP    bt ON bt.MALH  = tg.MALH
WHERE tg.TRANGTHAI = N'Đang học'    -- chỉ học viên đang học
  AND NOT EXISTS (
        SELECT 1 FROM BAINOP bn
        WHERE bn.MABT = bt.MABT
          AND bn.MATHAMGIA = tg.MATHAMGIA
  )
ORDER BY lh.TENLH, nd.TENHT, bt.HANNOP;
GO


-- ============================================================
-- 8. Top 5 giáo viên có nhiều lớp đang dạy nhất
-- ============================================================
SELECT TOP 5
    nd.TENHT              AS [Giáo viên],
    nd.EMAIL,
    COUNT(lh.MALH)        AS [Số lớp đang dạy]
FROM NGUOIDUNG nd
JOIN LOPHOC lh ON lh.MAND = nd.MAND
WHERE lh.TRANGTHAI = N'Đang mở'
GROUP BY nd.MAND, nd.TENHT, nd.EMAIL
ORDER BY [Số lớp đang dạy] DESC;
GO


-- ============================================================
-- 9. Cảnh báo chưa đọc, sắp xếp theo mức độ nghiêm trọng
--    [v4] Hiển thị thêm cột NGUONCB để biết cảnh báo về điểm
--         hay chuyên cần.
-- ============================================================
SELECT
    nd.TENHT          AS [Học viên],
    lh.TENLH          AS [Lớp],
    cb.NGUONCB        AS [Nguồn cảnh báo],
    cb.LOAICB         AS [Mức cảnh báo],
    cb.NOIDUNG        AS [Nội dung],
    cb.NGAYTAO        AS [Ngày tạo]
FROM CANHBAO cb
JOIN NGUOIDUNG nd ON cb.MAND = nd.MAND
JOIN LOPHOC    lh ON cb.MALH = lh.MALH
WHERE cb.DADOC = 0
ORDER BY
    CASE cb.LOAICB
        WHEN N'Nguy cơ cao' THEN 1
        WHEN N'Nguy cơ'     THEN 2
        ELSE 3
    END,
    cb.NGAYTAO DESC;
GO


-- ============================================================
-- 10. Thống kê tổng quan toàn hệ thống
-- ============================================================
SELECT
    (SELECT COUNT(*) FROM NGUOIDUNG)                                 AS [Tổng người dùng],
    (SELECT COUNT(*) FROM LOPHOC WHERE TRANGTHAI = N'Đang mở')       AS [Lớp đang mở],
    (SELECT COUNT(*) FROM THAMGIALOP WHERE TRANGTHAI = N'Đang học')  AS [Học viên đang học],
    (SELECT COUNT(*) FROM BAITAP
        WHERE HANNOP >= CAST(GETDATE() AS DATE))                     AS [Bài tập còn hiệu lực],
    (SELECT COUNT(*) FROM CANHBAO WHERE DADOC = 0)                   AS [Cảnh báo chưa đọc];
GO
