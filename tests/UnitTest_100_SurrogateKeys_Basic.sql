exec dbo.UnitTest_PopulateDDL
go

if object_id('dbo.UnitTest_SurrogateKeys_TargetTable1') is not null
begin
   exec ('drop table dbo.UnitTest_SurrogateKeys_TargetTable1')
end
go

create table dbo.UnitTest_SurrogateKeys_TargetTable1
(UnitTestSurrogateKeyID bigint not null
,PKColumn varchar(400) not null
,constraint PKUnitTest_SurrogateKeys_TargetTable1 primary key clustered (PKColumn)
)
go


UPDATE dbo.SyncConfig
SET SurrogateTable = 'UnitTest_SurrogateKeys_TargetTable1'
,SurrogateKeyColumn = 'UnitTestSurrogateKeyID'
WHERE TargetTable = 'UnitTest_TargetTable1'
go


select *
from dbo.SyncConfig
where TargetTable = 'UnitTest_TargetTable1'
go

exec dbo.UpdateSurrogateKeys
    @TargetDatabaseName='Scratch'
   ,@TargetTableName='UnitTest_TargetTable1'
   ,@Debug=1


select *
from dbo.UnitTest_SurrogateKeys_TargetTable1

-- add more rows, do it again
; WITH Nbrs_3( n ) AS ( SELECT 1 UNION SELECT 0 ),
Nbrs_2( n ) AS ( SELECT 1 FROM Nbrs_3 n1 CROSS JOIN Nbrs_3 n2 ),
Nbrs_1( n ) AS ( SELECT 1 FROM Nbrs_2 n1 CROSS JOIN Nbrs_2 n2 ),
Nbrs_0( n ) AS ( SELECT 1 FROM Nbrs_1 n1 CROSS JOIN Nbrs_1 n2 ),
Nbrs ( n ) AS ( SELECT 1 FROM Nbrs_0 n1 CROSS JOIN Nbrs_0 n2 )

insert into dbo.UnitTest_SourceTable1
(PKColumn
,IntColumn
,GuidColumn
,NvarcharColumn
,DateColumn
,UnitTestStagingTime)
SELECT 
   PKColumn = cast(n as varchar) + cast(n as varchar)
  ,n as IntColumn
  ,newid() as GuidColumn
  ,NvarcharColumn = N'TestData='+cast(n as varchar) + cast(n as varchar)
  ,DateColumn = dateadd(ss,-1.0*n,getdate())
  ,UnitTestStagingTime = getdate()
FROM ( SELECT ROW_NUMBER() OVER (ORDER BY n)
FROM Nbrs ) D ( n )
WHERE n between 501 and 1000 ; 



exec dbo.UpdateSurrogateKeys
    @TargetDatabaseName='Scratch'
   ,@TargetTableName='UnitTest_TargetTable1'
   ,@Debug=0


select *
from dbo.UnitTest_SurrogateKeys_TargetTable1
