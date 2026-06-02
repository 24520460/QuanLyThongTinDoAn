USE QuanLyHocTap;
GO

-- ====================================================================
-- 1. TẠO STORED PROCEDURE ĐĂNG NHẬP
-- ====================================================================
CREATE OR ALTER PROCEDURE SP_DANGNHAP
    @TenDangNhap NVARCHAR(100),
    @MatKhau NVARCHAR(255)
AS
BEGIN
    IF EXISTS (SELECT 1 FROM NGUOIDUNG WHERE TENND = @TenDangNhap AND MATKHAU = @MatKhau)
    BEGIN
        DECLARE @TenHT NVARCHAR(100), @VaiTro NVARCHAR(50);
        
        SELECT @TenHT = TENHT, @VaiTro = vt.TENVT 
        FROM NGUOIDUNG nd JOIN VAITRO vt ON nd.MAVT = vt.MAVT
        WHERE TENND = @TenDangNhap AND MATKHAU = @MatKhau;

        PRINT N'✅ ĐĂNG NHẬP THÀNH CÔNG!';
        PRINT N'Chào mừng [' + @TenHT + N'] - Vai trò: ' + @VaiTro;
    END
    ELSE
    BEGIN
        RAISERROR (N'❌ ĐĂNG NHẬP THẤT BẠI: Sai tên đăng nhập hoặc mật khẩu!', 16, 1);
    END
END
GO

-- ====================================================================
-- 2. TẠO USER ẢO VÀ CẤP QUYỀN (CHẠY NHIỀU LẦN KHÔNG LỖI)
-- ====================================================================
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'vunguyen')
    CREATE USER [vunguyen] WITHOUT LOGIN;

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'loc.le')
    CREATE USER [loc.le] WITHOUT LOGIN;
GO

ALTER ROLE GiaoVien ADD MEMBER [vunguyen];
ALTER ROLE HocSinh ADD MEMBER [loc.le];
GO

-- ====================================================================
-- 3. KỊCH BẢN TEST 
-- ====================================================================
PRINT N'==============================================================';
PRINT N' KỊCH BẢN 1: GIÁO VIÊN ĐĂNG NHẬP VÀ CHẤM ĐIỂM (THÀNH CÔNG)';
PRINT N'==============================================================';

-- ⚠️ Nhớ thay đúng mật khẩu của vunguyen vào đây
EXEC SP_DANGNHAP @TenDangNhap = 'vunguyen', @MatKhau = '$2b$10$xyzFakeHashForEveryone...'; 
GO

EXECUTE AS USER = 'vunguyen'; 
GO
BEGIN TRY
    -- Dọn rác cảnh báo cũ để Trigger không báo lỗi UNIQUE KEY
    DELETE FROM CANHBAO WHERE NGUONCB = N'Điểm';

    UPDATE BAINOP SET DIEM = 9.5 WHERE MANOP = 1;
    PRINT N'✅ HOÀN TẤT: Giáo viên đã chấm điểm hợp lệ!';
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH;
GO

REVERT; 
GO

PRINT N'';

PRINT N'==============================================================';
PRINT N' KỊCH BẢN 2: HỌC SINH ĐĂNG NHẬP VÀ CỐ TÌNH SỬA ĐIỂM (BỊ CHẶN)';
PRINT N'==============================================================';

-- ⚠️ Nhớ thay đúng mật khẩu của loc.le vào đây
EXEC SP_DANGNHAP @TenDangNhap = 'loc.le', @MatKhau = '$2b$10$xyzFakeHashForEveryone...'; 
GO

EXECUTE AS USER = 'loc.le'; 
GO
BEGIN TRY
    UPDATE BAINOP SET DIEM = 10 WHERE MANOP = 1;
    PRINT N'✅ HOÀN TẤT!'; 
END TRY
BEGIN CATCH
    PRINT N'❌ HỆ THỐNG ĐÃ TỪ CHỐI THAO TÁC:';
    PRINT ERROR_MESSAGE(); 
END CATCH;
GO

REVERT; 
GO