USE QuanLyHocTap;
GO

-- ==========================================
-- 1. FUNCTION: Hàm tính điểm trung bình môn
-- ==========================================
CREATE OR ALTER FUNCTION FN_TinhDiemTrungBinh (@MaThamGia INT)
RETURNS FLOAT
AS
BEGIN
    DECLARE @DiemTB FLOAT;
    
    SELECT @DiemTB = AVG(DIEM) 
    FROM BAINOP 
    WHERE MATHAMGIA = @MaThamGia;
    
    RETURN ISNULL(@DiemTB, 0);
END;
GO

-- ==========================================
-- 2. CURSOR: Cập nhật xếp loại đồng loạt
-- ==========================================
CREATE OR ALTER PROCEDURE SP_CapNhatXepLoaiDongLoat
AS
BEGIN
    DECLARE @MaTG INT;
    DECLARE @Diem FLOAT;
    DECLARE @XepLoai NVARCHAR(50);

    -- Khởi tạo Cursor
    DECLARE Cur_HocVien CURSOR FOR 
    SELECT MATHAMGIA FROM THAMGIALOP;

    OPEN Cur_HocVien;
    FETCH NEXT FROM Cur_HocVien INTO @MaTG;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Gọi Function tính điểm
        SET @Diem = dbo.FN_TinhDiemTrungBinh(@MaTG);

        -- Phân loại
        SET @XepLoai = CASE 
            WHEN @Diem >= 8.0 THEN N'Giỏi'
            WHEN @Diem >= 6.5 THEN N'Khá'
            WHEN @Diem >= 5.0 THEN N'Trung bình'
            ELSE N'Yếu'
        END;

        -- Cập nhật vào bảng BANGDIEM
        IF EXISTS (SELECT 1 FROM BANGDIEM WHERE MATHAMGIA = @MaTG)
            UPDATE BANGDIEM SET DIEM = @Diem, XEPLOAI = @XepLoai, NGAYCAPNHAT = GETDATE() WHERE MATHAMGIA = @MaTG;
        ELSE
            INSERT INTO BANGDIEM (MATHAMGIA, DIEM, XEPLOAI, NGAYCAPNHAT) VALUES (@MaTG, @Diem, @XepLoai, GETDATE());

        FETCH NEXT FROM Cur_HocVien INTO @MaTG;
    END;

    CLOSE Cur_HocVien;
    DEALLOCATE Cur_HocVien;
    
    PRINT N'✅ Đã cập nhật điểm và xếp loại đồng loạt thành công!';
END;
GO

-- ==========================================
-- CHẠY THỬ ĐỂ TEST (CHỤP MÀN HÌNH NẾU CẦN)
-- ==========================================
EXEC SP_CapNhatXepLoaiDongLoat;
GO