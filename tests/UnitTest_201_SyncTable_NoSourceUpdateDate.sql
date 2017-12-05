exec UnitTest_PopulateDDL
go


/*
select *
from dbo.SyncConfig
where TargetTable = 'UnitTest_TargetTable1'
go
*/

declare @DatabaseName varchar(128)
set @DatabaseName = (select db_name())

truncate table dbo.UnitTest_TargetTable1


update dbo.SyncConfig
set SourceUpdateDateColumn = null
where TargetTable = 'UnitTest_TargetTable1'

-- First, load the table
exec dbo.SyncTable @TargetDatabaseName=@DatabaseName, @TargetTableName='UnitTest_TargetTable1', @Debug=0

/*
select *
from dbo.SyncConfig
where TargetTable = 'UnitTest_TargetTable1'
*/

select 'TargetTable' as TableDesc 
    ,'TotalRowcount' = count(*)
from dbo.UnitTest_TargetTable1
union ALL
select 'SourceTable' as TableDesc 
    ,'TotalRowcount' = count(*)
from dbo.UnitTest_SourceTable1

select top 100 *
from dbo.HistoryLog
order by HistoryLogID desc