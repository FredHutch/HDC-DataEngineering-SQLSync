if object_id('dbo.UpdateSurrogateKeys') is not null
begin
   exec ('drop procedure dbo.UpdateSurrogateKeys')
end
go

create procedure dbo.UpdateSurrogateKeys
    @TargetDatabaseName varchar(128)
   ,@TargetSchemaName varchar(128)='dbo'
   ,@TargetTableName varchar(128)
   ,@Debug bit=0
as
begin
   declare @insertSQL nvarchar(max)
      ,@getMaxValueSQL nvarchar(max)
   /*
   Order of operations:

   1. Assemble parameters
   2. Get the max SK value in the current table
   3. Insert query
   */

   -- PART 1: Assemble parameters
      declare 
         @PKColumns varchar(8000)
        ,@PKColumnsXML xml
        ,@PKJoin varchar(8000)
        ,@SKLocation varchar(400)
        ,@SourceLocation varchar(400)
        ,@SKColumn varchar(128)
        ,@MaxSKValue bigint
        ,@ParmDefinition nvarchar(500)

   select
     @SourceLocation = '['+s.SourceDatabase+'].['+s.SourceSchema+'].['+s.SourceTable+']'
     ,@SKLocation = '['+s.TargetDatabase+'].['+s.TargetSchema+'].['+s.SurrogateTable+']'
     ,@PKColumnsXML = s.PrimaryKeyColumns
     ,@SKColumn = s.SurrogateKeyColumn
   from dbo.SyncConfig s
   where s.TargetTable = @TargetTableName
   and s.TargetSchema = @TargetSchemaName
   and s.TargetDatabase = @TargetDatabaseName

   set @PKColumns = (select dbo.GetColumnList(@TargetDatabaseName, @TargetSchemaName, @TargetTableName, null, @PKColumnsXML, null))
   set @PKJoin = (select dbo.GetPKJoin(@PKColumnsXML, 's','t'))


   -- PART 2: Get the max SK value in the current table
   set @getMaxValueSQL = N'select @maxSKOUT = max('+@SKColumn+') from '+@SKLocation
   set @ParmDefinition = '@maxSKOUT int OUTPUT'

   exec sp_executeSQL 
      @getMaxValueSQL
      ,@ParmDefinition
      ,@maxSKOUT = @MaxSKValue OUTPUT

   set @MaxSKValue = isnull(@MaxSKValue,0)


   -- PART 3: Insert Query
   begin try
     set @insertSQL = '
     ; with src as 
     (
        SELECT
           (PK_COLUMNS)
        FROM (SOURCE_LOCATION) s
        GROUP BY (PK_COLUMNS)
     )

     INSERT INTO (SK_LOCATION)
     ( (SK_COLUMN), (PK_COLUMNS) )
     SELECT   
        ROW_NUMBER() OVER (ORDER BY getdate()) + (MAX_CURRENT_SK_VALUE)
        ,(PK_COLUMNS)
     FROM src s
     WHERE NOT EXISTS
     (
        SELECT 1
        FROM (SK_LOCATION) t
        WHERE (PK_JOIN)
     )'

     set @insertSQL = replace(@insertSQL, '(SK_LOCATION)',@SKLocation)
     set @insertSQL = replace(@insertSQL, '(SOURCE_LOCATION)',@SourceLocation)
     set @insertSQL = replace(@insertSQL, '(PK_COLUMNS)',@PKColumns)
     set @insertSQL = replace(@insertSQL, '(PK_JOIN)', @PKJoin)
     set @insertSQL = replace(@insertSQL, '(SK_COLUMN)',@SKColumn)
     set @insertSQL = replace(@insertSQL, '(MAX_CURRENT_SK_VALUE)',@MaxSKValue)

     if @Debug=1
     begin
        select @insertSQL as InsertSKSQL
     end
     else
     begin
        exec (@insertSQL)
     end
   end try
   begin catch
    select @@error
   end catch
end
go