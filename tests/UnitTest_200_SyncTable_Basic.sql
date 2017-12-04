exec UnitTest_PopulateDDL
go


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

-- then wait, pretend it's a delay
waitfor delay '00:02:00'

-- update the source and run the diff again
update UnitTest_SourceTable1
set NvarcharColumn = replace(NvarcharColumn,'TestData','UpdatedTestData')
go

exec dbo.DiffTable @TargetDatabaseName=@DatabaseName, @TargetTableName='UnitTest_TargetTable2', @Debug=0


/*
select *
from dbo.SyncConfig
where TargetTable = 'UnitTest_TargetTable2'
*/

select TotalRowcount = count(*)
    ,OriginalData = sum(case when NvarcharColumn like 'TestData%' then 1 else 0 end)
    ,EndedOriginalData = sum(case when NvarcharColumn like 'TestData%' and UnitTestEndDate < '9999-12-31' then 1 else 0 end)
    ,UpdatedData = sum(case when NvarcharColumn like 'UpdatedTestData%' then 1 else 0 end)
    ,ActiveUpdatedData = sum(case when NvarcharColumn like 'UpdatedTestData%' and UnitTestEndDate = '9999-12-31' then 1 else 0 end)
from dbo.UnitTest_TargetTable2
