-- =============================================
-- SQL Server Vector Search Deployment Script
-- =============================================

USE master;
GO

-- Enable CLR integration (requires sysadmin)
sp_configure 'clr enabled', 1;
RECONFIGURE;
GO

-- Enable CLR strict security (SQL Server 2017+)
-- For development, you may need to disable this or sign assemblies
-- sp_configure 'clr strict security', 0;
-- RECONFIGURE;
-- GO

-- Create database (or use existing)
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'VectorSearchDB')
BEGIN
    CREATE DATABASE VectorSearchDB;
END
GO

USE VectorSearchDB;
GO

-- =============================================
-- Drop existing objects (for clean reinstall)
-- =============================================

-- Drop functions
IF OBJECT_ID('dbo.VectorDistance', 'FS') IS NOT NULL
    DROP FUNCTION dbo.VectorDistance;
GO

IF OBJECT_ID('dbo.L2Distance', 'FS') IS NOT NULL
    DROP FUNCTION dbo.L2Distance;
GO

IF OBJECT_ID('dbo.CosineSimilarity', 'FS') IS NOT NULL
    DROP FUNCTION dbo.CosineSimilarity;
GO

IF OBJECT_ID('dbo.CosineDistance', 'FS') IS NOT NULL
    DROP FUNCTION dbo.CosineDistance;
GO

IF OBJECT_ID('dbo.InnerProduct', 'FS') IS NOT NULL
    DROP FUNCTION dbo.InnerProduct;
GO

-- Drop procedures
IF OBJECT_ID('dbo.sp_create_vector_index', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_create_vector_index;
GO

-- Drop types
IF EXISTS (SELECT * FROM sys.types WHERE name = 'VectorType' AND is_user_defined = 1)
    DROP TYPE dbo.VectorType;
GO

-- Drop assembly
IF EXISTS (SELECT * FROM sys.assemblies WHERE name = 'SqlServerVectorSearch')
    DROP ASSEMBLY SqlServerVectorSearch;
GO

-- =============================================
-- Create Assembly
-- =============================================
-- NOTE: Update the path to your DLL location
-- For UNSAFE permission level, you may need to:
-- 1. Sign the assembly with a strong name key
-- 2. Create an asymmetric key from the assembly
-- 3. Create a login from the asymmetric key
-- 4. Grant UNSAFE ASSEMBLY permission to the login

DECLARE @AssemblyPath NVARCHAR(500) = 'C:\Path\To\SqlServer.VectorSearch.dll';

-- For development/testing (requires CLR strict security = 0)
DECLARE @SQL NVARCHAR(MAX) = N'
CREATE ASSEMBLY SqlServerVectorSearch
FROM ''' + @AssemblyPath + '''
WITH PERMISSION_SET = UNSAFE;
';

-- Uncomment to execute
-- EXEC sp_executesql @SQL;
-- GO

-- For production (requires signed assembly)
/*
-- Create asymmetric key from signed DLL
CREATE ASYMMETRIC KEY VectorSearchKey
FROM FILE = 'C:\Path\To\SqlServer.VectorSearch.dll';
GO

-- Create login from key
CREATE LOGIN VectorSearchLogin
FROM ASYMMETRIC KEY VectorSearchKey;
GO

-- Grant UNSAFE permission
GRANT UNSAFE ASSEMBLY TO VectorSearchLogin;
GO

-- Create assembly
CREATE ASSEMBLY SqlServerVectorSearch
FROM 'C:\Path\To\SqlServer.VectorSearch.dll'
WITH PERMISSION_SET = UNSAFE;
GO
*/

-- =============================================
-- Create User-Defined Type
-- =============================================

-- Placeholder - will be created after assembly is loaded
/*
CREATE TYPE dbo.VectorType
EXTERNAL NAME SqlServerVectorSearch.[SqlServer.VectorSearch.Types.VectorType];
GO
*/

-- =============================================
-- Create Functions
-- =============================================

/*
CREATE FUNCTION dbo.L2Distance(@v1 VectorType, @v2 VectorType)
RETURNS FLOAT
AS EXTERNAL NAME SqlServerVectorSearch.[SqlServer.VectorSearch.Functions.DistanceFunctions].L2Distance;
GO

CREATE FUNCTION dbo.CosineSimilarity(@v1 VectorType, @v2 VectorType)
RETURNS FLOAT
AS EXTERNAL NAME SqlServerVectorSearch.[SqlServer.VectorSearch.Functions.DistanceFunctions].CosineSimilarity;
GO

CREATE FUNCTION dbo.CosineDistance(@v1 VectorType, @v2 VectorType)
RETURNS FLOAT
AS EXTERNAL NAME SqlServerVectorSearch.[SqlServer.VectorSearch.Functions.DistanceFunctions].CosineDistance;
GO

CREATE FUNCTION dbo.InnerProduct(@v1 VectorType, @v2 VectorType)
RETURNS FLOAT
AS EXTERNAL NAME SqlServerVectorSearch.[SqlServer.VectorSearch.Functions.DistanceFunctions].InnerProduct;
GO

CREATE FUNCTION dbo.VectorDistance(@v1 VectorType, @v2 VectorType, @metric NVARCHAR(50))
RETURNS FLOAT
AS EXTERNAL NAME SqlServerVectorSearch.[SqlServer.VectorSearch.Functions.DistanceFunctions].VectorDistance;
GO
*/

-- =============================================
-- Create Metadata Tables
-- =============================================

IF OBJECT_ID('dbo.sys_vector_indexes', 'U') IS NOT NULL
    DROP TABLE dbo.sys_vector_indexes;
GO

CREATE TABLE dbo.sys_vector_indexes (
    index_id INT IDENTITY(1,1) PRIMARY KEY,
    table_schema NVARCHAR(128) NOT NULL,
    table_name NVARCHAR(128) NOT NULL,
    column_name NVARCHAR(128) NOT NULL,
    index_type NVARCHAR(50) NOT NULL, -- FLAT, HNSW, IVF, etc.
    metric_type NVARCHAR(50) NOT NULL, -- L2, COSINE, IP
    dimension INT NOT NULL,
    ntotal BIGINT DEFAULT 0,
    index_path NVARCHAR(512) NOT NULL,
    index_options NVARCHAR(MAX), -- JSON with index-specific params
    created_date DATETIME2 DEFAULT GETDATE(),
    last_rebuilt DATETIME2 DEFAULT GETDATE(),
    is_active BIT DEFAULT 1,
    CONSTRAINT UK_VectorIndex UNIQUE (table_schema, table_name, column_name)
);
GO

-- Index for lookups
CREATE INDEX IX_VectorIndexes_Table 
ON dbo.sys_vector_indexes(table_schema, table_name);
GO

-- =============================================
-- Deployment Instructions
-- =============================================

PRINT '========================================';
PRINT 'SQL Server Vector Search Deployment';
PRINT '========================================';
PRINT '';
PRINT 'MANUAL STEPS REQUIRED:';
PRINT '1. Update @AssemblyPath in this script to point to SqlServer.VectorSearch.dll';
PRINT '2. Ensure native library (SqlServer.VectorSearch.Native.dll) is in the same directory';
PRINT '3. Uncomment and execute the CREATE ASSEMBLY section';
PRINT '4. Uncomment and execute the CREATE TYPE and CREATE FUNCTION sections';
PRINT '5. Grant necessary permissions to users who will use vector search';
PRINT '';
PRINT 'SECURITY OPTIONS:';
PRINT '  Development: Disable CLR strict security and use PERMISSION_SET = UNSAFE';
PRINT '  Production: Sign assembly and create login from asymmetric key';
PRINT '';
PRINT 'CONFIGURATION:';
PRINT '  - CLR enabled: ' + CONVERT(VARCHAR, (SELECT value FROM sys.configurations WHERE name = 'clr enabled'));
PRINT '  - CLR strict security: ' + CONVERT(VARCHAR, (SELECT value FROM sys.configurations WHERE name = 'clr strict security'));
PRINT '';
GO
