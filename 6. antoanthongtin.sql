USE QuanLyHocTap; 
GO

-- A. TẠO CÁC ROLE TRONG HỆ THỐNG
CREATE ROLE QuanTriVien;
CREATE ROLE GiaoVien;
CREATE ROLE HocSinh;
GO

-- B. PHÂN QUYỀN CHO ROLE 'QuanTriVien'
-- Quản trị viên được cấp toàn quyền (CONTROL) thao tác trên Database
GRANT CONTROL ON DATABASE::QuanLyHocTap TO QuanTriVien;
GO

-- C. PHÂN QUYỀN CHO ROLE 'GiaoVien'
-- Quản lý Lớp học, Bài tập, Tài liệu, Bảng điểm, Thông báo, Lịch học, Cảnh báo
GRANT SELECT, INSERT, UPDATE, DELETE ON LOPHOC TO GiaoVien;
GRANT SELECT, INSERT, UPDATE, DELETE ON BAITAP TO GiaoVien;
GRANT SELECT, INSERT, UPDATE, DELETE ON TAILIEU TO GiaoVien;
GRANT SELECT, INSERT, UPDATE, DELETE ON BANGDIEM TO GiaoVien;
GRANT SELECT, INSERT, UPDATE, DELETE ON THONGBAO TO GiaoVien;
GRANT SELECT, INSERT, UPDATE, DELETE ON LICHHOC TO GiaoVien;
GRANT SELECT, INSERT, UPDATE, DELETE ON CANHBAO TO GiaoVien;

-- Giáo viên được xem thông tin User, Môn học, Khoa, Hiện diện
GRANT SELECT ON NGUOIDUNG TO GiaoVien;
GRANT SELECT ON MONHOC TO GiaoVien;
GRANT SELECT ON KHOA TO GiaoVien;
GRANT SELECT ON THAMGIALOP TO GiaoVien;
GRANT SELECT ON HIENDIEN TO GiaoVien;

-- Giáo viên xem và chấm điểm bài nộp (Update cột điểm)
GRANT SELECT, UPDATE(DIEM, NHANXET) ON BAINOP TO GiaoVien;

-- Giáo viên có thể xem đánh giá lớp của mình
GRANT SELECT ON DANHGIA TO GiaoVien;

-- Gửi, nhận tin nhắn
GRANT SELECT, INSERT, UPDATE ON TINNHAN TO GiaoVien;
GO

-- D. PHÂN QUYỀN CHO ROLE 'HocSinh'
-- Học sinh được xem thông tin lớp học, bài tập, tài liệu, thông báo, lịch học
GRANT SELECT ON LOPHOC TO HocSinh;
GRANT SELECT ON BAITAP TO HocSinh;
GRANT SELECT ON TAILIEU TO HocSinh;
GRANT SELECT ON THONGBAO TO HocSinh;
GRANT SELECT ON LICHHOC TO HocSinh;
GRANT SELECT ON CANHBAO TO HocSinh;
GRANT SELECT ON BANGDIEM TO HocSinh;
GRANT SELECT ON MONHOC TO HocSinh;
GRANT SELECT ON KHOA TO HocSinh;
GRANT SELECT ON THAMGIALOP TO HocSinh;

-- Tham gia lớp (Insert)
GRANT INSERT ON THAMGIALOP TO HocSinh;

-- Nộp bài tập
GRANT SELECT, INSERT, UPDATE(DUONGDAN) ON BAINOP TO HocSinh;

-- Điểm danh bản thân
GRANT SELECT, INSERT ON HIENDIEN TO HocSinh;

-- Đánh giá lớp học
GRANT SELECT, INSERT ON DANHGIA TO HocSinh;

-- Gửi, nhận tin nhắn
GRANT SELECT, INSERT, UPDATE ON TINNHAN TO HocSinh;
GO

USE master;
GO

-- 1. Sao lưu Cơ sở dữ liệu (Backup vào ổ C:\Temp)
BACKUP DATABASE QuanLyHocTap 
TO DISK = 'C:\Temp\QuanLyHocTap_Backup.bak' 
WITH FORMAT, 
     MEDIANAME = 'QL_HocTap_Backup', 
     NAME = 'Full Backup Quan Ly Hoc Tap';
GO

-- 2. Phục hồi Cơ sở dữ liệu (Restore)
ALTER DATABASE QuanLyHocTap SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO

RESTORE DATABASE QuanLyHocTap 
FROM DISK = 'C:\Temp\QuanLyHocTap_Backup.bak' 
WITH REPLACE;
GO

ALTER DATABASE QuanLyHocTap SET MULTI_USER;
GO

-- 3. Import Data
USE QuanLyHocTap;
GO

BULK INSERT NGUOIDUNG
FROM 'C:\Temp\DanhSachNguoiDung.csv'
WITH (
    FIELDTERMINATOR = ',',  
    ROWTERMINATOR = '\n',   
    FIRSTROW = 2,           
    CODEPAGE = '65001'      
);
GO