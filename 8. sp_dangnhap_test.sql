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
-- 2. KỊCH BẢN TEST (BÔI ĐEN TỪNG ĐOẠN ĐỂ CHẠY VÀ CHỤP MÀN HÌNH)
-- ====================================================================

PRINT N'--- TEST 1: ĐĂNG NHẬP SAI MẬT KHẨU ---';
-- Kết quả: Báo lỗi đỏ
EXEC SP_DANGNHAP @TenDangNhap = 'taikhoan_test', @MatKhau = 'matsai123';
GO

PRINT N'--- TEST 2: ĐĂNG NHẬP ĐÚNG MẬT KHẨU ---';
-- Lưu ý: M mở bảng NGUOIDUNG ra, kiếm 1 cái TENND và MATKHAU có thật thay vào 2 chữ bên dưới nhé
EXEC SP_DANGNHAP @TenDangNhap = 'DienTenDangNhapVaoDay', @MatKhau = 'DienMatKhauVaoDay';
GO

PRINT N'--- TEST 3: BẢO MẬT - HỌC SINH CỐ TÌNH CHẤM ĐIỂM SẼ BỊ CHẶN ---';
-- Kết quả: Báo lỗi Permission Denied đỏ chót
EXECUTE AS ROLE = 'HocSinh'; 
GO
BEGIN TRY
    UPDATE BAINOP SET DIEM = 10 WHERE MANOP = 1;
END TRY
BEGIN CATCH
    PRINT N'❌ BỊ CHẶN: Học sinh không có quyền sửa điểm!';
    PRINT ERROR_MESSAGE();
END CATCH;
REVERT; 
GO

PRINT N'--- TEST 4: BẢO MẬT - GIÁO VIÊN ĐĂNG NHẬP VÀ CHẤM ĐIỂM HỢP LỆ ---';
-- Kết quả: Thành công
EXECUTE AS ROLE = 'GiaoVien'; 
GO
BEGIN TRY
    UPDATE BAINOP SET DIEM = 9.5 WHERE MANOP = 1;
    PRINT N'✅ THÀNH CÔNG: Giáo viên đã cập nhật điểm!';
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH;
REVERT; 
GO