exec UnitTest_PopulateDDL
go


/*
select *
from dbo.SyncConfig
where TargetTable = 'UnitTest_TargetTable2'
go
*/

update UnitTest_SourceTable1
set NvarcharColumn = N'TestData='+cast(IntColumn as varchar) + cast(IntColumn as varchar)
go

truncate table dbo.UnitTest_TargetTable2
go


declare @DatabaseName varchar(128)
set @DatabaseName = (select db_name())


-- First, load the table
exec dbo.DiffTable @TargetDatabaseName=@DatabaseName, @TargetTableName='UnitTest_TargetTable2', @Debug=0
go

-- then wait, pretend it's a delay
waitfor delay '00:01:01'
go

-- update the source and run the diff again
update UnitTest_SourceTable1
set NvarcharColumn = replace(NvarcharColumn,'TestData','UpdatedTestData')
go

declare @DatabaseName varchar(128)
set @DatabaseName = (select db_name())

exec dbo.DiffTable @TargetDatabaseName=@DatabaseName, @TargetTableName='UnitTest_TargetTable2', @Debug=0
go

/*
select *
from dbo.SyncConfig
where TargetTable = 'UnitTest_TargetTable2'

select TotalRowcount = count(*)
    ,OriginalData = sum(case when NvarcharColumn like 'TestData%' then 1 else 0 end)
    ,EndedOriginalData = sum(case when NvarcharColumn like 'TestData%' and UnitTestEndDate < '9999-12-31' then 1 else 0 end)
    ,UpdatedData = sum(case when NvarcharColumn like 'UpdatedTestData%' then 1 else 0 end)
    ,ActiveUpdatedData = sum(case when NvarcharColumn like 'UpdatedTestData%' and UnitTestEndDate = '9999-12-31' then 1 else 0 end)
from dbo.UnitTest_TargetTable2
*/

select
    case when count(*)=1500 then 'Success' else 'Failure' END as [Status]
    ,'Make sure the total rowcount is 1500' as TestDescription
from dbo.UnitTest_TargetTable2

union all

select
    case when sum(case when NvarcharColumn like 'TestData%' then 1 else 0 end)=1000 then 'Success' else 'Failure' END
    ,'Make sure the rowcount for original data is 1000' as TestDescription
from dbo.UnitTest_TargetTable2

union all

select
    case when sum(case when NvarcharColumn like 'UpdatedTestData%' then 1 else 0 end)=500 then 'Success' else 'Failure' END
    ,'Make sure the rowcount for updated data is 500' as TestDescription
from dbo.UnitTest_TargetTable2

union all

select
    case when sum(case when NvarcharColumn like 'TestData%' and UnitTestEndDate < '9999-12-31' then 1 else 0 end)=500 then 'Success' else 'Failure' END
    ,'Make sure the rowcount for ended original data is 500' as TestDescription
from dbo.UnitTest_TargetTable2

union all

select
    case when sum(case when NvarcharColumn like 'UpdatedTestData%' and UnitTestEndDate = '9999-12-31' then 1 else 0 end)=500 then 'Success' else 'Failure' END
    ,'Make sure the rowcount for active updated data is 500' as TestDescription
from dbo.UnitTest_TargetTable2


/*
select top 1000 *
from UnitTest_TargetTable2
order by PKColumn asc, UnitTestBeginDate asc

*/



