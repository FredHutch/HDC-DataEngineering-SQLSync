if object_id('dbo.SyncTable') is not null
begin
   exec ('drop procedure dbo.SyncTable');
end
go

create procedure dbo.SyncTable
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
   2. Find the source's max UpdateDate if available
   3. Assign surrogate keys to any rows that don't have them
   4. Copy the source data into a load table, including SK
   5. Do a diff, find the differences
   6. Update/insert the target based on the source
   7. Clean up the source if specified
   8. Update state management
   */

   -- PART 1: Assemble parameters
   declare @updateSQL nvarchar(max)
      ,@mergeSQL nvarchar(max)
      ,@diffSQL nvarchar(max)
      ,@loadSQL nvarchar(max)
      ,@cleanupSQL nvarchar(max)
      ,@RowsAffected int
      ,@Msg VARCHAR(max)
      ,@ParmDefinition nvarchar(500)

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
      ,@DiffTableName varchar(256)
      ,@SKColumn varchar(128)
      ,@TargetActiveColumn varchar(128)
      ,@TargetCreateDateColumn varchar(128)
      ,@TargetUpdateDateColumn varchar(128)
      ,@SourceUpdateDateColumn varchar(128)
      ,@DoCleanup bit
      ,@SourceMinUpdateDate datetime
      ,@SourceMaxUpdateDate datetime

   set @Msg = 'Starting SyncTable, parameters:'
               +' @TargetDatabase=' + isnull(@TargetDatabaseName,'null')
               +', @TargetSchema=' + isnull(@TargetSchemaName,'null')
               +', @TargetTable=' + isnull(@TargetTableName,'null')
               +', @Debug=' + isnull(convert(varchar,@Debug),'null')
   set @TargetLocation = '['+@TargetDatabaseName+'].['+@TargetSchemaName+'].['+@TargetTableName+']'
   exec dbo.WriteLog @ProcName='SyncTable',@ObjectName=@TargetLocation
                    ,@MessageText=@Msg, @Status='Starting'

   select
       @TargetLocation = '['+s.TargetDatabase+'].['+s.TargetSchema+'].['+s.TargetTable+']'
      ,@SourceLocation = '['+s.SourceDatabase+'].['+s.SourceSchema+'].['+s.SourceTable+']'
      ,@LoadTableName = s.TargetSchema+'.HdcLoad_'+s.TargetTable
      ,@DiffTableName = s.TargetSchema+'.HdcDiff_'+s.TargetTable
      ,@SKLocation = '['+s.TargetDatabase+'].['+s.TargetSchema+'].['+s.SurrogateTable+']'
      ,@SourceDatabaseName = s.SourceDatabase
      ,@SourceSchemaName = s.SourceSchema
      ,@SourceTableName = s.SourceTable
      ,@TargetActiveColumn = s.TargetActiveColumn
      ,@TargetCreateDateColumn = s.TargetCreateDateColumn
      ,@TargetUpdateDateColumn = s.TargetUpdateDateColumn
      ,@SourceUpdateDateColumn = s.SourceUpdateDateColumn
      ,@SKColumn = s.SurrogateKeyColumn
      ,@PKColumnsXML = s.PrimaryKeyColumns
      ,@SourceMinUpdateDate = s.SourceMaxLoadDate
      ,@DoCleanup = s.CleanUpSourceAfterRun
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


   -- get the concatenation of primary key columns.
   set @PKColumnsConcat =  (
     SELECT 'cast(s.'+s.COLUMN_NAME+' as varchar)+''|''+'
     FROM dbo.GlobalInformationSchema s
     WHERE s.TABLE_CATALOG = @SourceDatabaseName
     AND s.TABLE_SCHEMA = @SourceSchemaName
     AND s.TABLE_NAME = @SourceTableName
     AND EXISTS
     (
       SELECT 1
       FROM @PKColumnsXML.nodes('columns/column') p(i)
       WHERE p.i.value('@name','varchar(128)') = s.COLUMN_NAME
     )
     FOR XML PATH('')
   )
   set @PKColumnsConcat = SUBSTRING(@PKColumnsConcat,1,len(@PKColumnsConcat)-5)



   -- PART 2: Find the source's max(UpdateDate) if available
   set @updateSQL = N'select @UpdateDateOUT = max('+@SourceUpdateDateColumn+') from '+@SourceLocation
   set @ParmDefinition = '@UpdateDateOUT datetime OUTPUT'

   exec sp_executeSQL 
       @updateSQL
      ,@ParmDefinition
      ,@UpdateDateOUT = @SourceMaxUpdateDate OUTPUT

   set @SourceMinUpdateDate = isnull(@SourceMinUpdateDate, '1900-01-01')
   set @SourceMaxUpdateDate = isnull(@SourceMaxUpdateDate, '9999-12-31');

   set @Msg = 'SyncTable variables:'
               +' @SourceMinUpdateDate=' + isnull(convert(varchar(30),@SourceMinUpdateDate,121),'null')
               +', @SourceMaxUpdateDate=' + isnull(convert(varchar(30),@SourceMaxUpdateDate,121),'null')
   exec dbo.WriteLog @ProcName='SyncTable',@ObjectName=@TargetLocation
                    ,@MessageText=@Msg, @Status='Assigned variables'


   -- PART 3: Assign surrogate keys to any rows that don't have them
   exec dbo.UpdateSurrogateKeys
      @TargetDatabaseName=@TargetDatabaseName
      ,@TargetSchemaName=@TargetSchemaName
      ,@TargetTableName=@TargetTableName
      ,@Debug=@Debug;

   exec dbo.WriteLog @ProcName='SyncTable',@ObjectName=@TargetLocation
                    ,@Status='Called UpdateSurrogateKeys'



   -- PART 4: Copy the source data into a load table, including SK
   -- Drop the load table first if it already exists
   begin try
      if object_id(@LoadTableName) is not null
      begin
         set @loadSQL = 'drop table '+@LoadTableName

         if @Debug=1
         begin
            select @loadSQL as DropTableSQL
         end
         else 
         begin
            exec (@loadSQL)
            exec dbo.WriteLog @ProcName='SyncTable',@ObjectName=@TargetLocation
                             ,@MessageText=@loadSQL, @Status='Dropped load table'
         end
      end

      set @loadSQL = cast('
      ; with src as 
      (
         select distinct
            PrimaryKeyRanker = ROW_NUMBER() OVER (PARTITION BY (PK_COLUMNS) ORDER BY (SOURCE_UPDATE_COLUMN) desc)
            ,(PK_COLUMNS)
            ,(COLUMN_LIST)
         from (SOURCE_LOCATION) as s
         where (SOURCE_UPDATE_COLUMN) <= ''(SOURCE_MAX_UPDATEDATE)''
           and (SOURCE_UPDATE_COLUMN) >= ''(SOURCE_MIN_UPDATEDATE)''
      )

      SELECT
          t.(SK_COLUMN)
         ,(PK_COLUMNS_S)
         ,(COLUMN_LIST)
      INTO (LOAD_LOCATION)
      FROM src s
      INNER JOIN (SK_LOCATION) t
      ON (PK_JOIN)
      WHERE s.PrimaryKeyRanker = 1
      ' as nvarchar(max) );

      set @loadSQL = replace(@loadSQL, '(COLUMN_LIST)',@ColumnList)
      set @loadSQL = replace(@loadSQL, '(SOURCE_LOCATION)',@SourceLocation)
      set @loadSQL = replace(@loadSQL, '(SOURCE_MAX_UPDATEDATE)', convert(varchar(30),@SourceMaxUpdateDate,121))
      set @loadSQL = replace(@loadSQL, '(SOURCE_MIN_UPDATEDATE)', convert(varchar(30),@SourceMinUpdateDate,121))
      set @loadSQL = replace(@loadSQL, '(SOURCE_UPDATE_COLUMN)',@SourceUpdateDateColumn)
      set @loadSQL = replace(@loadSQL, '(LOAD_LOCATION)',@LoadTableName)
      set @loadSQL = replace(@loadSQL, '(PK_COLUMNS)',@PKColumns)
      set @loadSQL = replace(@loadSQL, '(PK_COLUMNS_S)',@PKColumnsS)
      set @loadSQL = replace(@loadSQL, '(SK_COLUMN)',@SKColumn)
      set @loadSQL = replace(@loadSQL, '(SK_LOCATION)',@SKLocation)
      set @loadSQL = replace(@loadSQL, '(PK_JOIN)',@PKJoin)

      if @Debug=1
      begin
         select @loadSQL as LoadSQL
      end
      else
      begin
         exec (@loadSQL);

         set @RowsAffected = isnull(@@ROWCOUNT,0)
         exec dbo.WriteLog @ProcName='SyncTable',@ObjectName=@TargetLocation
                          ,@MessageText=@loadSQL, @Status='Populated load table'
                          ,@RowsAffected=@RowsAffected
      end


      -- PART 5: Do a diff, find the differences

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
      */
      if object_id(@DiffTableName) is not null
      begin
         set @diffSQL = 'drop table '+@DiffTableName

         if @Debug=1
         begin
            select @diffSQL as DropTableSQL
         end
         else 
         begin
            exec (@diffSQL)
            exec dbo.WriteLog @ProcName='SyncTable',@ObjectName=@TargetLocation
                             ,@MessageText=@diffSQL, @Status='Dropped diff table'
         end
      end

      set @diffSQL = cast('
      ; with diff as
      (
         SELECT
            ''s'' as HDCTableSource
            ,(SK_COLUMN)
            ,(COLUMN_LIST)
         FROM (LOAD_LOCATION)

         UNION ALL

         SELECT
            ''t'' as HDCTableSource
            ,(SK_COLUMN)
            ,(COLUMN_LIST)
         FROM (TARGET_LOCATION) as s
         WHERE (ACTIVE_COLUMN) = 1
      ), results as 
      (
         SELECT 
             HDCTableSource = min(HDCTableSource)
            ,(SK_COLUMN)
            ,(COLUMN_LIST)
         FROM diff
         GROUP BY (SK_COLUMN), (COLUMN_LIST)
         HAVING COUNT(*) = 2
         OR (COUNT(*) = 1 AND min(HDCTableSource) = ''s'')
      )

      SELECT HDCTableSource
         ,(SK_COLUMN)
      INTO (DIFF_LOCATION)
      FROM results
      ' as nvarchar(max) );

      set @diffSQL = replace(@diffSQL, '(COLUMN_LIST)',@ColumnList)
      set @diffSQL = replace(@diffSQL, '(TARGET_LOCATION)',@TargetLocation)
      set @diffSQL = replace(@diffSQL, '(LOAD_LOCATION)', @LoadTableName)
      set @diffSQL = replace(@diffSQL, '(SK_COLUMN)',@SKColumn)
      set @diffSQL = replace(@diffSQL, '(DIFF_LOCATION)',@DiffTableName)
      set @diffSQL = replace(@diffSQL, '(ACTIVE_COLUMN)',@TargetActiveColumn)


      if @Debug=1
      begin
         select @diffSQL as DiffSQL
            ,@ColumnList as ColumnList
            ,@TargetLocation as TargetLocation
            ,@LoadTableName as LoadLocation
            ,@SKColumn as SKColumn
            ,@DiffTableName as DiffTableName
            ,@TargetActiveColumn as TargetActiveColumn
      end
      else
      begin
         exec (@diffSQL);

         set @RowsAffected = isnull(@@ROWCOUNT,0)
         exec dbo.WriteLog @ProcName='SyncTable',@ObjectName=@TargetLocation
                          ,@MessageText=@diffSQL, @Status='Populated diff table'
                          ,@RowsAffected=@RowsAffected
      end


      -- PART 5: Upsert
      /* LOGIC:
         merge
         when matched
            update
         when not matched on target
            insert
         then delete everything based on PKs and the 
      */
      set @mergeSQL = 'CREATE UNIQUE CLUSTERED INDEX fakePK ON (LOAD_LOCATION) ( (SK_COLUMN) ) with (DATA_COMPRESSION = ROW)'
      set @mergeSQL = replace(@mergeSQL, '(LOAD_LOCATION)',@LoadTableName);
      set @mergeSQL = replace(@mergeSQL, '(SK_COLUMN)',@SKColumn);

      if @Debug=1
      begin
         select @mergeSQL as MergeSQL
               ,@LoadTableName as LoadTableName
               ,@SKColumn as SKColumn
      end
      else
      begin
         exec (@mergeSQL);
         exec dbo.WriteLog @ProcName='SyncTable',@ObjectName=@TargetLocation
                          ,@MessageText=@mergeSQL, @Status='Created index on load table'
      end



      set @mergeSQL = '
      MERGE (TARGET_LOCATION) as t 
      USING 
         (
         SELECT 
             s.(SK_COLUMN)
            ,(PK_COLUMNS_S)
            ,(COLUMN_LIST)
         FROM (LOAD_LOCATION) s
         WHERE EXISTS
          (
            SELECT * 
            FROM (DIFF_LOCATION) d
            WHERE d.(SK_COLUMN) = s.(SK_COLUMN)
          )
         ) as s 
      ON s.(SK_COLUMN) = t.(SK_COLUMN)
      WHEN MATCHED THEN
         UPDATE SET
         (COLUMN_UPDATE)
         ,(ACTIVE_COLUMN) = 1
         ,(TARGET_UPDATE_COLUMN) = getdate() 
      WHEN NOT MATCHED BY TARGET THEN
         INSERT
         ( (SK_COLUMN), (PK_COLUMNS), (COLUMN_LIST), (ACTIVE_COLUMN), (TARGET_CREATE_COLUMN), (TARGET_UPDATE_COLUMN) )
         VALUES
         ( s.(SK_COLUMN), (PK_COLUMNS_S), (S_COLUMN_LIST), 1, getdate(), getdate() )
      ;';

      set @mergeSQL = replace(@mergeSQL, '(COLUMN_LIST)',@ColumnList);
      set @mergeSQL = replace(@mergeSQL, '(LOAD_LOCATION)',@LoadTableName);
      set @mergeSQL = replace(@mergeSQL, '(TARGET_LOCATION)',@TargetLocation);
      set @mergeSQL = replace(@mergeSQL, '(ACTIVE_COLUMN)',@TargetActiveColumn);
      set @mergeSQL = replace(@mergeSQL, '(DIFF_LOCATION)',@DiffTableName);
      set @mergeSQL = replace(@mergeSQL, '(PK_COLUMNS)', @PKColumns );
      set @mergeSQL = replace(@mergeSQL, '(PK_COLUMNS_S)',@PKColumnsS);
      set @mergeSQL = replace(@mergeSQL, '(SK_COLUMN)',@SKColumn);
      set @mergeSQL = replace(@mergeSQL, '(TARGET_CREATE_COLUMN)', @TargetCreateDateColumn);
      set @mergeSQL = replace(@mergeSQL, '(TARGET_UPDATE_COLUMN)', @TargetUpdateDateColumn);
      set @mergeSQL = replace(@mergeSQL, '(COLUMN_UPDATE)', @ColumnUpdate);
      set @mergeSQL = replace(@mergeSQL, '(S_COLUMN_LIST)', @ColumnListS);


      if @Debug=1
      begin
         select @mergeSQL as MergeSQL
               ,@ColumnList as ColumnList
               ,@SourceLocation as SourceLocation
               ,@TargetLocation as TargetLocation
               ,@SKLocation as SKLocation
               ,@TargetActiveColumn as TargetActiveColumn
               ,@DiffTableName as DiffTableName
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

         set @RowsAffected = isnull(@@ROWCOUNT,0)
         exec dbo.WriteLog @ProcName='SyncTable',@ObjectName=@TargetLocation
                          ,@MessageText=@mergeSQL, @Status=@Msg
                          ,@RowsAffected=@RowsAffected
      end

      -- PART 6: Clean up the source if specified
      if @DoCleanup=1
      begin
         set @cleanupSQL = N'
         DELETE 
         FROM (SOURCE_LOCATION)
         WHERE (SOURCE_UPDATE_COLUMN) <= ''(SOURCE_MAX_UPDATEDATE)''
         ';
         set @cleanupSQL = replace(@cleanupSQL, '(SOURCE_LOCATION)',@SourceLocation);
         set @cleanupSQL = replace(@cleanupSQL, '(SOURCE_MAX_UPDATEDATE)',convert(varchar(30),@SourceMaxUpdateDate,121))
         set @cleanupSQL = replace(@cleanupSQL, '(SOURCE_UPDATE_COLUMN)',@SourceUpdateDateColumn);

        if @Debug=1
        begin
            select @cleanupSQL as CleanupSQL
                  ,@SourceLocation as SourceLocation
                  ,@SourceUpdateDateColumn as SourceUpdateDateColumn
                  ,@SourceMaxUpdateDate as SourceMaxUpdateDate
        end
        else
        begin
            exec (@cleanupSQL)

            set @RowsAffected = isnull(@@ROWCOUNT,0)
            exec dbo.WriteLog @ProcName='SyncTable',@ObjectName=@TargetLocation
                             ,@MessageText=@cleanupSQL, @Status='Cleaned up source table'
                             ,@RowsAffected=@RowsAffected
        end
      end
      else
      begin
          exec dbo.WriteLog @ProcName='SyncTable',@ObjectName=@TargetLocation
                           ,@Status='Skipped cleanup because CleanUpSourceAfterRun=0'
      end


      -- PART 7: Update state management and do cleanup
      set @cleanupSQL=N'update dbo.SyncConfig
         set SourceMaxLoadDate = '''+convert(varchar(30),@SourceMaxUpdateDate,121)+'''
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

         set @Msg = 'Updated source max load date to '+convert(varchar(30),@SourceMaxUpdateDate,121)
         exec dbo.WriteLog @ProcName='SyncTable',@ObjectName=@TargetLocation
                          ,@Status=@Msg
      end

      -- PART 7b: Truncate the load and diff tables, to save space
      set @cleanupSQL=N'truncate table '+@LoadTableName

      if @Debug=1
      begin
         select @cleanupSQL as StateUpdateSQL
      end
      else
      begin
         exec (@cleanupSQL)

         exec dbo.WriteLog @ProcName='SyncTable',@ObjectName=@TargetLocation
                          ,@Status='Truncated load table', @MessageText=@cleanupSQL
      end

      set @cleanupSQL=N'truncate table '+@DiffTableName

      if @Debug=1
      begin
         select @cleanupSQL as StateUpdateSQL
      end
      else
      begin
         exec (@cleanupSQL)

         exec dbo.WriteLog @ProcName='SyncTable',@ObjectName=@TargetLocation
                          ,@Status='Truncated diff table', @MessageText=@cleanupSQL
      end
   end try
   begin catch
      set @Msg = 'ERROR! '+error_message() 
               + ', ErrorNumber='+convert(varchar,@@ERROR)
               + ', ErrorLine='+convert(varchar,error_line())
      select @Msg
      exec dbo.WriteLog @ProcName='SyncTable',@ObjectName=@TargetLocation
                       ,@Status='ERROR',@MessageText=@Msg
   end catch
end
go