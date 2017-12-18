if object_id('dbo.GetBeginDate') is not null
begin
   exec ('drop function dbo.GetBeginDate')
end
go


create function dbo.GetBeginDate (@DatabaseName varchar(128), @SchemaName varchar(128), @TableName varchar(128))
returns datetime
as
begin
   declare @ret datetime

   -- Customize this for your environment
   set @ret = (select convert(datetime,convert(varchar(30),getdate(),120)))

   return @ret
end
go

-- Test the function
select dbo.GetBeginDate(db_name()
   ,'sys'
   ,'tables')