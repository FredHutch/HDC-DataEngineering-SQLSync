if object_id('dbo.HistoryLog') is not NULL
BEGIN
    exec ('drop table dbo.HistoryLog');
END
go

create table dbo.HistoryLog
(HistoryLogID bigint not null identity(1,1)
,LogTime datetime not null default(getdate())
,ProcName varchar(128) not null
,ObjectName varchar(256) null
,Status varchar(400) null
,RowsAffected int null
,MessageText varchar(max) null
,constraint HistoryLogPK primary key clustered (HistoryLogID)
) with (data_compression = row)
go
