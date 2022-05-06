	Declare @IndexName varchar(100)
	Declare @objectId varchar(100)
	Declare @TableName varchar(100)
	Declare @SchemaName varchar(100)
	Declare @ExecutionSyntax varchar(500)
	Declare @ExecutionType varchar(100)
	Declare @AvgFragmentation varchar(100)
 
    DECLARE index_cursor CURSOR FOR
       SELECT 'ALTER INDEX [' + ix.name + '] ON [' + s.name + '].[' + t.name + '] ' +
       CASE
              WHEN ps.avg_fragmentation_in_percent > 15			--破碎程度 判斷使用重組() 還是使用 重建()
              THEN 'REBUILD'									--重建
              ELSE 'REORGANIZE'									--重組
       END +
       CASE
              WHEN pc.partition_count > 1
              THEN ' PARTITION = ' + CAST(ps.partition_number AS nvarchar(MAX))
              ELSE ''
       END as ExecutionSyntax
	   ,avg_fragmentation_in_percent,
	   CASE
              WHEN ps.avg_fragmentation_in_percent > 15			--破碎程度 判斷使用重組() 還是使用 重建()
              THEN 'REBUILD'
              ELSE 'REORGANIZE'
       END as ExecutionType
	   ,ix.object_id as objectId
	   ,ix.name as IndexName 
	   ,t.name as TableName
	   ,s.name as SchemaName
		FROM   sys.indexes AS ix
			   INNER JOIN sys.tables t
			   ON     t.object_id = ix.object_id
			   INNER JOIN sys.schemas s
			   ON     t.schema_id = s.schema_id
			   INNER JOIN
					  (SELECT object_id                   ,
							  index_id                    ,
							  avg_fragmentation_in_percent,
							  partition_number
					  FROM    sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL, NULL, NULL)
					  ) ps
			   ON     t.object_id = ps.object_id
				  AND ix.index_id = ps.index_id
			   INNER JOIN
					  (SELECT  object_id,
							   index_id ,
							   COUNT(DISTINCT partition_number) AS partition_count
					  FROM     sys.partitions
					  GROUP BY object_id,
							   index_id
					  ) pc
			   ON     t.object_id              = pc.object_id
				  AND ix.index_id              = pc.index_id
		WHERE  ps.avg_fragmentation_in_percent > 10						--需要進行重組或重建的破碎程度 條件
		   AND ix.name IS NOT NULL
 
    OPEN index_cursor
    FETCH NEXT FROM index_cursor INTO @ExecutionSyntax,@AvgFragmentation,@ExecutionType,@objectId,@IndexName,@TableName,@SchemaName
    WHILE @@FETCH_STATUS = 0
        Begin
			--重整資訊
    	    print '-- TableName: '+@TableName+' , IndexName: '+@IndexName+' , SchemaName: '+@SchemaName +' , AvgFragmentationInPercent: '+@AvgFragmentation+' , ExecutionType: '+@ExecutionType
			print '   ExecutionSyntax: '+@ExecutionSyntax
			exec(@ExecutionSyntax)
            FETCH NEXT FROM index_cursor INTO @ExecutionSyntax,@AvgFragmentation,@ExecutionType,@objectId,@IndexName,@TableName,@SchemaName 
        End
    CLOSE index_cursor
    DEALLOCATE index_cursor