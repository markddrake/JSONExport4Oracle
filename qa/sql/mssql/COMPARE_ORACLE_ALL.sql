--
:setvar SCHEMA "HR"
DECLARE @COMMENT NVARCHAR(128) ='$(METHOD)'
DECLARE @DATETIME_PRECISION INT = $(DATETIME_PRECISION)
DECLARE @SPATIAL_PRECISION INT = $(SPATIAL_PRECISION)
DECLARE @SOURCE_DATABASE NVARCHAR(128) = '$(SCHEMA)$(ID1)'
DECLARE @TARGET_DATABASE NVARCHAR(128) = '$(SCHEMA)$(ID2)'
use  $(SCHEMA)$(ID1)
exec sp_COMPARE_SCHEMA TRUE, @SOURCE_DATABASE, 'dbo', @TARGET_DATABASE, 'dbo', @COMMENT, TRUE, @SPATIAL_PRECISION, @DATETIME_PRECISION
go
--
--
:setvar SCHEMA "SH"
DECLARE @COMMENT NVARCHAR(128) ='$(METHOD)'
DECLARE @DATETIME_PRECISION INT = $(DATETIME_PRECISION)
DECLARE @SPATIAL_PRECISION INT = $(SPATIAL_PRECISION)
DECLARE @SOURCE_DATABASE NVARCHAR(128) = '$(SCHEMA)$(ID1)'
DECLARE @TARGET_DATABASE NVARCHAR(128) = '$(SCHEMA)$(ID2)'
use  $(SCHEMA)$(ID1)
exec sp_COMPARE_SCHEMA TRUE, @SOURCE_DATABASE, 'dbo', @TARGET_DATABASE, 'dbo', @COMMENT, TRUE, @SPATIAL_PRECISION, @DATETIME_PRECISION
go
--
--
:setvar SCHEMA "OE"
DECLARE @COMMENT NVARCHAR(128) ='$(METHOD)'
DECLARE @DATETIME_PRECISION INT = $(DATETIME_PRECISION)
DECLARE @SPATIAL_PRECISION INT = $(SPATIAL_PRECISION)
DECLARE @SOURCE_DATABASE NVARCHAR(128) = '$(SCHEMA)$(ID1)'
DECLARE @TARGET_DATABASE NVARCHAR(128) = '$(SCHEMA)$(ID2)'
use  $(SCHEMA)$(ID1)
exec sp_COMPARE_SCHEMA TRUE, @SOURCE_DATABASE, 'dbo', @TARGET_DATABASE, 'dbo', @COMMENT, TRUE, @SPATIAL_PRECISION, @DATETIME_PRECISION
go
--
--
:setvar SCHEMA "PM"
DECLARE @COMMENT NVARCHAR(128) ='$(METHOD)'
DECLARE @DATETIME_PRECISION INT = $(DATETIME_PRECISION)
DECLARE @SPATIAL_PRECISION INT = $(SPATIAL_PRECISION)
DECLARE @SOURCE_DATABASE NVARCHAR(128) = '$(SCHEMA)$(ID1)'
DECLARE @TARGET_DATABASE NVARCHAR(128) = '$(SCHEMA)$(ID2)'
use  $(SCHEMA)$(ID1)
exec sp_COMPARE_SCHEMA TRUE, @SOURCE_DATABASE, 'dbo', @TARGET_DATABASE, 'dbo', @COMMENT, TRUE, @SPATIAL_PRECISION, @DATETIME_PRECISION
go
--
:setvar SCHEMA "IX"
DECLARE @COMMENT NVARCHAR(128) ='$(METHOD)'
DECLARE @DATETIME_PRECISION INT = $(DATETIME_PRECISION)
DECLARE @SPATIAL_PRECISION INT = $(SPATIAL_PRECISION)
DECLARE @SOURCE_DATABASE NVARCHAR(128) = '$(SCHEMA)$(ID1)'
DECLARE @TARGET_DATABASE NVARCHAR(128) = '$(SCHEMA)$(ID2)'
use  $(SCHEMA)$(ID1)
exec sp_COMPARE_SCHEMA TRUE, @SOURCE_DATABASE, 'dbo', @TARGET_DATABASE, 'dbo', @COMMENT, TRUE, @SPATIAL_PRECISION, @DATETIME_PRECISION
go
--
:setvar SCHEMA "BI"
DECLARE @COMMENT NVARCHAR(128) ='$(METHOD)'
DECLARE @DATETIME_PRECISION INT = $(DATETIME_PRECISION)
DECLARE @SPATIAL_PRECISION INT = $(SPATIAL_PRECISION)
DECLARE @SOURCE_DATABASE NVARCHAR(128) = '$(SCHEMA)$(ID1)'
DECLARE @TARGET_DATABASE NVARCHAR(128) = '$(SCHEMA)$(ID2)'
use  $(SCHEMA)$(ID1)
exec sp_COMPARE_SCHEMA TRUE, @SOURCE_DATABASE, 'dbo', @TARGET_DATABASE, 'dbo', @COMMENT, TRUE, @SPATIAL_PRECISION, @DATETIME_PRECISION
go
--
quit
