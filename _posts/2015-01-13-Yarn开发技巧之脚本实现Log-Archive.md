---
layout: post
title: Yarn开发技巧之脚本实现Log Archive
---

学习开发Yarn，在最初阶段会遇到一个较为陡峭的学习曲线。造成的这个的原因除了项目本身的复杂程度以外，还有不同于以往的调试方法会让人产生不适应。在以前，我从没有注意过任何的调试技巧，基本上都是断点啊，单步啊之类的，但是到了这次调试Hadoop这样大的项目才发觉原来的简单调试方法不给力了。

本文将会涉及：

+ 设置Hadoop的调试级别
+ 将每一次的日志记录保存在不同的文件中，形成一个Log Archive

##&#9824;&nbsp;&nbsp;调整日至级别

调试Yarn，我采用的方式是开启<a href="http://logging.apache.org/log4j/2.x/">Apache Log4j</a>的DEBUG级别，这一工具在大型项目中具有很广泛的应用。如果我们需要打开Hadoop相关组件的DEBUG级别，获得调试输出。有一下三种途径：

- 使用Hadoop Shell命令

查看当前的组件日志级别，以ResourceManager为例
<pre><code class="BASH">/opt/yarn/hadoop-2.6.0/bin$ ./hadoop daemonlog -getlevel localhost:8042 org.apache.hadoop.yarn.server.resourcemanager
</code></pre>
以上的代码会显示resourcemanager组件的整体日志级别，你也可以后面添上类名而查询更细粒度的日志级别。
注意，我的开发环境是Single-Node的配置，所以上面用了localhost，如果在真实集群中，需要使用<span style="background-color: #084B8A"><font color="white">${nodemanager-host}</font></span>，下同


- 使用Web界面修改和查看

前往如下地址
<pre><code class="BASH">localhost:8042/logLevel</code></pre>

使用以上两种方式获的效果是单次的，在Hadoop重启后将失效。

<!--more-->


- 直接修改log4j的配置文件

通过这种方式获得的效果是持久的。配置文件的具体位置在：<span style="background-color: #084B8A"><font color="white">${HADOOP_HOME}／etc/hadoop/log4j.properties</font></span>, 其中需要配置的语句是

<pre><code class="BASH">hadoop.root.logger=INFO,console</code></pre>

如果将这里的INFO修改成为DEBUG，全局的调试信息都可以看到。当然过多的调试信息有时候也会让你迷惑，因此你会需要更加细粒度的控制，通过修改/添加一下的语句：

<pre><code class="Bash">log4j.logger.org.apache.hadoop.yarn.server.resourcemanager=DEBUG,console
log4j.logger.org.apache.hadoop.yarn.server.nodemanager=DEBUG,console
log4j.logger.org.apache.hadoop.yarn.server.api.impl.pb.service=DEBUG,console
log4j.logger.org.apache.hadoop.yarn.server.api.impl.pb.client=DEBUG,console
</code></pre>

通过将具体的类或者包添加进来，我开启了（如上）：nodemanager, resourcemanager, ipc 相关类的DEBUG级别。你可以设置更过的具体类/包进来。


##&#9824;&nbsp;&nbsp;编写脚本实现Log Archive

在开发过程中让人比较头疼的是，每次修改完代码，`mvn package`重新启动集群后，`resourcemanager` 和`nodemanager`的日志会继续续着之前的往下写，这样非常不利于发现当次的修改对集群产生了那些变化，因此这也带来了我的需求。我希望每一次集群运行的日志会单独保存在一个文件内，`One Log to One Run` 是我想达到的效果，这样检查每一次的修改会方便和准确很多。实现的方式可以通过添加JAVA代码扩展log4j的某些类，重写某些函数来做，稍显麻烦，而且我也不像过多的改动源代码。所以采用脚本的方式，在每次启动和关闭集群的时候对日志进行处理。

基本效果有：

1. 关闭集群时，将该次日志内容保存到<span style="background-color: #084B8A"><font color="white">${HADOOP_LOG_DIR}/xx_log_archive</font></span>中，并且自动生成version号码
2. 开启集群时，清空上次的相关日志内容。

脚本全文可以在这里<a href="https://gist.github.com/legatoo/bf8bca91ad6886512500">下载</a>，下面对其中几个地方做一解释，也方便自己回顾学习。

- 【获得脚本的当前执行目录】

在hadoop的原脚本中也可以看到类似的语句，如下：

<pre><code class="Bash">bin=`dirname "${BASH_SOURCE-$0}"`
bin=`cd "$bin"; pwd`
</code></pre>

这里涉及到的知识点有：

+ <a href="http://tldp.org/LDP/abs/html/parameter-substitution.html">Parameter Substitution</a>
+ <a href="http://www.gnu.org/software/bash/manual/html_node/Bash-Variables.html">什么是BASH_SOURCE</a>
+ <a href="http://unix.stackexchange.com/a/46856/64917">Login Shell and Non-Login Shell</a>
+ <a href="http://stackoverflow.com/a/246128/1285444">Find which location this script is stored</a>


- 【保存日志并自动编号】

相关代码如下：

<pre><code class="Bash">echo "----------------------Moving logs to log archive-----------------------"
# Copy RM log of last run to rm log archive
if [ -f "$rm_logfile_name" ]; then
    #echo "Original log file is exist."
    #Moving log content to defined directory
    if [ -d "$rm_logfile_location" ]; then
        #echo "User defined rm log directory is exist."
        if [[ -n $(find $rm_logfile_location -maxdepth 0 -empty) ]]; then
            firstRunLogName="$rm_log_basename"'001.log'
            #echo "First run, log name is: ", $firstRunLogName
            cat "$rm_logfile_name" > "$rm_logfile_location"/"$firstRunLogName"
            echo "Writing log to", $firstRunLogName
        else
            # echo "Directory is not empty."
            file=`ls "$rm_logfile_location"|sort -g -r|head -n1`
            lastRunLogFullName=$(basename $file)
            extension=${lastRunLogFullName##*.}
            lastRunFileName=${lastRunLogFullName%.*}
            IFS='-' read -ra ARRAY <<<  "$lastRunFileName"
            preVersion=${ARRAY[@]:(-1)}

            # Remove leading zero
            preVersionToDigital=${preVersion#0}

            # Convert to base-10, and do add operation
            ((newVersion=10#$preVersionToDigital+1));

            # Add leading zero
            padding_newVersion=$(printf "%03d" $newVersion)
            newLogFileName="$rm_log_basename""$padding_newVersion"'.'"$extension"
            cat "$rm_logfile_name" > "$rm_logfile_location"/"$newLogFileName"
            echo "Writing log to", $newLogFileName
        fi
    fi
fi
</code></pre>

这里涉及到的知识点有圆括号和花括号的区别（可能很基础，但是深入理解内容却很多），所以<a href="http://ss64.com/bash/syntax-brackets.html">这里</a>是关于不同括号的效果，当把一串命令由圆括号包裹起来时，这些命令将交由SubShell来完成，SubShell拥有原Shell的数据拷贝，但是不能修改原数据，<a href="http://unix.stackexchange.com/a/138498/64917">Gilles回答</a>了一下有关SubShell的有关内容。

还有在脚本中我使用了<span style="background-color: #084B8A"><font color="white"> [[ </font></span>和<span style="background-color: #084B8A"><font color="white"> [ </font></span>，两种用来做条件判断的句式。其中单个<span style="background-color: #084B8A"><font color="white"> [ </font></span>是bash builtin，会顺次读取其中的语句，以空格隔开，倘若一个变量中拥有空格，但是没有用双引号扩起来，那么<span style="background-color: #084B8A"><font color="white"> [ </font></span>读入后可能就会被错误解析。而<span style="background-color: #084B8A"><font color="white"> [[ </font></span>是一个keyword，具有更好的解析能力，详细请见<a href="http://mywiki.wooledge.org/BashGuide/TestsAndConditionals#Conditional_Blocks_.28if.2C_test_and_.5B.5B.29">这里</a>.

最后会在脚本中发现几段自动编号的代码，其中需要注意的是String转数字并且在加一的操作。之前没有注意，遇到的问题是在<span style="background-color: #084B8A"><font color="white">008</font></span>之后就出现<span style="background-color: #084B8A"><font color="white">value too great for base</font></span>这样的错误，也就是不能到009去了。我第一次遇到这样的问题，原因如下。

> Numerical values starting with a zero (0) are interpreted as numbers in octal notation by the C language. As the only digits allowed in octal are {0..7}, an 8 or a 9 will cause the evaluation to fail


因此需要先去头部0，转换位十进制，然后做加法，然后填头部零。Bash真的好神奇。


Sincerely,<br>
<a href="https://twitter.com/stevenyfy"><font color="green">@stevenyfy</font></a>


<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.
