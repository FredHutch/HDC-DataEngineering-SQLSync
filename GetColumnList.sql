if object_id('dbo.GetColumnList') is not null
begin
   exec ('drop function dbo.GetColumnList')
end
go


create function dbo.GetColumnList (@DatabaseName varchar(128), @SchemaName varchar(128), @TableName varchar(128), @ColumnsToIgnore xml, @ColumnList xml, @Alias varchar(6))
returns varchar(max)
as
begin
   declare @ret varchar(max)

   set @ret = (
       select
           ','
           +case when len(isnull(@Alias,'')) < 1 then '' else @Alias+'.' end
           +'['+g.COLUMN_NAME+']'
       from dbo.GlobalInformationSchema g
       where TABLE_CATALOG = @DatabaseName
       and TABLE_SCHEMA = @SchemaName
       and TABLE_NAME = @TableName
       and not exists
       (
           select 1
           from @ColumnsToIgnore.nodes('columns/column') c(i)
           where c.i.value('@name','varchar(30)') = g.COLUMN_NAME
       )
       and exists
       (
         select 1
         from @ColumnList.nodes('columns/column') c(i)
         where c.i.value('@name','varchar(30)') = g.COLUMN_NAME
         
         union all
         
         select 1
         from sysobjects
         where case when @ColumnList is null then 1 else 0 end=1
       )
       ORDER BY g.ORDINAL_POSITION
       FOR XML PATH('')
   )

   set @ret = substring(@ret,2,(len(@ret)-1))
   return @ret
end
go

-- Test the function
select dbo.GetColumnList(db_name()
   ,'sys'
   ,'columns'
   ,N'<columns>
    <column name="object_id" />
    <column name="column_id" />
</columns>'
   ,null
   ,'')


select dbo.GetColumnList(db_name()
   ,'sys'
   ,'tables'
   ,N'<columns>
    <column name="object_id" />
    <column name="schema_id" />
</columns>'
   ,null'
   ,'a')