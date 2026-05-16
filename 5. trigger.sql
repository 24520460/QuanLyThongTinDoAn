USE QuanLyHocTap;
GO

CREATE TRIGGER TRG_CHECK_TEACHER_THONGBAO
ON THONGBAO
FOR INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted i
        LEFT JOIN NGUOIDUNG nd ON i.MAND = nd.MAND
        LEFT JOIN VAITRO vt ON nd.MAVT = vt.MAVT
        WHERE i.MAND IS NULL OR vt.TENVT <> N'Giáo viên'
    )
    BEGIN
        RAISERROR (N'Chỉ giáo viên mới được tạo thông báo', 16, 1);
        ROLLBACK TRANSACTION;
    END
END
GO

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
        RAISERROR (N'Lớp đã đủ số lượng học viên', 16, 1);
        ROLLBACK TRANSACTION;
    END
END
GO

