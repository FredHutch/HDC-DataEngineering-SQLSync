-- make sure you're running this in the context of the database where the SyncConfig table lives

-- This is a template to configure a type-1 (non-deleting) table

declare @TargetDatabaseName varchar(128)
   , @TargetSchemaName varchar(128)
   , @TargetTableName varchar(128)


set @TargetDatabaseName = '--SET THIS VALUE'
set @TargetSchemaName = '-- SET THIS VALUE'
set @TargetTableName = '--SET THIS VALUE'


begin try
   begin tran
      delete from dbo.SyncConfig
      where TargetDatabase=@TargetDatabaseName
      and TargetSchema=@TargetSchemaName
      and TargetTable=@TargetTableName

      insert into dbo.SyncConfig
      (TargetDatabase
      ,TargetSchema
      ,TargetTable
      ,SourceDatabase
      ,SourceSchema
      ,SourceTable
      ,SourceUpdateDateColumn
      ,IsActive
      ,ProcessMode
      ,TableGroup
      ,PrimaryKeyColumns
      ,SurrogateTable
      ,SurrogateKeyColumn
      ,TargetActiveColumn
      ,TargetCreateDateColumn
      ,TargetUpdateDateColumn
      ,CleanUpSourceAfterRun
      ,ReconcileTable)
      select
         TargetDatabase=@TargetDatabase
         ,TargetSchema=@TargetSchema
         ,TargetTable=@TargetTable

         ,SourceDatabase='' --the name of the source database for this load
         ,SourceSchema='' --the name of the source schema for this load
         ,SourceTable='' --the name of the source table for this load. Can be a view

         ,SourceUpdateDateColumn=

         ,IsActive=1 --if set to 1, this table will be processed. When set to 0, it will be skipped/disabled
         ,ProcessMode='Type-1' --when set to 'Type-1', it will be a non-deleting copy
         ,TableGroup='' -- a table group is 

         --what is the primary key for this table? Please specify the column names
         ,PrimaryKeyColumns=N'<columns>
                                 <column name="FirstColumnNameHere!">
                                 <column name="SecondColumnNameHere!">
                                 <column name="ThirdColumnNameHere!">
                              </columns>' 

         -- SK information. The name of the SK mapping table, 
         -- and the column name used for SKs
         ,SurrogateTable=''
         ,SurrogateKeyColumn=''

         -- type-1 system columns. The name of the columns used for an active flag
         --, and an update-date column
         ,TargetActiveColumn='' -- a bit column
         ,TargetCreateDateColumn='' -- a datetiime column
         ,TargetUpdateDateColumn='' -- a datetime column

         -- cleanup, reconcile, and state information
         ,CleanUpSourceAfterRun='' --  1 or 0. If enabled, the sync procedures will delete sync'd data from the source after a successful run
         ,ReconcileTable='' --if specified, use this for reconciling the data


   commit tran
end try
begin catch
   if @@trancount>0
      rollback tran
end catch


