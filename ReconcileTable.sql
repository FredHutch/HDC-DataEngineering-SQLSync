if object_id('dbo.ReconcileTable') is not null
begin
   exec ('drop procedure dbo.ReconcileTable')
end
go


create procedure dbo.ReconcileTable
    @TargetDatabaseName varchar(128)
   ,@TargetSchemaName varchar(128)='dbo'
   ,@TargetTableName varchar(128)
   ,@Debug bit=0
as
begin
/*
Order of operations:

1. Assemble parameters
   PK columns
   All columns
   Schema-qualified 3-part names
2. Create the templates for both type-1 and type-2 reconciling
3. Run the update statements
4. Clean up the source (?)

*/

   set @Msg = 'Starting ReconcileTable, parameters:'
               +' @TargetDatabase=' + isnull(@TargetDatabaseName,'null')
               +', @TargetSchema=' + isnull(@TargetSchemaName,'null')
               +', @TargetTable=' + isnull(@TargetTableName,'null')
               +', @Debug=' + isnull(convert(varchar,@Debug),'null')
   exec dbo.WriteLog @ProcName='DiffTable',@MessageText=@Msg, @Status='Starting'


-- PART 1: Assemble parameters
   declare 
      @type1SQL nvarchar(max)
      ,@type2SQL nvarchar(max)
      ,@cleanupSQL nvarchar(max)
      ,@ParmDefinition nvarchar(500)
      ,@RowsAffected int

      ,@PKColumns varchar(8000)
      ,@PKColumnsS varchar(8000)
      ,@PKColumnsXML xml
      ,@PKColumnsConcat varchar(8000)
      ,@PKJoin varchar(8000)

      ,@TargetColumnsToIgnore xml
      ,@ColumnList varchar(8000)
      ,@ColumnListS varchar(8000)
      ,@ColumnUpdate varchar(8000)
      
      ,@SourceLocation varchar(400)
      ,@TargetLocation varchar(400)
      ,@SKLocation varchar(400)
      ,@SourceDatabaseName varchar(128)
      ,@SourceSchemaName varchar(128)
      ,@SourceTableName varchar(128)
      ,@LoadTableName varchar(256)

      ,@SKColumn varchar(128)
      ,@TargetCreateDateColumn varchar(128)
      ,@TargetUpdateDateColumn varchar(128)
      ,@TargetBeginDateColumn varchar(128)
      ,@TargetEndDateColumn varchar(128)
      ,@SourceUpdateDateColumn varchar(128)
      
      ,@SourceMinUpdateDate datetime
      ,@SourceMaxUpdateDate datetime
      ,@BeginDate datetime
      ,@EndDate datetime


   select
     @TargetLocation = '['+s.TargetDatabase+'].['+s.TargetSchema+'].['+s.TargetTable+']'
     ,@SourceLocation = '['+s.SourceDatabase+'].['+s.SourceSchema+'].['+s.SourceTable+']'
     ,@LoadTableName = s.TargetSchema+'.HdcLoad_'+s.TargetTable
     ,@SKLocation = '['+s.TargetDatabase+'].['+s.TargetSchema+'].['+s.SurrogateTable+']'
     ,@SourceDatabaseName = s.SourceDatabase
     ,@SourceSchemaName = s.SourceSchema
     ,@SourceTableName = s.SourceTable
     ,@TargetCreateDateColumn = s.TargetCreateDateColumn
     ,@TargetUpdateDateColumn = s.TargetUpdateDateColumn
     ,@TargetBeginDateColumn = s.TargetBeginDateColumn
     ,@TargetEndDateColumn = s.TargetEndDateColumn
     ,@SourceUpdateDateColumn = s.SourceUpdateDateColumn
     ,@SKColumn = s.SurrogateKeyColumn
     ,@PKColumnsXML = s.PrimaryKeyColumns
     ,@SourceMinUpdateDate = s.SourceMaxLoadDate
   from dbo.SyncConfig s
   where s.TargetTable = @TargetTableName
   and s.TargetSchema = @TargetSchemaName
   and s.TargetDatabase = @TargetDatabaseName


   set @PKColumns    = (select dbo.GetColumnList(@TargetDatabaseName, @TargetSchemaName, @TargetTableName, null, @PKColumnsXML, null))
   set @PKColumnsS   = (select dbo.GetColumnList(@TargetDatabaseName, @TargetSchemaName, @TargetTableName, null, @PKColumnsXML, 's'))
   set @ColumnList   = (select dbo.GetColumnList(@SourceDatabaseName, @SourceSchemaName, @SourceTableName, @PKColumnsXML, null, null))
   set @ColumnListS  = (select dbo.GetColumnList(@SourceDatabaseName, @SourceSchemaName, @SourceTableName, @PKColumnsXML, null, 's'))
   set @PKJoin       = (select dbo.GetPKJoin(@PKColumnsXML, 's','t'))
   set @ColumnUpdate = (select dbo.GetUpdateList(@SourceDatabaseName, @SourceSchemaName, @SourceTableName, 's'))

   -- TO DO: Set the begin date and end date values
   set @EndDate = getdate()







   -- PART 
   -- 
   begin try
      set @type1SQL = cast('
      UPDATE t
      SET (TARGET_UPDATE_COLUMN) = getdate()
         ,(TARGET_ACTIVE_COLUMN) = 0
      FROM (TARGET_LOCATION) as t
      WHERE EXISTS
      (
         SELECT 1
         FROM (RECONCILE_LOCATION) as s
         WHERE (PK_JOIN)
      )' as nvarchar(max) );


      set @type1SQL = replace(@type1SQL, '(TARGET_LOCATION)',@TargetLocation)
      set @type1SQL = replace(@type1SQL, '(RECONCILE_LOCATION)',@ReconcileTable)
      set @type1SQL = replace(@type1SQL, '(TARGET_UPDATE_COLUMN)',@SourceUpdateDateColumn)
      set @type1SQL = replace(@type1SQL, '(TARGET_ACTIVE_COLUMN)',@LoadTableName)
      set @type1SQL = replace(@type1SQL, '(PK_JOIN)',@PKJoin)

      if @Debug=1
      begin
        select @loadSQL as LoadSQL
      end
      else
      begin
         exec (@loadSQL);

         set @RowsAffected = isnull(@@ROWCOUNT,0)
         set @Msg = 'Populate load table, '+convert(varchar,@RowsAffected)+' rows'
         exec dbo.WriteLog @ProcName='DiffTable',@MessageText=@loadSQL, @Status=@Msg
      end


      -- PART 4: Do a diff, find the differences

      /* LOGIC:
      - Do a diff using a GROUP BY to figure out what data is different. 
          Load the PKs into a temp table, with 'S' or 'T' for source or target

      The results of the UNION ALL + GROUP BY determine what to do.
      For a type-1 non-deleting table, we do the following:

      - If there are 2 rows ('s' and 't', then there's a difference to an existing row
          Do an update
      - If there is only a source row ('s'), then it's new.
          Do an insert
      - If there's only a target row ('t'), then it is either deleted or hasn't changed
          Do nothing. The reconcile process handles it if it's a hidden delete

      In the results, if HdcTableSource='s', then it's an insert. If HdcTableSource='t', then it's an update
      */

      if object_id('tempdb..#differences') is not NULL
      BEGIN
        exec ('drop table #differences');
      END

      create table #differences
      (HDCTableSource char(1)
      ,HDCPrimaryKeyConcat varchar(8000))

      if @Debug=1
      begin
        select 'create table #differences
         (HDCTableSource char(1)
         ,HDCPrimaryKeyConcat varchar(8000))' as CreateDifferencesTableSQL
      end


      set @diffSQL = cast('
      ; with diff as
      (
        SELECT
         ''s'' as HDCTableSource
         ,HDCPrimaryKeyConcat
         ,(COLUMN_LIST)
        FROM (LOAD_LOCATION)

        UNION ALL

        SELECT
         ''t'' as HDCTableSource
         ,HDCPrimaryKeyConcat = (PK_CONCAT)
         ,(COLUMN_LIST)
        FROM (TARGET_LOCATION) as s
        WHERE (TARGET_ENDDATE_COLUMN) = ''9999-12-31''
      ), results as 
      (
        SELECT 
         HDCTableSource = min(HDCTableSource)
         ,HDCPrimaryKeyConcat = min(HDCPrimaryKeyConcat)
         ,(COLUMN_LIST)
        FROM diff
        GROUP BY (COLUMN_LIST)
        HAVING COUNT(*) = 2
        OR (COUNT(*) = 1 AND min(HDCTableSource) = ''s'')
      )

      insert into #differences 
      (HDCTableSource
      ,HDCPrimaryKeyConcat)
       SELECT HDCTableSource
        ,HDCPrimaryKeyConcat
       FROM results
      ' as nvarchar(max) );

     set @diffSQL = replace(@diffSQL, '(COLUMN_LIST)',@ColumnList)
     set @diffSQL = replace(@diffSQL, '(TARGET_LOCATION)',@TargetLocation)
     set @diffSQL = replace(@diffSQL, '(LOAD_LOCATION)', @LoadTableName)
     set @diffSQL = replace(@diffSQL, '(PK_COLUMNS)',@PKColumns)
     set @diffSQL = replace(@diffSQL, '(PK_CONCAT)',@PKColumnsConcat)
     set @diffSQL = replace(@diffSQL, '(TARGET_ENDDATE_COLUMN)',@TargetEndDateColumn)


      if @Debug=1
      begin
        select @diffSQL as DiffSQL
             ,@ColumnList as ColumnList
             ,@TargetLocation as TargetLocation
             ,@LoadTableName as LoadLocation
             ,@PKColumns as PKColumns
             ,@PKColumnsConcat as PKColumnsConcat
             ,@TargetEndDateColumn as TargetEndDateColumn
      end
      else
      begin
        exec (@diffSQL);
      end


      -- PART 4: Assign surrogate keys to any rows that don't have them
      exec dbo.UpdateSurrogateKeys
         @TargetDatabaseName=@TargetDatabaseName
         ,@TargetSchemaName=@TargetSchemaName
         ,@TargetTableName=@TargetTableName
         ,@Debug=@Debug;


      -- PART 5: Upsert
      /* LOGIC:
         merge
         when matched
            update
         when not matched on target
            insert
         then delete everything based on PKs and the 
      */
      set @mergeSQL = '
      begin tran

      UPDATE t
      SET (TARGET_UPDATE_COLUMN) = getdate()
         ,(TARGET_ENDDATE_COLUMN) = (END_DATE)
      FROM (TARGET_LOCATION) as t
      INNER JOIN
      (
         SELECT 
             t.(SK_COLUMN)
            ,(PK_COLUMNS_S)
            ,(COLUMN_LIST)
         FROM (LOAD_LOCATION) s
         INNER JOIN (SK_LOCATION) as t
         ON (PK_JOIN)
         WHERE EXISTS
         (
            SELECT * 
            FROM #differences d
            WHERE d.HDCPrimaryKeyConcat = s.HDCPrimaryKeyConcat
              AND d.HdcTableSource = ''t''
         )
      ) as s 
      ON s.(SK_COLUMN) = t.(SK_COLUMN)
      
      INSERT INTO (TARGET_LOCATION)
      ((SK_COLUMN)
      ,(PK_COLUMNS)
      ,(COLUMN_LIST)
      ,(TARGET_BEGINDATE_COLUMN)
      ,(TARGET_ENDDATE_COLUMN)
      ,(TARGET_CREATE_COLUMN)
      ,(TARGET_UPDATE_COLUMN) )
      SELECT
          s.(SK_COLUMN)
         ,(PK_COLUMNS_S)
         ,(S_COLUMN_LIST)
         ,(BEGIN_DATE)
         ,(END_DATE)
         ,getdate()
         ,getdate() )
      FROM 
      (
         SELECT 
             t.(SK_COLUMN)
            ,(PK_COLUMNS_S)
            ,(COLUMN_LIST)
         FROM (LOAD_LOCATION) s
         INNER JOIN (SK_LOCATION) as t
         ON (PK_JOIN)
         WHERE EXISTS
         (
            SELECT * 
            FROM #differences d
            WHERE d.HDCPrimaryKeyConcat = s.HDCPrimaryKeyConcat
         )
      ) as s

      COMMIT TRAN;';

      set @mergeSQL = replace(@mergeSQL, '(COLUMN_LIST)',@ColumnList);
      set @mergeSQL = replace(@mergeSQL, '(LOAD_LOCATION)',@LoadTableName);
      set @mergeSQL = replace(@mergeSQL, '(TARGET_LOCATION)',@TargetLocation);
      set @mergeSQL = replace(@mergeSQL, '(SK_LOCATION)',@SKLocation);
      set @mergeSQL = replace(@mergeSQL, '(TARGET_ENDDATE_COLUMN)',@TargetEndDateColumn);
      set @mergeSQL = replace(@mergeSQL, '(TARGET_BEGINDATE_COLUMN)',@TargetBeginDateColumn);
      set @mergeSQL = replace(@mergeSQL, '(END_DATE)',@EndDate);
      set @mergeSQL = replace(@mergeSQL, '(BEGIN_DATE)',@BeginDate);
      set @mergeSQL = replace(@mergeSQL, '(PK_JOIN)',@PKJoin);
      set @mergeSQL = replace(@mergeSQL, '(PK_COLUMNS)', @PKColumns );
      set @mergeSQL = replace(@mergeSQL, '(PK_COLUMNS_S)',@PKColumnsS);
      set @mergeSQL = replace(@mergeSQL, '(SK_COLUMN)',@SKColumn);
      set @mergeSQL = replace(@mergeSQL, '(TARGET_CREATE_COLUMN)', @TargetCreateDateColumn);
      set @mergeSQL = replace(@mergeSQL, '(TARGET_UPDATE_COLUMN)', @TargetUpdateDateColumn);
      set @mergeSQL = replace(@mergeSQL, '(S_COLUMN_LIST)', @ColumnListS);


      if @Debug=1
      begin
         select @mergeSQL as MergeSQL
               ,@ColumnList as ColumnList
               ,@SourceLocation as SourceLocation
               ,@TargetLocation as TargetLocation
               ,@SKLocation as SKLocation
               ,@TargetEndDateColumn as TargetEndDateColumn
               ,@PKJoin as PKJoin
               ,@PKColumnsConcat as PKColumnsConcat
               ,@PKColumns as PKColumns
               ,@PKColumnsS as PKColumnsS
               ,@SKColumn as SKColumn
               ,@TargetCreateDateColumn as TargetCreateDateColumn
               ,@TargetUpdateDateColumn as TargetUpdateDateColumn
               ,@ColumnUpdate as ColumnUpdate
               ,@ColumnListS as ColumnListS
      end
      else
      begin
         exec (@mergeSQL);
      end

      -- PART 6: Clean up the source if specified
      set @cleanupSQL = N'
      DELETE 
      FROM (SOURCE_LOCATION)
      WHERE (SOURCE_UPDATE_COLUMN) <= ''(SOURCE_MAX_UPDATEDATE)'' ';
      set @cleanupSQL = replace(@cleanupSQL, '(SOURCE_LOCATION)',@SourceLocation);
      set @cleanupSQL = replace(@cleanupSQL, '(SOURCE_MAX_UPDATEDATE)',isnull(convert(varchar(30),@SourceMaxUpdateDate,121),'9999-12-31'));
      set @cleanupSQL = replace(@cleanupSQL, '(SOURCE_UPDATE_COLUMN)',@SourceUpdateDateColumn);

      if @Debug=1
      begin
         select @cleanupSQL as CleanupSQL
               ,@SourceLocation as SourceLocation
               ,@SourceUpdateDateColumn as SourceUpdateDateColumn
               ,isnull(@SourceMaxUpdateDate,'9999-12-31') as SourceMaxUpdateDate
      end
      else
      begin
         exec (@cleanupSQL)
      end


      -- PART 7: Update state management
      set @cleanupSQL=N'update dbo.SyncConfig
         set SourceMaxLoadDate = '''+@SourceMaxUpdateDate+'''
         where TargetDatabase = '''+@TargetDatabaseName+'''
           and TargetSchema = '''+@TargetSchemaName+'''
           and TargetTable = '''+@TargetTableName+''''

      if @Debug=1
      begin
         select @cleanupSQL as StateUpdateSQL
      end
      else
      begin
         exec (@cleanupSQL)
      end
   end try
   begin catch
      select @@ERROR
   end catch
end
go