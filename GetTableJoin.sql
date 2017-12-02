if object_id('dbo.GetTableJoin') is not null
begin
   exec ('drop function dbo.GetTableJoin')
end
go

create function dbo.GetTableJoin (@DatabaseName varchar(128), @SchemaName varchar(128), @TableName varchar(128), @FirstAlias varchar(6), @SecondAlias varchar(6))
returns varchar(max)
as
begin
   declare @ret varchar(max)

   set @ret = 
      (
      select
           ' and '+case when @FirstAlias is null or len(@FirstAlias) < 1 then ''
                                      else @FirstAlias+'.' end
                                      +'['+g.COLUMN_NAME+'] = '+@SecondAlias+'.['+g.COLUMN_NAME+']' 
       from dbo.GlobalInformationSchema g
       where TABLE_CATALOG = @DatabaseName
       and TABLE_SCHEMA = @SchemaName
       and TABLE_NAME = @TableName
       ORDER BY g.ORDINAL_POSITION
       for xml path('')
      )

   set @ret = substring(@ret,6,len(@ret)-4)
   return @ret
end
go


-- Test the function
select dbo.GetTableJoin(db_name()
   ,'sys'
   ,'tables'
    ,'s'
    ,'t')


select dbo.GetTableJoin(db_name()
   ,'sys'
   ,'tables'
    ,''
    ,'t')
go