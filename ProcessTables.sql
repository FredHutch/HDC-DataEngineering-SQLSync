if object_id('dbo.ProcessTables') is not null
begin
   exec ('drop procedure dbo.ProcessTables')
end
go

create procedure ProcessTables
    @TargetDatabaseName varchar(128)=null
   ,@TargetTableName varchar(128)=null
   ,@SourceDatabaseName varchar(128)=null
   ,@SourceTableName varchar(128)=null
   ,@ProcessMode varchar(32)=null
   ,@TableGroup varchar(32)=null
   ,@Debug bit=0
as
begin

   set nocount on

   declare 
       @lTargetDatabaseName varchar(128)
      ,@lTargetSchemaName varchar(128)
      ,@lTargetTableName varchar(128)
      ,@lProcessMode varchar(32)
      ,@Msg varchar(max)
      ,@StoredProcName varchar(255)
      ,@CurrentOperation varchar(255)
      ,@ErrorFlag bit = 0
      ,@ErrorMessage varchar(max)
   
/*
This sproc iterates over table, syncing, diffing, or reconciling them one at a time

Order of operations:
- Load the tables to process into a temp table
- Using a while loop, call either Diff, Sync, or Reconcile
*/

   set @ErrorMessage = ''
   set @StoredProcName = object_name(@@procid)

   set @Msg = 'Starting ' + @StoredProcName + ', filters:'
                +' @TargetDatabase=' + isnull(@TargetDatabaseName,'null')
                +', @TargetTable=' + isnull(@TargetTableName,'null')
                +', @SourceDatabase Name=' + isnull(@SourceDatabaseName,'null')
                +', @SourceTableName=' + isnull(@SourceTableName,'null')
                +', @ProcessMode=' + isnull(@ProcessMode,'null')
                +', @TableGroup=' + isnull(@TableGroup,'null')
                +', @Debug=' + isnull(convert(varchar,@Debug),'null')
   exec dbo.WriteLog @ProcName=@StoredProcName, @MessageText=@Msg, @Status='Starting'

   if object_id('tempdb..#tablesToProcess') is not null
   begin
      exec ('drop table #tablesToProcess');
   end

   select
       s.TargetDatabase
      ,s.TargetSchema
      ,s.TargetTable
      ,s.ProcessMode
   into #tablesToProcess
   from dbo.SyncConfig s
   where 1=1
   and (s.TargetDatabase = @TargetDatabaseName or @TargetDatabaseName is null)
   and (s.TargetTable = @TargetTableName or @TargetTableName is null)
   and (s.SourceDatabase = @SourceDatabaseName or @SourceDatabaseName is null)
   and (s.SourceTable = @SourceTableName or @SourceTableName is null)
   and (s.TableGroup = @TableGroup or @TableGroup is null)
   and (s.ProcessMode = @ProcessMode or @ProcessMode is null
          or (@ProcessMode='Reconcile' and ReconcileTable is not null) )
   and s.IsActive = 1

   while exists (select * from #tablesToProcess)
   begin
      select top 1
          @lTargetDatabaseName = t.TargetDatabase
         ,@lTargetSchemaName = t.TargetSchema
         ,@lTargetTableName = t.TargetTable
         ,@lProcessMode = t.ProcessMode
      from #tablesToProcess t

      begin try

         if @lProcessMode = 'Type-2'
         begin
            set @CurrentOperation = 'DiffTable: Target='+@lTargetDatabaseName+'.'+@lTargetSchemaName+'.'+@lTargetTableName
            set @Msg = 'Starting ' + @CurrentOperation
                     +', @Debug=' + isnull(convert(varchar,@Debug),'null')
            exec dbo.WriteLog @ProcName=@StoredProcName, @MessageText=@Msg, @Status='Calling DiffTable'

            exec dbo.DiffTable @TargetDatabaseName=@lTargetDatabaseName, @TargetSchemaName=@lTargetSchemaName, @TargetTableName = @lTargetTableName, @Debug = @Debug
         end
         if @lProcessMode = 'Type-1'
         begin
            set @CurrentOperation = 'SyncTable: Target='+@lTargetDatabaseName+'.'+@lTargetSchemaName+'.'+@lTargetTableName
            set @Msg = 'Starting ' + @CurrentOperation
                     +', @Debug=' + isnull(convert(varchar,@Debug),'null')
            exec dbo.WriteLog @ProcName=@StoredProcName, @MessageText=@Msg,@Status='Calling SyncTable'

            exec dbo.SyncTable @TargetDatabaseName=@lTargetDatabaseName, @TargetSchemaName=@lTargetSchemaName, @TargetTableName = @lTargetTableName, @Debug = @Debug
         end
         if @ProcessMode = 'Reconcile'
         begin
            set @CurrentOperation = 'ReconcileTable: Target='+@lTargetDatabaseName+'.'+@lTargetSchemaName+'.'+@lTargetTableName
            set @Msg = 'Starting ' + @CurrentOperation
                     +', @Debug=' + isnull(convert(varchar,@Debug),'null')
            exec dbo.WriteLog @ProcName=@StoredProcName, @MessageText=@Msg,@Status='Calling ReconcileTable'

            exec dbo.ReconcileTable @TargetDatabaseName=@lTargetDatabaseName, @TargetSchemaName=@lTargetSchemaName, @TargetTableName = @lTargetTableName, @Debug = @Debug
         end
      
      end try

      begin catch

         select @ErrorMessage = @ErrorMessage + cast(getdate() as varchar) + CHAR(13) + CHAR(10)
              + error_message() + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10)

         set @Msg = 'ERROR in '+ @CurrentOperation + '.  Review previous log entries for details.'

         exec dbo.WriteLog @ProcName=@StoredProcName, @Status='ERROR'
                          ,@MessageText=@Msg

         set @ErrorFlag = 1

      end catch

      delete from #tablesToProcess
      where TargetDatabase = @lTargetDatabaseName
         and TargetSchema = @lTargetSchemaName
         and TargetTable = @lTargetTableName

   end

   exec dbo.WriteLog @ProcName=@StoredProcName, @Status='Finished'

   if @ErrorFlag = 1
      raiserror (@ErrorMessage, 16, 1)

end
go
