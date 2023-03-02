# 网站日志数据分析

## 需求分析
在如今互联网行业中，数据的收集特别是日志数据的收集已经成为了系统的标配。将用户行为日志或者线上系统生产的数据通过flume收集起来，存放到数据仓库（hive）中，然后离线通过sql进行统计分析，这一套数据流的建设对系统有非常重要的意义。
几乎任何规模的公司，每时每刻都在产生大量的数据，收集业务日志数据，供离线和在线的分析系统使用。处理这些日志需要特定的日志系统，一般而言，这些系统需要具有高可用性、高可靠性和可扩展性。
我们使用nginx对网站日志数据进行捕获。Nginx是一款轻量级的Web服务器、反向代理服务器，由于它的内存占用少，启动极快，高并发能力强，在互联网项目中广泛应用。Nginx是一款开源服务器软件，兼有HTTP服务器和反向代理服务器的功能。其主要特点在于高性能、高并发和低内存消耗。Nginx具有负载均衡、缓存、访问控制、带宽控制以及高效整合各种应用的能力，这些特性使得Nginx非常适合计算广告这种并发很高的互联网服务。*【2】
我们通过flume对捕获的日志数据进行传输。Flume是一个分布式、可靠的和高可用的海量日志采集，聚合和传输的系统。支持在系统中定制各类数据发送方，用于收集数据;同时，Flume 提供对数据进行简单处理，并写到各种数据接受方(可定制)的能力。Flume 初始的发行版本目前被统称为Flume OG(original generation) ，属于Cloudera.但随着Flume功能的扩展，Flume OG代码工程臃肿，核心组件设计不合理、核心配置不标准等缺点暴露出来，尤其是在Flume OG的最后一个发行版本0.94.0中，日志传输不稳定的现象尤为严重。为了解决这些问题，2011 年10月22日,Cloudera完成了Flume-728，对Flume进行了里程碑式的改动：重构核心组件、核心配置以及代码架构，重构后的版本统称为Flume NG (next generation) ;改动的另一原因是将Flume纳入Apache旗下，Cloudera Flume改名为Apache Flume。*【1】
此外，我们通过Hadoop打包好的jar包，其中主要包含MapReduce操作，对flume采集的数据进行清洗。HDFS是一种易于横向扩展的分布式文件系统，提供大规模数据文件存储服务，支持PB级数据规模。它可以运行在上万台的通用商业服务器集群上，提供副本容错机制，为海量用户提供性能优秀的存取服务。计算广告系统里的海量日志文件等就是通过Flume之类的数据高速公路传送，最终存储在HDFS上，为各种离线计算任务提供服务。Hadoop MapReduce是一种分布式计算框架，顾名思义，它由map和reduce两个部分组成。map是将一个作业分解成多个任务，而reduce是将分解后多任务处理的结果汇总起来。在程序设计中，一项工作往往可以被拆分成为多个任务，任务之间的关系可以分为两种：一种是不相关的任务，可以并行执行；另一种是任务之间有相互依赖，先后顺序不能够颠倒，这种任务是无法并行处理的。MapReduce适用于第一种类型，庞大的集群可以看作是硬件资源池，将任务并行拆分，然后交由每一个空闲硬件资源去处理，能够极大地提高计算效率，同时这种资源无关性对于计算集群的横向扩展提供了最好的设计保证。*【4】
最终将清洗后的完整而有效的数据导入hive中，建表储存。hive是基于Hadoop的一个数据仓库工具，用来进行数据提取、转化、加载，这是一种可以存储、查询和分析存储在Hadoop中的大规模数据的机制。hive数据仓库工具能将结构化的数据文件映射为一张数据库表，并提供SQL查询功能，能将SQL语句转变成MapReduce任务来执行。
本文综合nginx、flume、Hadoop、hive技术，最终实现网站日志数据的获取与保存。在后续可以将数据用于对用户的分析、对网站的改进和计算广告投放等实现计算机技术的变现。


## 概要设计
整个项目主要有四个部分：日志拆解、日志采集、日志清洗和建表储存。
日志拆解主要通过shell脚本，将离线的日志数据按照时间拆分。
日志采集是通过flume将拆分后的日志数据从日志目录中采集运输至hdfs中。
日志清洗是通过打包好MapReduce操作的jar包，直接使用命令对目录中日志文件进行清洗操作，指定日志目录和输出目录。
建表储存是在hive中建立结构化数据表，储存清洗后的数据。


## 实现过程
本项目主要实现过程如下
1）nginx将访问a.html、b.html、c.html产生日志数于目录：/home/hadoop/nginx/logs/access_*.log ；
2）将access_*.log中的日志数据通过shell拆解，使用定时器crontab定时执行shell拆解脚本并且使用时间命名；
3）使用flume采集目录：/home/hadoop/nginx/logs/access_*.log的日志文件到hdfs的储存目录，再通过shell移至工作目录；
4）使用打包好的MapReduce操作的jar包对日志数据进行清洗，最终汇总保存；
5）hive建立外表，读取flume收集到hdfs上的数据。



## 测试
### 1、nginx完成对网页的监控，捕获日志数据。

启动Nginx后，其实就是在80端口启动了Socket服务进行监听，如图所示，Nginx涉及Master进程和Worker进程。（这里的80端口是默认的，可能会存在端口被占用的情况，可以在.conf中改成比较少用的端口号。）
Master-Worker模式
Master进程读取并验证配置文件nginx.conf；管理worker进程；每一个Worker进程都维护一个线程（避免线程切换），处理连接和请求；注意Worker进程的个数由配置文件决定，一般和CPU个数相关（有利于进程切换），配置几个就有几个Worker进程。




### 2、将access_*.log中的日志数据通过shell拆解，使用定时器crontab定时执行shell拆解脚本并且使用时间命名；

计算机计算速度非常快而被人们加以使用，但计算速度再快的计算机，处理数据的能力也有一定限度，所以在处理大数据操作的时候，采用分治法可以有效的处理目前人类社会所遇到的大部分大数据问题。这里存在大量的日志访问数据，所以我们也采取分治法。
分治法的主要思想就是将一个复杂的问题分成两个或多个相同的子问题，子问题可以分成更小的子问题，直到子问题可以容易解决的时候，原问题的解就是子问题解的和。
为了实现日志数据自动采集，我们又使用定时器crontab定时执行shell拆解脚本并且使用时间命名。（nginx的目录中不允许出现相同的文件，使用时间相关命名最为方便。）
结果如下，拆分后获得多个日志数据文件：



### 3、使用flume采集目录：/home/hadoop/nginx/logs/access_*.log的日志文件到hdfs的储存目录，再通过shell移至工作目录；
Flume是一个分布式、可靠、和高可用的海量日志采集、聚合和传输的系统。它可以采集文件，socket数据包、文件、文件夹、kafka等各种形式源数据，又可以将采集到的数据 sink（下沉） 到HDFS、hbase、hive、kafka等众多外部存储系统中。

### Flume架构中的组件：
#### Agent本质上是一个 JVM 进程，该JVM进程控制Event数据流从外部日志生产者那里传输到目的地(或者是下一个Agent)。一个完整的Agent中包含了三个组件Source、Channel和Sink，Source是指数据的来源和方式，Channel是一个数据的缓冲池，Sink定义了数据输出的方式和目的地。
#### Source是负责接收数据到Flume Agent的组件。Source组件可以处理各种类型、各种格式的日志数据，包括avro、exec、spooldir、netcat等。
#### Channel是位于Source和Sink之间的缓冲区。Channel允许Source和Sink运作在不同的速率上。Channel是线程安全的，可以同时处理多个Source的写入操作及多个Sink的读取操作。常用的Channel包括：oMemory Channel是内存中的队列。Memory Channel在允许数据丢失的情景下适用。如果不允许数据丢失，应该避免使用Memory Channel，因为程序死亡、机器宕机或者重启都可能会导致数据丢失。
oFile Channel将所有事件写到磁盘。因此在程序关闭或机器宕机的情况下不会丢失数据。
#### Sink
不断地轮询Channel中的事件且批量地移除它们，并将这些事件批量写入到存储或索引系统、或者被发送到另一个Flume Agent。oSink是完全事务性的。在从Channel批量删除数据之前，每个Sink用Channel启动一个事务。批量事件一旦成功写出到存储系统或下一个Flume Agent，Sink就利用Channel提交事务。事务一旦被提交，该Channel从自己的内部缓冲区删除事件。
oSink组件包括hdfs、logger、avro、file、null、HBase、消息队列等。
####Event是Flume定义的一个数据流传输的最小单位。
我们设定的是Memory channel和hdfs,代码如下:
```
agent1.sources = source1
agent1.sinks = sink1
agent1.channels = channel1
```
监控一个目录下的多个文件新增的内容
`agent1.sources.source1.type = TAILDIR`
通过 json 格式存下每个文件消费的偏移量，避免从头消费
```
agent1.sources.source1.positionFile = /home/hadoop/taildir_position.json
agent1.sources.source1.filegroups = f1
agent1.sources.source1.filegroups.f1 = /home/hadoop/nginx/logs/access_*.log

agent1.sources.source1.interceptors = i1
agent1.sources.source1.interceptors.i1.type = host
agent1.sources.source1.interceptors.i1.hostHeader = hostname
```
配置sink组件为hdfs
```
agent1.sinks.sink1.type = hdfs
agent1.sinks.sink1.hdfs.path=hdfs://localhost:8020/weblog/flume-collection/%Y-%m-%d/%H-%M_%{hostname}
```
#指定文件名前缀
`agent1.sinks.sink1.hdfs.filePrefix = access_log`
指定每批下沉数据的记录条数
``
`agent1.sinks.sink1.hdfs.batchSize= 100
agent1.sinks.sink1.hdfs.fileType = DataStream
agent1.sinks.sink1.hdfs.writeFormat =Text
```
指定下沉文件按1MB大小滚动
`agent1.sinks.sink1.hdfs.rollSize = 1048576`
指定下沉文件按1000000条数滚动
`agent1.sinks.sink1.hdfs.rollCount = 1000000`
指定下沉文件按30分钟滚动
```
agent1.sinks.sink1.hdfs.rollInterval = 30
#agent1.sinks.sink1.hdfs.round = true
#agent1.sinks.sink1.hdfs.roundValue = 10
#agent1.sinks.sink1.hdfs.roundUnit = minute
agent1.sinks.sink1.hdfs.useLocalTimeStamp = true
```
使用memory类型channel
```
agent1.channels.channel1.type = memory
agent1.channels.channel1.capacity = 500000
agent1.channels.channel1.transactionCapacity = 600

//Bind the source and sink to the channel
agent1.sources.source1.channels = channel1
agent1.sinks.sink1.channel = channel1
```

启动flume的时候指定需要采集的nginx目录和存储目录即可。
结果如下：

Flume采集到hdfs
在采集到hdfs的存储目录之后，再使用shell脚本转移到操作目录，以便于后续的数据清理。（这个项目中所有的操作几乎都是shell脚本或者代码完成，这样便于后续整合到一个大脚本中，进行自动的网站实时数据采集，而不需要人工手动执行每一个shell脚本。）

4、使用打包好的MapReduce操作的jar包对日志数据进行清洗（ETL），最终汇总保存；
“ETL，是英文 Extract-Transform-Load 的缩写，用来描述将数据从来源端经过抽取（Extract）、转换（Transform）、加载（Load）至目的端的过程。ETL 一词较常用在数据仓库，但其对象并不限于数据仓库。
在运行核心业务 MapReduce 程序之前，往往要先对数据进行清洗，清理掉不符合用户要求的数据。清理的过程往往只需要运行 Mapper 程序，不需要运行 Reduce 程序。
数据清洗（Data Cleaning）原理即通过分析“脏数据”的产生原因和存在形式，利用现有的技术手段和方法去清洗“脏数据”,将原有的不符合要求的数据转化为满足数据质量或应用要求的数据，从而提高数据集的数据质量。
数据清洗(Data cleaning)– 对数据进行重新审查和校验的过程，目的在于删除重复信息、纠正存在的错误，并提供数据一致性。

### 清洗规则：
1、进行判断， 如果 时间是：time_local或者 时间等于null
2、数组长度大于12，说明最后一个字段切出来比较长，把所有多的数据都塞到最后一个字段里面去
3、如果请求状态码大于400值，就认为是请求出错了，请求出错的数据直接认为是无效数据
4、如果获取时间没拿到，那么也是认为是无效的数据

清洗后的结果：


## 5）hive建立外表，读取flume收集到hdfs上的数据。
Hive是基于Hadoop的一个数据仓库工具，可以将结构化的数据文件映射为一张数据库表，并提供简单的sql查询功能，可以将sql语句转换为MapReduce任务进行运行。
建表如下：
```
drop table ods_weblog_detail;
create table ods_weblog_detail0610(
valid           string, --有效标识
remote_addr     string, --来源IP
remote_user     string, --用户标识
time_local      string, --访问完整时间
daystr          string, --访问日期
timestr         string, --访问时间
month           string, --访问月
day             string, --访问日
hour            string, --访问时
request         string, --请求的url
status          string, --响应码
body_bytes_sent string, --传输字节数
http_referer    string, --来源url
ref_host        string, --来源的host
ref_path        string, --来源的路径
ref_query       string, --来源参数query
ref_query_id    string, --来源参数query的值
http_user_agent string --客户终端标识
)
partitioned by(datestr string);
```
在建表之后，将清洗完成的数据导入，即完成了日志数据的存储。
这里使用hive的原因在于，方便后续的网站日志数据的使用。Hive是管理,读和写数据的工具。说简单了就是用SQL分析数据。Hive只能处理结构化数据,处理hadoop里面的数据,而网站日志数据恰好又是结构化数据。Hive能分析结构化的数据,Hive是坐落在hadoop之上的(使用hive前提是必须要安装了hadoop),用来分析大数据的,可以让查询和分析更简单。


## 五、总结
在这次实时网站数据采集项目中，了解了web服务器nginx如何监听web服务器、数据采集工具flume对日志数据进行采集聚合和下沉到hdfs中、计算框架MapReduce打包jar包进行数据清洗和在数据仓库hive中建表储存。通过这些技术的综合，完成了这次网站数据采集存储。
在完成的过程中也遇到过许多问题，比如nginx的端口被占用，flume传输日志数据失败，jar包清洗数据后就一条不剩了，以及各种大大小小的问题。最大最大的问题，我觉得是在于最初的配置，这是代表从理论走向实践的第一步，从无到有的第一步。它要求的不仅仅是输入几条命令，系统就能嘟嘟嘟地自己安装好，然后等你来宠幸就行了。它需要的是极强的实践能力-导入压缩包一步一步往前走、毫不畏惧的勇气与毅力-你要准备面对一切材料就绪，在安装的瞬间又一次次跳红（版本不符合，或者和其他组件版本不符合，内存不足以及各种从没见过的问题）、高超的数据检索能力-各种爆红会锻炼出你对搜索引擎的熟练使用，从最初的百度搜狗到后面的谷歌或者稀土掘金博客园等技术博客网站，甚至直接上官网。这也正是这次实训的意义，真正在实践中锻炼代码编写能力。
在这次实践中拓展，我们也发现了许多更有意思的东西。
Nginx不仅仅可以监控网站访问日志数据。Nginx 是一种轻量级的占用内存少、启动速度快、并发能力强的web服务器，设计思想是事件驱动的异步非阻塞处理（类node.js）。Nginx主要有4大应用：动静分离、反向代理、负载均衡、正向代理。不仅仅可以返回日志数据，这是一个极其优秀的服务器管理工具，从动静分离告诉返回用户数据到反向代理保障服务器安全实现负载均衡。
Apache Flume 是一个分布式，可靠且可用的系统，用于有效地从许多不同的源收集、聚合和移动大量日志数据到一个集中式的数据存储区。Flume 的使用不只限于日志数据。因为数据源可以定制，flume 可以被用来传输大量事件数据，这些数据不仅仅包括网络通讯数据、社交媒体产生的数据、电子邮件信息等等。
MapReduce和hive成名已久，就不一一介绍了。
假如对这个项目深入，可以对网络广告投放进行优化：通过获取各个广告服务器的日志数据，找到某个网站、某些人群、某个时间段最适合投放的广告内容。或者对商品的进行推送优化。
或者换个方向，可以对用户输入内容进行传输保存，最终进行分析。用于防止一些敏感性话题的讨论（莫谈国事），或者一些恐怖主义的防止。

