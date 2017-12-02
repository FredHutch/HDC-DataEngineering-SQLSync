if object_id('dbo.GetPKJoin') is not null
begin
   exec ('drop function dbo.GetPKJoin')
end
go


create function dbo.GetPKJoin (@ColumnList xml, @FirstAlias varchar(6), @SecondAlias varchar(6))
returns varchar(8000)
as
begin
   declare @ret varchar(8000)

   ; with src as 
   (
   select c.i.value('@name','varchar(30)') as ColumnName
   from @ColumnList.nodes('columns/column') c(i)
   )
   select @ret = (SELECT ' and '+case when @FirstAlias is null or len(@FirstAlias) < 1 then ''
                                   else @FirstAlias+'.' end
                                   +'['+ColumnName+'] = '+@SecondAlias+'.['+ColumnName+']' 
       from src
       for xml path (''))

   set @ret = substring(@ret,6,len(@ret)-4)
   return @ret
end
go


-- Test the function
select dbo.GetPKJoin(N'<columns>
      <column name="PKColumn" />
      <column name="SecondPKColumn" />
    </columns>'
    ,'s'
    ,'t')


select dbo.GetPKJoin(N'<columns>
      <column name="PKColumn" />
      <column name="SecondPKColumn" />
    </columns>'
    ,''
    ,'t')
go