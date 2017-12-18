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



; with t as
(
   select 'TargetTable' as TableDesc 
    ,'TotalRowcount' = count(*)
   from dbo.UnitTest_TargetTable1
), s as
(
   select 'SourceTable' as TableDesc 
    ,'TotalRowcount' = count(*)
   from dbo.UnitTest_SourceTable1
)


select
    case when isnull(s.TotalRowcount,-1) = isnull(t.TotalRowcount,-1) then 'Success' else 'Failure' end as Status
  ,'Make sure the source and target rowcounts match' as TestDescription
  ,s.TotalRowcount as SourceRowcount
  ,t.TotalRowcount as TargetRowcount
from t
cross join s

/*
select top 100 *
from dbo.HistoryLog
order by HistoryLogID desc
*/