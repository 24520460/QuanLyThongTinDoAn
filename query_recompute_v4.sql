USE QuanLyHocTap1;
GO

-- ============================================================
-- query_recompute_v4.sql
--
-- Dùng SAU KHI nạp dữ liệu seed (data nạp trước khi trigger
-- trg_TinhBangDiem được tạo) để tính lại BANGDIEM thủ công
-- theo công thức ĐÚNG (chuẩn hóa thang 10 theo DIEMTOIDA).
--
-- Sau lần này, các trigger v4 sẽ tự lo cho mọi INSERT/UPDATE
-- trên BAINOP và HIENDIEN.
--
-- KHÁC v3:
--   ✅ AVG(DIEM * 10.0 / DIEMTOIDA) thay vì AVG(DIEM)
--      → tránh tràn CHECK DIEM <= 10 của BANGDIEM khi BAITAP
--        có DIEMTOIDA khác 10.
-- ============================================================
MERGE BANGDIEM AS bd
USING (
    SELECT
        bn.MATHAMGIA,
        AVG(bn.DIEM * 10.0 / NULLIF(bt.DIEMTOIDA, 0)) AS DiemTB
    FROM BAINOP bn
    JOIN BAITAP bt ON bt.MABT = bn.MABT
    WHERE bn.DIEM IS NOT NULL
    GROUP BY bn.MATHAMGIA
) AS src
ON bd.MATHAMGIA = src.MATHAMGIA
WHEN MATCHED THEN
    UPDATE SET
        bd.DIEM        = src.DiemTB,
        bd.XEPLOAI     = CASE
                            WHEN src.DiemTB >= 8.5 THEN N'Giỏi'
                            WHEN src.DiemTB >= 7.0 THEN N'Khá'
                            WHEN src.DiemTB >= 5.0 THEN N'Trung bình'
                            ELSE N'Yếu'
                         END,
        bd.NGAYCAPNHAT = GETDATE()
WHEN NOT MATCHED THEN
    INSERT (MATHAMGIA, DIEM, XEPLOAI, NGAYCAPNHAT)
    VALUES (
        src.MATHAMGIA,
        src.DiemTB,
        CASE
            WHEN src.DiemTB >= 8.5 THEN N'Giỏi'
            WHEN src.DiemTB >= 7.0 THEN N'Khá'
            WHEN src.DiemTB >= 5.0 THEN N'Trung bình'
            ELSE N'Yếu'
        END,
        GETDATE()
    );
GO


-- ============================================================
-- Tính lại CANHBAO cảnh báo điểm cho học viên đã có BANGDIEM
-- (dùng cho lần đầu, sau khi MERGE BANGDIEM ở trên)
-- ============================================================
MERGE CANHBAO AS cb
USING (
    SELECT
        tg.MAND,
        tg.MALH,
        bd.DIEM,
        CASE
            WHEN bd.DIEM >= 5 THEN N'Đạt'
            WHEN bd.DIEM >= 3 THEN N'Nguy cơ'
            ELSE N'Nguy cơ cao'
        END AS LOAI,
        N'Điểm tổng kết: ' + CAST(ROUND(bd.DIEM, 2) AS NVARCHAR(10)) AS NOIDUNG
    FROM BANGDIEM bd
    JOIN THAMGIALOP tg ON tg.MATHAMGIA = bd.MATHAMGIA
    WHERE bd.DIEM IS NOT NULL
) AS src
   ON cb.MAND = src.MAND
  AND cb.MALH = src.MALH
  AND cb.NGUONCB = N'Điểm'
WHEN MATCHED THEN
    UPDATE SET
        cb.LOAICB  = src.LOAI,
        cb.NOIDUNG = src.NOIDUNG,
        cb.NGAYTAO = GETDATE(),
        cb.DADOC   = 0
WHEN NOT MATCHED THEN
    INSERT (MAND, MALH, NGUONCB, LOAICB, NOIDUNG, NGAYTAO, DADOC)
    VALUES (src.MAND, src.MALH, N'Điểm', src.LOAI, src.NOIDUNG, GETDATE(), 0);
GO


-- ============================================================
-- Tính lại CANHBAO cảnh báo chuyên cần dựa trên HIENDIEN hiện tại
-- ============================================================
MERGE CANHBAO AS cb
USING (
    SELECT
        tg.MAND,
        tg.MALH,
        COUNT(*)                                                    AS TONG_BUOI,
        SUM(CASE WHEN hd.TRANGTHAI = N'Vắng mặt' THEN 1 ELSE 0 END) AS SO_VANG,
        CAST(SUM(CASE WHEN hd.TRANGTHAI = N'Vắng mặt' THEN 1 ELSE 0 END) AS FLOAT)
            / NULLIF(COUNT(*), 0)                                   AS TY_LE_VANG
    FROM HIENDIEN hd
    JOIN THAMGIALOP tg ON tg.MATHAMGIA = hd.MATHAMGIA
    GROUP BY tg.MAND, tg.MALH
) AS src
   ON cb.MAND = src.MAND
  AND cb.MALH = src.MALH
  AND cb.NGUONCB = N'Chuyên cần'
WHEN MATCHED THEN
    UPDATE SET
        cb.LOAICB  = CASE
                        WHEN src.TY_LE_VANG > 0.4 THEN N'Nguy cơ cao'
                        WHEN src.TY_LE_VANG > 0.2 THEN N'Nguy cơ'
                        ELSE N'Đạt'
                     END,
        cb.NOIDUNG = N'Tỷ lệ vắng học: '
                       + CAST(ROUND(src.TY_LE_VANG * 100, 1) AS NVARCHAR(10)) + N'%'
                       + N' (' + CAST(src.SO_VANG AS NVARCHAR(5))
                       + N'/' + CAST(src.TONG_BUOI AS NVARCHAR(5)) + N' buổi)',
        cb.NGAYTAO = GETDATE(),
        cb.DADOC   = 0
WHEN NOT MATCHED THEN
    INSERT (MAND, MALH, NGUONCB, LOAICB, NOIDUNG, NGAYTAO, DADOC)
    VALUES (
        src.MAND, src.MALH, N'Chuyên cần',
        CASE
            WHEN src.TY_LE_VANG > 0.4 THEN N'Nguy cơ cao'
            WHEN src.TY_LE_VANG > 0.2 THEN N'Nguy cơ'
            ELSE N'Đạt'
        END,
        N'Tỷ lệ vắng học: '
            + CAST(ROUND(src.TY_LE_VANG * 100, 1) AS NVARCHAR(10)) + N'%'
            + N' (' + CAST(src.SO_VANG AS NVARCHAR(5))
            + N'/' + CAST(src.TONG_BUOI AS NVARCHAR(5)) + N' buổi)',
        GETDATE(), 0
    );
GO
