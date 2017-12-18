if object_id('dbo.GetEndDate') is not null
begin
   exec ('drop function dbo.GetEndDate')
end
go


create function dbo.GetEndDate (@DatabaseName varchar(128), @SchemaName varchar(128), @TableName varchar(128), @BeginDate datetime)
returns datetime
as
begin
   declare @ret datetime

   -- Customize this for your environment
   set @ret = (select dateadd(mi,-1.0,@BeginDate))

   return @ret
end
go

-- Test the function
select dbo.GetEndDate(db_name()
   ,'sys'
   ,'tables'
   ,'2017-01-01 12:00:00')