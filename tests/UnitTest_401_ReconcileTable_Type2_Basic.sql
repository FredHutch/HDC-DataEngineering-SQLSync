exec UnitTest_PopulateDDL
go

/*
Test methodology:

Diff the table over.
Make sure the rowcounts are the same
Copy all rows to the reconcile table, then delete some (hard delete)
Run ReconcileTable()
Confirm that the deleted rows are marked as inactive in the source
*/


/*
select *
from dbo.SyncConfig
where TargetTable = 'UnitTest_TargetTable2'
go
*/

declare @DatabaseName varchar(128)
set @DatabaseName = (select db_name())

truncate table dbo.UnitTest_TargetTable2


-- First, load the table
exec dbo.DiffTable @TargetDatabaseName=@DatabaseName, @TargetTableName='UnitTest_TargetTable2', @Debug=0
go

-- Create reconcile table and copy it over
if OBJECT_ID('dbo.UnitTest_ReconcileTable1') is not null
BEGIN
  exec ('drop table dbo.UnitTest_ReconcileTable1')
end
go

create table dbo.UnitTest_ReconcileTable1
(PKColumn varchar(400) not null primary key clustered)
go

insert into dbo.UnitTest_ReconcileTable1 (PKColumn)
select PKColumn
from UnitTest_SourceTable1
where TRY_CONVERT(int, PKColumn) % 20 != 13 --removes ~5% of the rows
go


declare @DatabaseName varchar(128)
set @DatabaseName = (select db_name())

update dbo.SyncConfig
set ReconcileTable = 'UnitTest_ReconcileTable1'
where TargetTable = 'UnitTest_TargetTable2'


exec dbo.ReconcileTable @TargetDatabaseName=@DatabaseName, @TargetTableName='UnitTest_TargetTable2', @Debug=0
go

/*
select *
from dbo.SyncConfig
where TargetTable = 'UnitTest_TargetTable2'
*/

-- Confirm that the deleted rows are marked as inactive in the target
; with t as
(
   select 'TargetTable' as TableDesc 
    ,'TotalRowcount' = count(*)
    ,'ReconcileRowcount' = sum(case when UnitTestEndDate='9999-12-31' then 1 else 0 end)
   from dbo.UnitTest_TargetTable2
), s as
(
   select 'SourceTable' as TableDesc 
    ,'TotalRowcount' = count(*)
    ,'ReconcileRowcount' = sum(case when r.PKColumn is not null then 1 else 0 end)
   from dbo.UnitTest_SourceTable1 s
   left outer join dbo.UnitTest_ReconcileTable1 r
   on r.PKColumn = s.PKColumn
)


select
    case when isnull(s.ReconcileRowcount,-1) = isnull(t.ReconcileRowcount,-1) then 'Success' else 'Failure' end as Status
  ,'Make sure the source and target reconcile rowcounts match' as TestDescription
  ,SourceReconcileCount = s.ReconcileRowcount
  ,SourceReconcileCount = t.ReconcileRowcount
  ,SourceRowcount = s.TotalRowcount
  ,TargetRowcount = t.TotalRowcount
from t
cross join s

