if object_id('dbo.WriteLog') is not NULL
BEGIN
    exec ('drop procedure dbo.WriteLog');
END
go

create procedure dbo.WriteLog
   @ProcName varchar(128)
   ,@ObjectName varchar(128)=null
   ,@Status varchar(400)=null
   ,@RowsAffected int=null
   ,@MessageText varchar(max)=null
as
begin

insert into dbo.HistoryLog
(LogTime
,ProcName
,ObjectName
,Status
,RowsAffected
,MessageText)
select
   getdate()
   ,@ProcName
   ,@ObjectName
   ,@Status
   ,@RowsAffected
   ,@MessageText


end
go