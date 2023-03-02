agent1.sources = source1
agent1.sinks = sink1
agent1.channels = channel1
#监控一个目录下的多个文件新增的内容
agent1.sources.source1.type = TAILDIR
#通过 json 格式存下每个文件消费的偏移量，避免从头消费
agent1.sources.source1.positionFile = /home/hadoop/taildir_position.json
agent1.sources.source1.filegroups = f1
agent1.sources.source1.filegroups.f1 = /home/hadoop/nginx/logs/access_*.log

agent1.sources.source1.interceptors = i1
agent1.sources.source1.interceptors.i1.type = host
agent1.sources.source1.interceptors.i1.hostHeader = hostname
#配置sink组件为hdfs
agent1.sinks.sink1.type = hdfs
agent1.sinks.sink1.hdfs.path=hdfs://localhost:8020/weblog/flume-collection/%Y-%m-%d/%H-%M_%{hostname}
#指定文件名前缀
agent1.sinks.sink1.hdfs.filePrefix = access_log
#指定每批下沉数据的记录条数
agent1.sinks.sink1.hdfs.batchSize= 100
agent1.sinks.sink1.hdfs.fileType = DataStream
agent1.sinks.sink1.hdfs.writeFormat =Text
#指定下沉文件按1MB大小滚动
agent1.sinks.sink1.hdfs.rollSize = 1048576
#指定下沉文件按1000000条数滚动
agent1.sinks.sink1.hdfs.rollCount = 1000000
#指定下沉文件按30分钟滚动
agent1.sinks.sink1.hdfs.rollInterval = 30
#agent1.sinks.sink1.hdfs.round = true
#agent1.sinks.sink1.hdfs.roundValue = 10
#agent1.sinks.sink1.hdfs.roundUnit = minute
agent1.sinks.sink1.hdfs.useLocalTimeStamp = true

#使用memory类型channel
agent1.channels.channel1.type = memory
agent1.channels.channel1.capacity = 500000
agent1.channels.channel1.transactionCapacity = 600

# Bind the source and sink to the channel
agent1.sources.source1.channels = channel1
agent1.sinks.sink1.channel = channel1
