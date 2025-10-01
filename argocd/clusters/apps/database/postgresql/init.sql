-- 建立 prefect 資料庫
CREATE DATABASE prefect;

-- 建立 prefect 使用者並設定密碼
CREATE USER prefect WITH PASSWORD 'prefect';

-- 授予 prefect 使用者對 prefect 資料庫的完整權限
GRANT ALL PRIVILEGES ON DATABASE prefect TO prefect;

-- 建立 metabase 資料庫
CREATE DATABASE metabase;

-- 建立 metabase 使用者並設定密碼
CREATE USER metabase WITH PASSWORD 'metabase';

-- 授予 metabase 使用者對 metabase 資料庫的完整權限
GRANT ALL PRIVILEGES ON DATABASE metabase TO metabase;

-- 可選：讓使用者成為資料庫的擁有者
ALTER DATABASE prefect OWNER TO prefect;
ALTER DATABASE metabase OWNER TO metabase;
