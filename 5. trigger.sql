USE QuanLyHocTap
GO

-- 1. Kiem tra vai tro la giao vien

CREATE TRIGGER TRG_CHECK_TEACHER_LOPHOC
ON LOPHOC
FOR INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN NGUOIDUNG nd ON i.MAND = nd.MAND
        JOIN VAITRO vt ON nd.MAVT = vt.MAVT
        WHERE vt.TENVT <> N'Giáo viên'
    )
    BEGIN
        RAISERROR (N'Chỉ giáo viên mới được tạo hoặc sửa lớp học', 16, 1)
        ROLLBACK TRANSACTION
    END
END
GO

CREATE TRIGGER TRG_CHECK_TEACHER_BAITAP
ON BAITAP
FOR INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN NGUOIDUNG nd ON i.MAND = nd.MAND
        JOIN VAITRO vt ON nd.MAVT = vt.MAVT
        WHERE vt.TENVT <> N'Giáo viên'
    )
    BEGIN
        RAISERROR (N'Chỉ giáo viên mới được tạo bài tập', 16, 1)
        ROLLBACK TRANSACTION
    END
END
GO

CREATE TRIGGER TRG_CHECK_TEACHER_TAILIEU
ON TAILIEU
FOR INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN NGUOIDUNG nd ON i.MAND = nd.MAND
        JOIN VAITRO vt ON nd.MAVT = vt.MAVT
        WHERE vt.TENVT <> N'Giáo viên'
    )
    BEGIN
        RAISERROR (N'Chỉ giáo viên mới được tạo tài liệu', 16, 1)
        ROLLBACK TRANSACTION
    END
END
GO

-- 2. Kiem tra so luong toi da cua lop

CREATE TRIGGER TRG_CHECK_SOSV
ON THAMGIALOP
FOR INSERT
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN LOPHOC lh ON i.MALH = lh.MALH
        WHERE (
            SELECT COUNT(*) 
            FROM THAMGIALOP t
            WHERE t.MALH = i.MALH
        ) > lh.SOSVTOIDA
    )
    BEGIN
        RAISERROR (N'Lớp đã đủ số lượng học viên', 16, 1)
        ROLLBACK TRANSACTION
    END
END
GO

--3 Tu dong canh bao diem so

GO
CREATE TRIGGER TRG_CANHBAO_DIEM
ON BAINOP
FOR INSERT, UPDATE
AS
BEGIN
    INSERT INTO CANHBAO (MAND, MALH, LOAICB, NOIDUNG, NGAYTAO, DADOC)
    SELECT 
        tg.MAND,
        bt.MALH,
        CASE 
            WHEN i.DIEM >= 5 THEN N'Đạt'
            WHEN i.DIEM >= 3 THEN N'Nguy cơ'
            ELSE N'Nguy cơ cao'
        END,
        N'Cảnh báo học tập tự động',
        GETDATE(),
        0
    FROM inserted i
    JOIN THAMGIALOP tg ON i.MATHAMGIA = tg.MATHAMGIA
    JOIN BAITAP bt ON i.MABT = bt.MABT
END
GO

--4 Kiem tra duy nhat

CREATE TRIGGER TRG_UNIQUE_THAMGIA
ON THAMGIALOP
FOR INSERT
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM THAMGIALOP t
        JOIN inserted i 
        ON t.MAND = i.MAND AND t.MALH = i.MALH
        GROUP BY t.MAND, t.MALH
        HAVING COUNT(*) > 1
    )
    BEGIN
        RAISERROR (N'Học sinh đã đăng ký lớp này rồi', 16, 1)
        ROLLBACK TRANSACTION
    END
END
GO

CREATE TRIGGER TRG_UNIQUE_DANHGIA
ON DANHGIA
FOR INSERT
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM DANHGIA d
        JOIN inserted i ON d.MATHAMGIA = i.MATHAMGIA
        GROUP BY d.MATHAMGIA
        HAVING COUNT(*) > 1
    )
    BEGIN
        RAISERROR (N'Chỉ được đánh giá 1 lần', 16, 1)
        ROLLBACK TRANSACTION
    END
END
GO

--5. Kiem tra logic thoi gian

CREATE TRIGGER TRG_CHECK_DATE
ON LOPHOC
FOR INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1 FROM inserted
        WHERE NGAYKETTHUC < NGAYBATDAU
    )
    BEGIN
        RAISERROR (N'Ngày kết thúc phải >= ngày bắt đầu', 16, 1)
        ROLLBACK TRANSACTION
    END
END
GO

CREATE TRIGGER TRG_CHECK_HANNOP
ON BAITAP
FOR INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1 FROM inserted
        WHERE HANNOP < NGAYTAO
    )
    BEGIN
        RAISERROR (N'Hạn nộp phải >= ngày tạo', 16, 1)
        ROLLBACK TRANSACTION
    END
END
GO

GO
CREATE TRIGGER TRG_CHECK_LICHHOC
ON LICHHOC
FOR INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1 FROM inserted
        WHERE THOIGIANKT < THOIGIANBD
    )
    BEGIN
        RAISERROR (N'Thời gian kết thúc phải >= thời gian bắt đầu', 16, 1)
        ROLLBACK TRANSACTION
    END
END
GO

