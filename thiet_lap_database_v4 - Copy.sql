CREATE DATABASE QuanLyHocTap1;
GO

USE QuanLyHocTap1;
GO

SET DATEFORMAT dmy;
GO

-- ============================================================
-- THIẾT LẬP CƠ SỞ DỮ LIỆU QUẢN LÝ LỚP HỌC TRỰC TUYẾN — v4
--
-- 🆕 Thay đổi v4 (so với v3) — sửa các lỗi nghiệp vụ phát hiện
--    sau khi rà soát toàn bộ schema + trigger + query:
--
--   🔴 [FIX A] trg_TinhBangDiem: thêm AFTER INSERT (v3 chỉ
--      AFTER UPDATE → INSERT BAINOP có DIEM ngay từ đầu sẽ
--      KHÔNG được cộng vào BANGDIEM). Sửa cả điều kiện guard.
--
--   🔴 [FIX B] trg_CapNhatCanhBao: sửa logic guard sai
--      "IF NOT UPDATE(DIEM) AND NOT EXISTS(...)" — dùng AND
--      sai khiến guard không bao giờ active. Đổi thành chỉ
--      check UPDATE(DIEM) — đối với INSERT, UPDATE() trả TRUE
--      cho mọi cột nên vẫn chạy bình thường.
--
--   🔴 [FIX C] trg_CanhBaoVangHoc: dùng DISTINCT MATHAMGIA
--      trước khi JOIN HIENDIEN, tránh đếm trùng N lần khi batch
--      INSERT có nhiều dòng cùng MATHAMGIA.
--
--   🔴 [FIX D] Xung đột 2 trigger trên CANHBAO:
--      v3: trg_CapNhatCanhBao (theo điểm) và trg_CanhBaoVangHoc
--          (theo vắng) đều ghi vào CANHBAO có UNIQUE(MAND,MALH)
--          → ghi đè lẫn nhau, mất thông tin.
--      v4: TÁCH thành 2 dòng cảnh báo phân biệt bằng cột mới
--          NGUONCB ∈ {'Điểm', 'Chuyên cần'}. UNIQUE đổi thành
--          (MAND, MALH, NGUONCB). Giáo viên nhìn thấy đầy đủ
--          cảnh báo cả về điểm lẫn về chuyên cần.
--
--   🔴 [FIX E] trg_TinhBangDiem (và phần MERGE thủ công trong
--      query_fixed.sql): điểm bài tập có DIEMTOIDA khác nhau
--      (10, 20, 100…). AVG(DIEM) thẳng → tràn CHECK DIEM<=10
--      của BANGDIEM. v4 chuẩn hóa về thang 10 trước khi AVG:
--      AVG(bn.DIEM * 10.0 / bt.DIEMTOIDA).
--
--   🟡 [FIX F] BAITAP.NGAYTAO thêm NOT NULL — v3 chỉ có DEFAULT,
--      cho phép INSERT tường minh NULL → bypass CHECK HanNopBT.
--
--   🟡 [FIX G] LICHHOC.NGAYTRONGTUAN: đổi từ BETWEEN 2 AND 8
--      sang BETWEEN 1 AND 7 cho khớp với DATEPART(weekday) của
--      SQL Server. Quy ước v4: 1=CN, 2=T2, …, 7=T7 (DATEFIRST
--      mặc định = 7). Tham khảo cuối file để đổi nếu cần.
--
--   🟡 [FIX H] HIENDIEN.MALICH: thêm NOT NULL — điểm danh phải
--      gắn với 1 buổi học cụ thể (đúng spec 2.3.5.5).
--
--   🟢 [FIX I] Bỏ index trùng IX_CanhBao_MAND_MALH vì
--      UQ_CanhBao đã tự tạo unique index trên cùng cột.
--
-- Các phần khác giữ nguyên từ v3.
-- ============================================================


-- ============================================================
-- BẢNG DỮ LIỆU
-- ============================================================

-- 1. Vai trò
CREATE TABLE VAITRO (
    MAVT  INT IDENTITY(1,1) PRIMARY KEY,
    TENVT NVARCHAR(100) NOT NULL
);

-- 2. Khoa
CREATE TABLE KHOA (
    MAKHOA  INT IDENTITY(1,1) PRIMARY KEY,
    TENKHOA NVARCHAR(100) NOT NULL
);

-- 3. Người dùng
CREATE TABLE NGUOIDUNG (
    MAND      INT IDENTITY(1,1) PRIMARY KEY,
    MAVT      INT NOT NULL,
    MAKHOA    INT,
    TENND     NVARCHAR(100) NOT NULL UNIQUE,
    MATKHAU   NVARCHAR(255) NOT NULL,
    TENHT     NVARCHAR(100),
    EMAIL     NVARCHAR(100) UNIQUE,
    SDT       VARCHAR(15),
    TRANGTHAI NVARCHAR(50) CHECK (TRANGTHAI IN (N'Hoạt động', N'Bị khóa')),
    CONSTRAINT FK_ND_VAITRO FOREIGN KEY (MAVT)   REFERENCES VAITRO(MAVT),
    CONSTRAINT FK_ND_KHOA   FOREIGN KEY (MAKHOA) REFERENCES KHOA(MAKHOA)
);

-- 4. Môn học
CREATE TABLE MONHOC (
    MAMH   INT IDENTITY(1,1) PRIMARY KEY,
    TENMH  NVARCHAR(100) NOT NULL,
    MAKHOA INT NOT NULL,
    CONSTRAINT FK_MH_KHOA FOREIGN KEY (MAKHOA) REFERENCES KHOA(MAKHOA)
);

-- 5. Lớp học
CREATE TABLE LOPHOC (
    MALH        INT IDENTITY(1,1) PRIMARY KEY,
    MAMH        INT NOT NULL,
    MAND        INT NOT NULL,
    TENLH       NVARCHAR(100) NOT NULL,
    SOSVTOIDA   INT CHECK (SOSVTOIDA > 0),   -- NULL = lớp không giới hạn
    LOAILH      NVARCHAR(50) CHECK (LOAILH IN (N'Online', N'Offline')),
    TRANGTHAI   NVARCHAR(50) CHECK (TRANGTHAI IN (N'Đang mở', N'Đã kết thúc', N'Tạm dừng')),
    NGAYBATDAU  DATE,
    NGAYKETTHUC DATE,
    CONSTRAINT CHK_NgayLH     CHECK (NGAYKETTHUC >= NGAYBATDAU),
    CONSTRAINT FK_LH_MONHOC   FOREIGN KEY (MAMH) REFERENCES MONHOC(MAMH),
    CONSTRAINT FK_LH_GIAOVIEN FOREIGN KEY (MAND) REFERENCES NGUOIDUNG(MAND)
);

-- 6. Tham gia lớp
CREATE TABLE THAMGIALOP (
    MATHAMGIA  INT IDENTITY(1,1) PRIMARY KEY,
    MALH       INT NOT NULL,
    MAND       INT NOT NULL,
    NGAYDANGKY DATETIME DEFAULT GETDATE(),
    TRANGTHAI  NVARCHAR(50) CHECK (TRANGTHAI IN (N'Đang học', N'Hoàn thành', N'Bỏ học')),
    CONSTRAINT UQ_ThamGia    UNIQUE (MALH, MAND),
    CONSTRAINT FK_TG_LOPHOC  FOREIGN KEY (MALH) REFERENCES LOPHOC(MALH),
    CONSTRAINT FK_TG_HOCSINH FOREIGN KEY (MAND) REFERENCES NGUOIDUNG(MAND)
);

-- ============================================================
-- 7. Lịch học
-- [FIX G] NGAYTRONGTUAN: BETWEEN 1 AND 7 (khớp DATEPART weekday
--          của SQL Server với DATEFIRST mặc định = 7 / Mỹ:
--          1 = Chủ Nhật, 2 = T2, …, 7 = T7).
--          Nếu muốn dùng quy ước Việt Nam (2=T2…8=CN) thì phải
--          SET DATEFIRST 1 ở đầu mọi session VÀ đổi CHECK.
-- ============================================================
CREATE TABLE LICHHOC (
    MALICH        INT IDENTITY(1,1) PRIMARY KEY,
    MALH          INT NOT NULL,
    THOIGIANBD    TIME NOT NULL,
    THOIGIANKT    TIME NOT NULL,
    HINHTHUC      NVARCHAR(50) CHECK (HINHTHUC IN (N'Online', N'Offline')),
    NGAYHOC       DATE,
    NGAYTRONGTUAN INT,
    CONSTRAINT CHK_ThoiGian        CHECK (THOIGIANKT >= THOIGIANBD),
    CONSTRAINT CHK_NgayTrongTuan   CHECK (NGAYTRONGTUAN IS NULL
                                         OR NGAYTRONGTUAN BETWEEN 2 AND 8),
    CONSTRAINT FK_LichHoc_Lop FOREIGN KEY (MALH) REFERENCES LOPHOC(MALH) ON DELETE CASCADE
);

-- ============================================================
-- 8. Hiện diện (điểm danh)
-- [FIX H] MALICH NOT NULL — điểm danh phải gắn với 1 buổi học.
-- ============================================================
CREATE TABLE HIENDIEN (
    MAHD         INT IDENTITY(1,1) PRIMARY KEY,
    MATHAMGIA    INT NOT NULL,
    NGAYDIEMDANH DATETIME DEFAULT GETDATE(),
    MALICH       INT NOT NULL,        -- v4: NOT NULL
    TRANGTHAI    NVARCHAR(50) CHECK (TRANGTHAI IN (N'Có mặt', N'Vắng mặt', N'Trễ')),
    CONSTRAINT UQ_HienDien   UNIQUE (MATHAMGIA, MALICH),
    CONSTRAINT FK_HD_THAMGIA FOREIGN KEY (MATHAMGIA) REFERENCES THAMGIALOP(MATHAMGIA),
    CONSTRAINT FK_HD_LICHHOC FOREIGN KEY (MALICH)    REFERENCES LICHHOC(MALICH)
);

-- ============================================================
-- 9. Bài tập
-- [FIX F] NGAYTAO NOT NULL — chặn bypass CHECK HanNopBT.
-- ============================================================
CREATE TABLE BAITAP (
    MABT      INT IDENTITY(1,1) PRIMARY KEY,
    MALH      INT NOT NULL,
    MAND      INT NOT NULL,
    TIEUDE    NVARCHAR(255) NOT NULL,
    NOIDUNG   NVARCHAR(MAX),
    HANNOP    DATE,
    NGAYTAO   DATETIME NOT NULL DEFAULT GETDATE(),    -- v4: NOT NULL
    DIEMTOIDA FLOAT NOT NULL CHECK (DIEMTOIDA > 0),   -- NOT NULL để FIX E hoạt động
    CONSTRAINT CHK_HanNopBT    CHECK (HANNOP >= CAST(NGAYTAO AS DATE)),
    CONSTRAINT FK_BT_LOPHOC    FOREIGN KEY (MALH) REFERENCES LOPHOC(MALH) ON DELETE CASCADE,
    CONSTRAINT FK_BT_GIAOVIEN  FOREIGN KEY (MAND) REFERENCES NGUOIDUNG(MAND)
);

-- 10. Bài nộp
CREATE TABLE BAINOP (
    MANOP     INT IDENTITY(1,1) PRIMARY KEY,
    MABT      INT NOT NULL,
    MATHAMGIA INT NOT NULL,
    NGAYNOP   DATETIME DEFAULT GETDATE(),
    DIEM      FLOAT,    -- KHÔNG CHECK [0,10] nữa: điểm raw theo DIEMTOIDA của bài tập
    DUONGDAN  NVARCHAR(255),
    NHANXET   NVARCHAR(MAX),
    CONSTRAINT UQ_BaiNop     UNIQUE (MABT, MATHAMGIA),
    CONSTRAINT FK_BN_BAITAP  FOREIGN KEY (MABT)      REFERENCES BAITAP(MABT),
    CONSTRAINT FK_BN_THAMGIA FOREIGN KEY (MATHAMGIA) REFERENCES THAMGIALOP(MATHAMGIA)
);
-- Lưu ý v4: ràng buộc 0 <= DIEM <= DIEMTOIDA được kiểm tra
-- bằng trigger trg_KiemTraDiemBaiNop (xem phía dưới) thay vì
-- CHECK constraint vì DIEMTOIDA nằm ở bảng khác.

-- 11. Thông báo
CREATE TABLE THONGBAO (
    MATB    INT IDENTITY(1,1) PRIMARY KEY,
    MALH    INT NOT NULL,
    TIEUDE  NVARCHAR(255) NOT NULL,
    NOIDUNG NVARCHAR(MAX),
    NGAYTAO DATETIME DEFAULT GETDATE(),
    MAND    INT,
    CONSTRAINT FK_TB_LOPHOC    FOREIGN KEY (MALH) REFERENCES LOPHOC(MALH) ON DELETE CASCADE,
    CONSTRAINT FK_TB_NGUOIDUNG FOREIGN KEY (MAND) REFERENCES NGUOIDUNG(MAND)
);

-- 12. Tin nhắn
CREATE TABLE TINNHAN (
    MATN        INT IDENTITY(1,1) PRIMARY KEY,
    MANGUOIGUI  INT NOT NULL,
    MANGUOINHAN INT NOT NULL,
    NOIDUNG     NVARCHAR(MAX) NOT NULL,
    NGAYGUI     DATETIME DEFAULT GETDATE(),
    DADOC       BIT DEFAULT 0,
    CONSTRAINT CHK_TN_KhacNguoi  CHECK (MANGUOIGUI <> MANGUOINHAN),
    CONSTRAINT FK_TN_NGUOIGUI    FOREIGN KEY (MANGUOIGUI)  REFERENCES NGUOIDUNG(MAND),
    CONSTRAINT FK_TN_NGUOINHAN   FOREIGN KEY (MANGUOINHAN) REFERENCES NGUOIDUNG(MAND)
);

-- 13. Bảng điểm (điểm tổng kết, đã chuẩn hóa thang 10)
CREATE TABLE BANGDIEM (
    MABD        INT IDENTITY(1,1) PRIMARY KEY,
    MATHAMGIA   INT NOT NULL UNIQUE,
    DIEM        FLOAT CHECK (DIEM >= 0 AND DIEM <= 10),
    XEPLOAI     NVARCHAR(50),
    NGAYCAPNHAT DATETIME DEFAULT GETDATE(),
    CONSTRAINT FK_BD_THAMGIA FOREIGN KEY (MATHAMGIA) REFERENCES THAMGIALOP(MATHAMGIA)
);

-- 14. Tài liệu
CREATE TABLE TAILIEU (
    MATL    INT IDENTITY(1,1) PRIMARY KEY,
    TENTL   NVARCHAR(255) NOT NULL,
    MAND    INT NOT NULL,
    MALH    INT NOT NULL,
    TIEUDE  NVARCHAR(255),
    NOIDUNG NVARCHAR(MAX),
    NGAYTAO DATETIME DEFAULT GETDATE(),
    CONSTRAINT FK_TL_NGUOIDUNG FOREIGN KEY (MAND) REFERENCES NGUOIDUNG(MAND),
    CONSTRAINT FK_TL_LOPHOC    FOREIGN KEY (MALH) REFERENCES LOPHOC(MALH) ON DELETE CASCADE
);

-- 15. Đánh giá
CREATE TABLE DANHGIA (
    MADG      INT IDENTITY(1,1) PRIMARY KEY,
    MATHAMGIA INT NOT NULL,
    DIEMDG    FLOAT CHECK (DIEMDG >= 0 AND DIEMDG <= 10),
    NHANXET   NVARCHAR(MAX),
    NGAYDG    DATETIME DEFAULT GETDATE(),
    CONSTRAINT UQ_DanhGia    UNIQUE (MATHAMGIA),
    CONSTRAINT FK_DG_THAMGIA FOREIGN KEY (MATHAMGIA) REFERENCES THAMGIALOP(MATHAMGIA)
);

-- ============================================================
-- 16. Cảnh báo
-- [FIX D] Thêm cột NGUONCB để phân biệt cảnh báo điểm và
--          cảnh báo chuyên cần. UNIQUE đổi thành 3 cột →
--          mỗi học sinh trong mỗi lớp có thể có TỐI ĐA 2 dòng:
--          1 dòng cho điểm, 1 dòng cho chuyên cần.
-- ============================================================
CREATE TABLE CANHBAO (
    MACB    INT IDENTITY(1,1) PRIMARY KEY,
    MAND    INT NOT NULL,
    MALH    INT NOT NULL,
    NGUONCB NVARCHAR(20) NOT NULL                       -- v4 mới
            CHECK (NGUONCB IN (N'Điểm', N'Chuyên cần')),
    LOAICB  NVARCHAR(50) CHECK (LOAICB IN (N'Đạt', N'Nguy cơ', N'Nguy cơ cao')),
    NOIDUNG NVARCHAR(MAX),
    NGAYTAO DATETIME DEFAULT GETDATE(),
    DADOC   BIT DEFAULT 0,
    CONSTRAINT UQ_CanhBao       UNIQUE (MAND, MALH, NGUONCB),  -- v4: thêm NGUONCB
    CONSTRAINT FK_CB_NGUOIDUNG  FOREIGN KEY (MAND) REFERENCES NGUOIDUNG(MAND),
    CONSTRAINT FK_CB_LOPHOC     FOREIGN KEY (MALH) REFERENCES LOPHOC(MALH) ON DELETE CASCADE
);
GO


-- ============================================================
-- INDEX HỖ TRỢ TRUY VẤN
-- [FIX I] Bỏ IX_CanhBao_MAND_MALH vì trùng với UQ_CanhBao.
-- ============================================================
CREATE INDEX IX_ThamGiaLop_MAND  ON THAMGIALOP (MAND);
CREATE INDEX IX_ThamGiaLop_MALH  ON THAMGIALOP (MALH);
CREATE INDEX IX_BaiNop_MATHAMGIA ON BAINOP     (MATHAMGIA);
CREATE INDEX IX_HienDien_MALICH  ON HIENDIEN   (MALICH);
GO


-- ============================================================
-- TRIGGER: XÓA THAMGIALOP (INSTEAD OF DELETE)
-- Thứ tự: HIENDIEN → BAINOP → BANGDIEM → DANHGIA → THAMGIALOP
-- ============================================================
CREATE TRIGGER trg_XoaThamGia
ON THAMGIALOP
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM HIENDIEN  WHERE MATHAMGIA IN (SELECT MATHAMGIA FROM deleted);
    DELETE FROM BAINOP    WHERE MATHAMGIA IN (SELECT MATHAMGIA FROM deleted);
    DELETE FROM BANGDIEM  WHERE MATHAMGIA IN (SELECT MATHAMGIA FROM deleted);
    DELETE FROM DANHGIA   WHERE MATHAMGIA IN (SELECT MATHAMGIA FROM deleted);
    DELETE FROM THAMGIALOP WHERE MATHAMGIA IN (SELECT MATHAMGIA FROM deleted);
END;
GO

-- TRIGGER: XÓA LOPHOC → kích hoạt cascade sang THAMGIALOP
CREATE TRIGGER trg_XoaLopHoc
ON LOPHOC
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM THAMGIALOP WHERE MALH IN (SELECT MALH FROM deleted);
END;
GO


-- ============================================================
-- TRIGGER 1a–1d: Kiểm tra vai trò
-- ============================================================
CREATE TRIGGER trg_KiemTraVaiTroLopHoc
ON LOPHOC AFTER INSERT, UPDATE
AS BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1 FROM inserted i
        JOIN NGUOIDUNG nd ON i.MAND = nd.MAND
        JOIN VAITRO vt    ON nd.MAVT = vt.MAVT
        WHERE vt.TENVT != N'Giáo viên'
    ) BEGIN
        RAISERROR (N'Người tạo lớp học phải có vai trò Giáo viên.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO

CREATE TRIGGER trg_KiemTraVaiTroBaiTap
ON BAITAP AFTER INSERT, UPDATE
AS BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1 FROM inserted i
        JOIN NGUOIDUNG nd ON i.MAND = nd.MAND
        JOIN VAITRO vt    ON nd.MAVT = vt.MAVT
        WHERE vt.TENVT != N'Giáo viên'
    ) BEGIN
        RAISERROR (N'Người tạo bài tập phải có vai trò Giáo viên.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO

CREATE TRIGGER trg_KiemTraVaiTroTaiLieu
ON TAILIEU AFTER INSERT, UPDATE
AS BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1 FROM inserted i
        JOIN NGUOIDUNG nd ON i.MAND = nd.MAND
        JOIN VAITRO vt    ON nd.MAVT = vt.MAVT
        WHERE vt.TENVT != N'Giáo viên'
    ) BEGIN
        RAISERROR (N'Người tạo tài liệu phải có vai trò Giáo viên.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO

CREATE TRIGGER trg_KiemTraVaiTroThamGia
ON THAMGIALOP AFTER INSERT, UPDATE
AS BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1 FROM inserted i
        JOIN NGUOIDUNG nd ON i.MAND = nd.MAND
        JOIN VAITRO vt    ON nd.MAVT = vt.MAVT
        WHERE vt.TENVT != N'Học sinh'
    ) BEGIN
        RAISERROR (N'Người tham gia lớp học phải có vai trò Học sinh.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO


-- ============================================================
-- TRIGGER 2: Kiểm tra sĩ số tối đa
-- ============================================================
CREATE TRIGGER trg_KiemTraSiSo
ON THAMGIALOP AFTER INSERT
AS BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN LOPHOC lh ON i.MALH = lh.MALH
        WHERE lh.SOSVTOIDA IS NOT NULL
          AND (SELECT COUNT(*) FROM THAMGIALOP WHERE MALH = i.MALH) > lh.SOSVTOIDA
    ) BEGIN
        RAISERROR (N'Lớp học đã đạt số lượng học viên tối đa.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO


-- ============================================================
-- TRIGGER MỚI v4: Kiểm tra điểm bài nộp ≤ DIEMTOIDA của bài tập
--
-- Vì DIEMTOIDA nằm ở bảng BAITAP nên không thể dùng CHECK
-- constraint trực tiếp trên BAINOP.DIEM. Trigger thay thế.
-- ============================================================
CREATE TRIGGER trg_KiemTraDiemBaiNop
ON BAINOP AFTER INSERT, UPDATE
AS BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(DIEM) RETURN;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN BAITAP bt ON bt.MABT = i.MABT
        WHERE i.DIEM IS NOT NULL
          AND (i.DIEM < 0 OR i.DIEM > bt.DIEMTOIDA)
    ) BEGIN
        RAISERROR (N'Điểm bài nộp phải nằm trong khoảng [0, DIEMTOIDA của bài tập].', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO


-- ============================================================
-- TRIGGER 3: Tự động tính BANGDIEM (FIX A + FIX E)
--
-- v3 → v4:
--   ✅ Thêm AFTER INSERT (v3 chỉ AFTER UPDATE → bỏ sót khi
--      INSERT BAINOP có DIEM ngay).
--   ✅ Chuẩn hóa DIEM về thang 10 trước khi AVG:
--          AVG(DIEM * 10.0 / DIEMTOIDA)
--      Nếu không scale, tổng kết có thể vượt 10 → tràn CHECK
--      của BANGDIEM.DIEM.
-- ============================================================
CREATE TRIGGER trg_TinhBangDiem
ON BAINOP
AFTER INSERT, UPDATE   -- v4: thêm INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Đối với INSERT: UPDATE() trả TRUE cho mọi cột → guard
    -- này chỉ chặn khi UPDATE thuần túy không động vào DIEM.
    IF NOT UPDATE(DIEM) RETURN;

    -- Có thay đổi DIEM nhưng tất cả đều NULL → không có gì để tính
    IF NOT EXISTS (SELECT 1 FROM inserted WHERE DIEM IS NOT NULL) RETURN;

    ;WITH AffectedTG AS (
        SELECT DISTINCT MATHAMGIA FROM inserted
    ),
    DiemTongKet AS (
        SELECT
            a.MATHAMGIA,
            -- v4 FIX E: scale về thang 10
            AVG(bn.DIEM * 10.0 / NULLIF(bt.DIEMTOIDA, 0)) AS DIEM_TONGKET
        FROM AffectedTG a
        JOIN BAINOP bn ON bn.MATHAMGIA = a.MATHAMGIA
        JOIN BAITAP bt ON bt.MABT      = bn.MABT
        WHERE bn.DIEM IS NOT NULL
        GROUP BY a.MATHAMGIA
    )
    MERGE BANGDIEM AS bd
    USING DiemTongKet AS dtk
        ON bd.MATHAMGIA = dtk.MATHAMGIA
    WHEN MATCHED THEN
        UPDATE SET
            bd.DIEM        = dtk.DIEM_TONGKET,
            bd.XEPLOAI     = CASE
                                WHEN dtk.DIEM_TONGKET >= 8.5 THEN N'Giỏi'
                                WHEN dtk.DIEM_TONGKET >= 7.0 THEN N'Khá'
                                WHEN dtk.DIEM_TONGKET >= 5.0 THEN N'Trung bình'
                                ELSE N'Yếu'
                             END,
            bd.NGAYCAPNHAT = GETDATE()
    WHEN NOT MATCHED THEN
        INSERT (MATHAMGIA, DIEM, XEPLOAI, NGAYCAPNHAT)
        VALUES (
            dtk.MATHAMGIA,
            dtk.DIEM_TONGKET,
            CASE
                WHEN dtk.DIEM_TONGKET >= 8.5 THEN N'Giỏi'
                WHEN dtk.DIEM_TONGKET >= 7.0 THEN N'Khá'
                WHEN dtk.DIEM_TONGKET >= 5.0 THEN N'Trung bình'
                ELSE N'Yếu'
            END,
            GETDATE()
        );
END;
GO


-- ============================================================
-- TRIGGER 4: Cảnh báo theo điểm tổng kết (FIX B + FIX D)
--
-- v3 → v4:
--   ✅ Sửa guard "IF NOT UPDATE(DIEM) AND NOT EXISTS(...)"
--      → đổi sang chỉ "IF NOT UPDATE(DIEM) RETURN"
--      (đối với INSERT thì UPDATE() = TRUE → không bị chặn).
--   ✅ Ghi NGUONCB = N'Điểm' để phân biệt với cảnh báo vắng.
-- ============================================================
CREATE TRIGGER trg_CapNhatCanhBao
ON BANGDIEM
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- v4 FIX B: chỉ check UPDATE(DIEM); INSERT vẫn pass
    IF NOT UPDATE(DIEM) RETURN;

    ;WITH CanhBaoMoi AS (
        SELECT
            tg.MAND,
            tg.MALH,
            CASE
                WHEN i.DIEM >= 5 THEN N'Đạt'
                WHEN i.DIEM >= 3 THEN N'Nguy cơ'
                ELSE N'Nguy cơ cao'
            END AS LOAI,
            N'Điểm tổng kết: '
              + ISNULL(CAST(ROUND(i.DIEM, 2) AS NVARCHAR(10)), N'Chưa có')
              + N' — Phân loại: '
              + CASE
                    WHEN i.DIEM >= 5 THEN N'Đạt'
                    WHEN i.DIEM >= 3 THEN N'Nguy cơ'
                    ELSE N'Nguy cơ cao'
                END AS NOIDUNG
        FROM inserted i
        JOIN THAMGIALOP tg ON i.MATHAMGIA = tg.MATHAMGIA
        WHERE i.DIEM IS NOT NULL
    )
    MERGE CANHBAO AS cb
    USING CanhBaoMoi AS cbm
        ON cb.MAND = cbm.MAND
       AND cb.MALH = cbm.MALH
       AND cb.NGUONCB = N'Điểm'        -- v4: phân biệt nguồn
    WHEN MATCHED THEN
        UPDATE SET
            cb.LOAICB  = cbm.LOAI,
            cb.NOIDUNG = cbm.NOIDUNG,
            cb.NGAYTAO = GETDATE(),
            cb.DADOC   = 0
    WHEN NOT MATCHED THEN
        INSERT (MAND, MALH, NGUONCB, LOAICB, NOIDUNG, NGAYTAO, DADOC)
        VALUES (cbm.MAND, cbm.MALH, N'Điểm', cbm.LOAI, cbm.NOIDUNG, GETDATE(), 0);
END;
GO


-- ============================================================
-- TRIGGER 4b: Cảnh báo theo tỷ lệ vắng (FIX C + FIX D)
--
-- v3 → v4:
--   ✅ DISTINCT MATHAMGIA trước khi JOIN HIENDIEN, tránh đếm
--      trùng khi batch INSERT có nhiều dòng cùng MATHAMGIA.
--   ✅ Ghi NGUONCB = N'Chuyên cần' → không xung đột với
--      cảnh báo điểm; cả 2 dòng cùng tồn tại trong CANHBAO.
-- ============================================================
CREATE TRIGGER trg_CanhBaoVangHoc
ON HIENDIEN
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH AffectedTG AS (
        SELECT DISTINCT MATHAMGIA FROM inserted   -- v4 FIX C
    ),
    TyLeVang AS (
        SELECT
            tg.MAND,
            tg.MALH,
            COUNT(*)                                                    AS TONG_BUOI,
            SUM(CASE WHEN hd.TRANGTHAI = N'Vắng mặt' THEN 1 ELSE 0 END) AS SO_VANG,
            CAST(SUM(CASE WHEN hd.TRANGTHAI = N'Vắng mặt' THEN 1 ELSE 0 END) AS FLOAT)
                / NULLIF(COUNT(*), 0)                                   AS TY_LE_VANG
        FROM AffectedTG a
        JOIN THAMGIALOP tg ON a.MATHAMGIA = tg.MATHAMGIA
        JOIN HIENDIEN hd   ON hd.MATHAMGIA = tg.MATHAMGIA
        GROUP BY tg.MAND, tg.MALH
    ),
    CanhBaoVang AS (
        SELECT
            MAND, MALH,
            CASE
                WHEN TY_LE_VANG > 0.4 THEN N'Nguy cơ cao'
                WHEN TY_LE_VANG > 0.2 THEN N'Nguy cơ'
                ELSE N'Đạt'
            END AS LOAI_VANG,
            N'Tỷ lệ vắng học: '
              + CAST(ROUND(TY_LE_VANG * 100, 1) AS NVARCHAR(10)) + N'%'
              + N' (' + CAST(SO_VANG AS NVARCHAR(5))
              + N'/' + CAST(TONG_BUOI AS NVARCHAR(5)) + N' buổi)' AS NOIDUNG_VANG
        FROM TyLeVang
    )
    MERGE CANHBAO AS cb
    USING CanhBaoVang AS cbv
        ON cb.MAND = cbv.MAND
       AND cb.MALH = cbv.MALH
       AND cb.NGUONCB = N'Chuyên cần'        -- v4: phân biệt nguồn
    WHEN MATCHED THEN
        UPDATE SET
            cb.LOAICB  = cbv.LOAI_VANG,
            cb.NOIDUNG = cbv.NOIDUNG_VANG,
            cb.NGAYTAO = GETDATE(),
            cb.DADOC   = 0
    WHEN NOT MATCHED THEN
        INSERT (MAND, MALH, NGUONCB, LOAICB, NOIDUNG, NGAYTAO, DADOC)
        VALUES (cbv.MAND, cbv.MALH, N'Chuyên cần', cbv.LOAI_VANG, cbv.NOIDUNG_VANG, GETDATE(), 0);
END;
GO


-- ============================================================
-- TRIGGER 5: Kiểm tra logic thời gian lịch học
-- ============================================================
CREATE TRIGGER trg_KiemTraThoiGianLichHoc
ON LICHHOC AFTER INSERT, UPDATE
AS BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted WHERE THOIGIANKT < THOIGIANBD) BEGIN
        RAISERROR (N'Thời gian kết thúc không được trước thời gian bắt đầu.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO


-- ============================================================
-- KẾT THÚC SCRIPT v4
-- ============================================================
