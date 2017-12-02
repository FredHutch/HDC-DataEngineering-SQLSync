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
   declare @lTargetDatabaseName varchar(128)
      ,@lTargetSchemaName varchar(128)
      ,@lTargetTableName varchar(128)
      ,@lProcessMode varchar(32)
      ,@Msg varchar(max)

/*
This sproc iterates over table, syncing, diffing, or reconciling them one at a time

Order of operations:
- Load the tables to process into a temp table
- Using a while loop, call either Diff, Sync, or Reconcile
*/
  
   set @Msg = 'Starting ProcessTables, filters:'
                +' @TargetDatabase=' + isnull(@TargetDatabaseName,'null')
                +', @TargetTable=' + isnull(@TargetTableName,'null')
                +', @SourceDatabase Name=' + isnull(@SourceDatabaseName,'null')
                +', @SourceTableName=' + isnull(@SourceTableName,'null')
                +', @ProcessMode=' + isnull(@ProcessMode,'null')
                +', @TableGroup=' + isnull(@TableGroup,'null')
                +', @Debug=' + isnull(convert(varchar,@Debug),'null')
   exec dbo.WriteLog @ProcName='ProcessTables',@MessageText=@Msg, @Status='Starting'

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

      if @lProcessMode = 'Type-2'
      begin
         set @Msg = 'Starting dbo.DiffTable: Target='
                  +@lTargetDatabaseName+'.'+@lTargetSchemaName+'.'+@lTargetTableName
                  +', @Debug=' + isnull(convert(varchar,@Debug),'null')
         exec dbo.WriteLog @ProcName='ProcessTables',@MessageText=@Msg, @Status='Calling DiffTable'

         exec dbo.DiffTable @TargetDatabaseName=@lTargetDatabaseName, @TargetSchemaName=@lTargetSchemaName, @TargetTableName = @lTargetTableName, @Debug = @Debug
      end
      if @lProcessMode = 'Type-1'
      begin
         set @Msg = 'Starting dbo.SyncTable: Target='
                  +@lTargetDatabaseName+'.'+@lTargetSchemaName+'.'+@lTargetTableName
                  +', @Debug=' + isnull(convert(varchar,@Debug),'null')
         exec dbo.WriteLog @ProcName='ProcessTables',@MessageText=@Msg,@Status='Calling SyncTable'

         exec dbo.SyncTable @TargetDatabaseName=@lTargetDatabaseName, @TargetSchemaName=@lTargetSchemaName, @TargetTableName = @lTargetTableName, @Debug = @Debug
      end
      if @ProcessMode = 'Reconcile'
      begin
         set @Msg = 'Starting dbo.ReconcileTable: Target='
                  +@lTargetDatabaseName+'.'+@lTargetSchemaName+'.'+@lTargetTableName
                  +', @Debug=' + isnull(convert(varchar,@Debug),'null')
         exec dbo.WriteLog @ProcName='ProcessTables',@MessageText=@Msg,@Status='Calling ReconcileTable'

         exec dbo.ReconcileTable @TargetDatabaseName=@lTargetDatabaseName, @TargetSchemaName=@lTargetSchemaName, @TargetTableName = @lTargetTableName, @Debug = @Debug
      end

     delete from #tablesToProcess
     where TargetDatabase = @lTargetDatabaseName
       and TargetSchema = @lTargetSchemaName
       and TargetTable = @lTargetTableName
   end
end
go
