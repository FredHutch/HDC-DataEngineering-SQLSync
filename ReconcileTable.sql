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
2. Create the templates for both type-1 and type-2 reconcile statements
3. Clean up the reconcile table if that's enabled

*/
-- PART 1: Assemble parameters
   declare 
      @type1SQL nvarchar(max)
      ,@type2SQL nvarchar(max)
      ,@cleanupSQL nvarchar(max)
      ,@ParmDefinition nvarchar(500)
      ,@RowsAffected int
      ,@Msg VARCHAR(max)

      ,@PKJoin varchar(8000)
      ,@PKColumnsXML xml

      ,@SourceLocation varchar(400)
      ,@TargetLocation varchar(400)
      ,@ReconcileTable varchar(400)
      ,@SourceDatabaseName varchar(128)
      ,@SourceSchemaName varchar(128)
      ,@SourceTableName varchar(128)
      ,@IsSourceCleanupAfterRun bit
      ,@ProcessMode varchar(8)

      ,@TargetCreateDateColumn varchar(128)
      ,@TargetUpdateDateColumn varchar(128)
      ,@TargetBeginDateColumn varchar(128)
      ,@TargetEndDateColumn varchar(128)
      ,@TargetActiveColumn varchar(128)

      ,@BeginDate datetime
      ,@EndDate datetime

   select
     @TargetLocation = '['+s.TargetDatabase+'].['+s.TargetSchema+'].['+s.TargetTable+']'
     ,@SourceLocation = '['+s.SourceDatabase+'].['+s.SourceSchema+'].['+s.SourceTable+']'
     ,@SourceDatabaseName = s.SourceDatabase
     ,@SourceSchemaName = s.SourceSchema
     ,@SourceTableName = s.SourceTable
     ,@TargetCreateDateColumn = s.TargetCreateDateColumn
     ,@TargetUpdateDateColumn = s.TargetUpdateDateColumn
     ,@TargetBeginDateColumn = s.TargetBeginDateColumn
     ,@TargetEndDateColumn = s.TargetEndDateColumn
     ,@TargetActiveColumn  = s.TargetActiveColumn
     ,@ReconcileTable = s.ReconcileTable
     ,@PKColumnsXML = s.PrimaryKeyColumns
     ,@IsSourceCleanupAfterRun = s.IsSourceCleanupAfterRun
   from dbo.SyncConfig s
   where s.TargetTable = @TargetTableName
   and s.TargetSchema = @TargetSchemaName
   and s.TargetDatabase = @TargetDatabaseName


   set @PKJoin       = (select dbo.GetPKJoin(@PKColumnsXML, 's','t'))
   set @ProcessMode = (select case when @TargetBeginDateColumn is null and @TargetActiveColumn is not null
                                   then 'Type-1'
                                   when @TargetActiveColumn is null and @TargetBeginDateColumn is not null
                                   then 'Type-2'
                                   else 'Unknown' end)
   
   -- Set the begin date and end date values
   set @BeginDate = (select dbo.GetBeginDate(@SourceDatabaseName, @SourceSchemaName, @SourceTableName))
   set @EndDate = (select dbo.GetEndDate(@SourceDatabaseName, @SourceSchemaName, @SourceTableName, @BeginDate))

   set @Msg = 'Starting ReconcileTable, parameters:'
               +' @TargetDatabase=' + isnull(@TargetDatabaseName,'null')
               +', @TargetSchema=' + isnull(@TargetSchemaName,'null')
               +', @TargetTable=' + isnull(@TargetTableName,'null')
               +', @Debug=' + isnull(convert(varchar,@Debug),'null')
               +', @BeginDate=' + isnull(convert(varchar,@BeginDate),'null')
               +', @EndDate=' + isnull(convert(varchar,@EndDate),'null')
               +', @ProcessMode=' + isnull(convert(varchar,@ProcessMode),'null')
   exec dbo.WriteLog @ProcName='ReconcileTable',@MessageText=@Msg, @Status='Starting'


   -- PART 2: Create the templates for both type-1 and type-2 reconcile statements
   begin try
      -- Type 1. 
      set @type1SQL = cast('
      UPDATE t
      SET (TARGET_UPDATE_COLUMN) = getdate()
         ,(TARGET_ACTIVE_COLUMN) = 0
      FROM (TARGET_LOCATION) as t
      WHERE NOT EXISTS
      (
         SELECT 1
         FROM (RECONCILE_LOCATION) as s
         WHERE (PK_JOIN)
      )' as nvarchar(max) );


      set @type1SQL = replace(@type1SQL, '(TARGET_LOCATION)',@TargetLocation)
      set @type1SQL = replace(@type1SQL, '(RECONCILE_LOCATION)',@ReconcileTable)
      set @type1SQL = replace(@type1SQL, '(TARGET_UPDATE_COLUMN)',@TargetUpdateDateColumn)
      set @type1SQL = replace(@type1SQL, '(TARGET_ACTIVE_COLUMN)',@TargetActiveColumn)
      set @type1SQL = replace(@type1SQL, '(PK_JOIN)',@PKJoin)


      -- Type 2.
      set @type2SQL = cast('
      UPDATE t
      SET (TARGET_UPDATE_COLUMN) = getdate()
         ,(TARGET_ENDDATE_COLUMN) = ''(END_DATE)''
      FROM (TARGET_LOCATION) as t
      WHERE t.(TARGET_ENDDATE_COLUMN) = ''9999-12-31''
      AND NOT EXISTS
      (
         SELECT 1
         FROM (RECONCILE_LOCATION) as s
         WHERE (PK_JOIN)
      )' as nvarchar(max) );


      set @type2SQL = replace(@type2SQL, '(TARGET_LOCATION)',@TargetLocation)
      set @type2SQL = replace(@type2SQL, '(RECONCILE_LOCATION)',@ReconcileTable)
      set @type2SQL = replace(@type2SQL, '(TARGET_UPDATE_COLUMN)',@TargetUpdateDateColumn)
      set @type2SQL = replace(@type2SQL, '(TARGET_ENDDATE_COLUMN)',@TargetEndDateColumn)
      set @type2SQL = replace(@type2SQL, '(END_DATE)',convert(varchar(30),@EndDate,121))
      set @type2SQL = replace(@type2SQL, '(PK_JOIN)',@PKJoin)


      if @ProcessMode='Type-1'
      begin
        if @Debug=1
        begin
          select @type1SQL as Type1SQL
                 ,@TargetLocation as TargetLocation
                 ,@ReconcileTable as ReconcileTable
                 ,@TargetUpdateDateColumn as TargetUpdateDateColumn
                 ,@TargetActiveColumn as TargetActiveColumn
                 ,@PKJoin as PKJoin
        end
        else
        begin
           exec (@type1SQL);

           set @RowsAffected = isnull(@@ROWCOUNT,0)
           set @Msg = 'Reconcile type-1 table, '+convert(varchar,@RowsAffected)+' rows'
           exec dbo.WriteLog @ProcName='ReconcileTable',@MessageText=@type1SQL, @Status=@Msg
        end
      end
      else if @ProcessMode='Type-2'
      begin
        if @Debug=1
        begin
          select @type2SQL as Type2SQL
                 ,@TargetLocation as TargetLocation
                 ,@ReconcileTable as ReconcileTable
                 ,@TargetUpdateDateColumn as TargetUpdateDateColumn
                 ,@TargetEndDateColumn as TargetEndDateColumn
                 ,@EndDate as EndDate
                 ,@PKJoin as PKJoin
        end
        else
        begin
           exec (@type2SQL);

           set @RowsAffected = isnull(@@ROWCOUNT,0)
           set @Msg = 'Reconcile type-2 table, '+convert(varchar,@RowsAffected)+' rows'
           exec dbo.WriteLog @ProcName='ReconcileTable',@MessageText=@type2SQL, @Status=@Msg
        end
      end


      -- PART 3: Clean up the source if specified
      if @IsSourceCleanupAfterRun=1
      begin
         set @cleanupSQL = N'
         DELETE 
         FROM (RECONCILE_LOCATION)'
         set @cleanupSQL = replace(@cleanupSQL, '(RECONCILE_LOCATION)',@ReconcileTable);

         if @Debug=1
         begin
            select @cleanupSQL as CleanupSQL
                  ,@ReconcileTable as ReconcileTable
         end
         else
         begin
            exec (@cleanupSQL)

            set @RowsAffected = isnull(@@ROWCOUNT,0)
            set @Msg = 'Clean up reconcile table after run, '+convert(varchar,@RowsAffected)+' rows'
            exec dbo.WriteLog @ProcName='ReconcileTable',@MessageText=@type2SQL, @Status=@Msg
         end
      end
   end try
   begin catch
      select @@ERROR
   end catch
end
go