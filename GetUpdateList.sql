if object_id('dbo.GetUpdateList') is not null
begin
   exec ('drop function dbo.GetUpdateList')
end
go


create function dbo.GetUpdateList (@DatabaseName varchar(128), @SchemaName varchar(128), @TableName varchar(128), @Alias varchar(6))
returns varchar(max)
as
begin
   declare @ret varchar(max)

   set @ret = 
      (
      select
           ',['+g.COLUMN_NAME+'] = '+@Alias+'.['+g.COLUMN_NAME+']' 
       from dbo.GlobalInformationSchema g
       where TABLE_CATALOG = @DatabaseName
       and TABLE_SCHEMA = @SchemaName
       and TABLE_NAME = @TableName
       ORDER BY g.ORDINAL_POSITION
       for xml path('')
      )

   set @ret = substring(@ret,2,len(@ret)-1)
   return @ret
end
go

-- Test the function
select dbo.GetUpdateList(db_name()
   ,'sys'
   ,'tables'
   ,'s')