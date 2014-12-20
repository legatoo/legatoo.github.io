---
layout: post
title: Install Yarn on Ubuntu Cluster via Scripts
---

Few months ago, I took a class about Cloud Computing, which is the very first time I have chance to know Hadoop. Cloud Computing sounds beautiful, but in order to build this magic cloud, hard works have to be done. When I was doing course project for that class, I felt extremely boring and tired to login every node and configure something (I didn't realize I can use some tools to simplify the work). It is this reason that pushes me to find another way to build the cloud.

Fortunately, a very good book: [Apache Hadoop Yarn](http://yarn-book.com/) shows me the pain-less way. In *Chapter 2*, the book offers <span itemprop="articleSection">a script-based method to install Yarn</span> on nodes which is elegant and concise. The code provided by this book is available to [download](http://clustermonkey.net/download/Apache_Hadoop_YARN/). These code works only on CentOS. However, I am familiar and also a fan of Ubuntu, so, the work I'v done to make it works with Ubuntu forms today's post.

Before the content, I would like to quote from *Optimizing LInux Performance* by *Phillip G. Ezolt*:

>Avoid repeating the work of others.
>
>Avoid repeating your own work.

##<a name="section1" color="black"><font color="black">&#9824;&nbsp;&nbsp;Before Run the Scripts</font></a>

###1. Install Java
Jave should be installed in every node in your cluster for Yarn to work. If you are using Ubuntu 14.04 just like me, the code below will install java for you. [More about install java](http://www.webupd8.org/2012/01/install-oracle-java-jdk-7-in-ubuntu-via.html)

<pre><code class="Bash">sudo add-apt-repository ppa:webupd8team/java
sudo apt-get update
sudo apt-get install oracle-java7-installer
</code></pre>

###2. Install XML Parser
Script will automatically generate configuration XMLs for you. In order for this feature to work, *LibXml2* library has to be installed.
<pre><code class="Bash">sudo apt-get install libxml2-utils
</code></pre>

###3. Create User and Group for Using Yarn
I create a default user for using Yarn across cluster: `ynuser` who is belong to group `yarn`.
>You can add more users to specify how you use yarn. Like one user for using mapreduce, one user for spark etc. It's all depends on you, but remember to modify corresponding part of script to satisfy your demand.

<pre><code class="Bash">sudo addgroup yarn
sudo adduser —ingroup yarn ynuser</code></pre>

*After this, switch to account `ynuser`.*

###4. Install Parallel Distributed Shell: Pdsh
[Pdsh](https://code.google.com/p/pdsh/) is an amazing tool helps you execute command through the nodes connected by `pdsh`. The script highly depends on this tool and `pdcp` which included in the tool kit too. Before you run the actual script, please setup *pdsh* correctly.

<pre><code class="Bash">sudo apt-get install pdsh
</code></pre>

When `pdsh` is installed, some configurations still need to do. First is  to change default `Remote Command Service (RCMD)` to `ssh`, since by default `pdsh` uses linux `rcmd` to execute command on a remote client but not `ssh`.

<pre><code class="Bash">echo 'ssh' > /etc/pdsh/rcmd_default</code></pre>

This will save you for typing `-R ssh` in `pdsh` & `pdcp` every time. After change protocol to `ssh`, next we set up *passwd-less* connections between nodes for not only `pdsh`, but also `Yarn`.

put `IP address:hostname` in you hosts file.
<pre><code class="Bash">sudo vim /etc/hosts
should look like this
127.0.0.1	localhost
IP address	node1
IP address	node2
IP address  node3
....</code></pre>

generate ssh-key and distribute.

<pre><code class="Bash">#log in as ynuser

ssh-keygen -t rsa
#key will be generated in ~/.ssh/ directory

ssh-copy-id -i ~/.ssh/id_rsa.pub hostnasme
#hostname means the node you want to login
#do ssh-copy-id on every node you want to connect
</code></pre>

Do `ssh ynuser@hostname` to verify your ssh setting is correct.

using the command below to test pdsh

<pre><code class="Bash">pdsh -w node1,node2,... uptime
#note: no space(s) between hostnames
</code></pre>

the output will look like this:

<pre><code class="Bash">ynuser@student73:/etc/pdsh$ pdsh -a uptime
student74:  05:37:06 up 1 day,  4:23,  1 user,  load average: 1.10, 1.19, 1.22
student75:  05:37:06 up 1 day,  4:23,  1 user,  load average: 1.34, 1.19, 1.16
student73:  05:37:06 up 1 day,  4:22,  1 user,  load average: 1.11, 1.15, 1.19
</code></pre>

since I configured hostname in my `gender` file[/etc/genders], I can use `-a` to let pdsh resolve the hosts automatically. Check [this](https://computing.llnl.gov/linux/genders.html) for more.

###5. Grant Permission to Yarn User
Some operstions in the scripts require more privileges. In order to eliminate input passowrd again and again in the install progress. (Actually, `pdsh` doesn't redirect input from remote node, which makes it impossible to input password for remote node.)  We need to grant super privileges: sudo operations without password, for `ynuser` on every node. You can simply change it back after installation.

<pre><code class="Bash">sudo vim /etc/sudoers
</code></pre>

and add this line at the end of it

<pre><code class="Bash">ynuser  ALL=(ALL) NOPASSWD:ALL
</code></pre>

Now you don't need to input password for `sudo` operations. Oui~

Beside this, some files we are going to modify are belong to `root` account and can not modify without permission. So, we add `ynuser` to `root` group and grant group write permission:

<pre><code class="Bash">sudo usermod -a -G root ynuser
sudo chmod -R ug+wx /etc/init.d
#startup scripts will be put here, and started with OS boot
sudo chmod -R ug+wx /opt
</code></pre>

###6. Install sysv-rc-conf
This tool is a replacement for `chkconfig` in CentOS. [More Info](http://manpages.ubuntu.com/manpages/dapper/man8/sysv-rc-conf.8.html)

<pre><code class="Bash">sudo apt-get install sysv-rc-conf
</code></pre>

###7. Download Hadoop pre-build Tarball

Download Hadoop from [here](http://hadoop.apache.org/releases.html#Download), and put in the *same* directory with scripts.

##<a name="section2" color="black"><font color="black">&#9824;&nbsp;&nbsp;How It Works</font></a>
This part explains some importants of script.

###1. Copy Hadoop Tarball to All Nodes, and Extract
<pre><code class="Bash">if [ ! -f /opt/hadoop-"$HADOOP_VERSION".tar.gz ]; then
    echo "Copying Hadoop $HADOOP_VERSION to all hosts..."
    pdcp -w ^all_hosts hadoop-"$HADOOP_VERSION".tar.gz /opt
else
    echo "Hadoop $HADOOP_VERSION is there already to be extracted."
fi

pdsh -w ^all_hosts tar -zxf /opt/hadoop-"$HADOOP_VERSION".tar.gz -C /opt</code></pre>

###2. Set Hadoop Version
At the beginning of this script, `HADOOP_VERSION` can be changed according to your Hadoop version. I tested with *Hadoop 2.5.1*.

<pre><code class="Bash">HADOOP_VERSION=2.5.1
</code></pre>

###3. Set JAVA_HOME Location
<pre><code class="Bash">JAVA_HOME=/usr/lib/jvm/java-7-oracle/
</code></pre>

###4. Define Your Cluster Topo
You can define cluster topo in files. Yarn Install Script will read them in, and confingure the cluster as you wish. THe meaning of each files are listed below.

*  *nn_host*: HDFS Namenode hostname
*  *rm_host*: YARN ResourceManager hostname
*  *snn_host*: HDFS SecondNameNode hostname
*  *mr_history_host*: MapReduce Job History server hostname
*  *yarn_proxy_host*: YARN Web Proxy hostname
*  *nm_hosts*:  YARN NodeManager hostnames
*  *dn_hosts*:  HDFS DataNode hostnames

> <font color="Red">Note: </font>all hostanmes in these files are separated by ONE space

###5. Distribute Bash Startup Files
In order to let Yarn running when your cluster starts up. Some environent variable should be `export`. There are multiple places can do this: <span style="background-color: #23241f"><font color="white">~/.bash_profile</font></span>, <span style="background-color: #23241f"><font color="white">~/.bashrc</font></span>, <span style="background-color: #23241f"><font color="white">/etc/profile</font></span>, and scripts in <span style="background-color: #23241f"><font color="white">/etc/profile.d</font></span>. First two are user-specific, and last two are global. But there are differences between last two places, the scripts in `/etc/profile.d/` are application-specific startup scripts, and it helps you organize system in modules which is much easy in terms of maintenance, see [more](http://unix.stackexchange.com/questions/64258/what-do-the-scripts-in-etc-profile-d-do).  So, we put the script in `/etc/profile.d`

<pre><code class="Bash">pdsh -w ^all_hosts  echo "export JAVA_HOME=$JAVA_HOME > /etc/profile.d/java.sh"
pdsh -w ^all_hosts  echo "export HADOOP_HOME=$HADOOP_HOME > /etc/profile.d/hadoop.sh"
pdsh -w ^all_hosts  echo "export HADOOP_PREFIX=$HADOOP_HOME >> /etc/profile.d/hadoop.sh"
pdsh -w ^all_hosts  echo "export HADOOP_CONF_DIR=$HADOOP_CONF_DIR >> /etc/profile.d/hadoop.sh"</code></pre>

###6. Create Directories Across Cluster for Yarn
You can see these directories in the beginning of script:

<pre><code class="Bash">NN_DATA_DIR=/var/data/hadoop/hdfs/nn
SNN_DATA_DIR=/var/data/hadoop/hdfs/snn
DN_DATA_DIR=/var/data/hadoop/hdfs/dn
YARN_LOG_DIR=/var/log/hadoop/yarn
HADOOP_LOG_DIR=/var/log/hadoop/hdfs
HADOOP_MAPRED_LOG_DIR=/var/log/hadoop/mapred
YARN_PID_DIR=/var/run/hadoop/yarn
HADOOP_PID_DIR=/var/run/hadoop/hdfs
HADOOP_MAPRED_PID_DIR=/var/run/hadoop/mapred</code></pre>


And scripts will `mkdir` for every line above. Because we'v set `sudo-passwd-less` before, the operations now are executed without password.

###7. Generate XML Configuration Files

Hadoop is configured by some XML files which indicates different attributes of Hadoop components. The Script will help you to generate these files automatically. Also, feel free to remove/add attributes by youself. The command to add one new attribute in XML file is very easy and intuitive. E.g, for create `core-site.xml` and put `namenode` location, simply do this:

<pre><code class="Bash">create_config --file core-site.xml
put_config --file core-site.xml --property fs.defaultFS --value "hdfs://$nn:9000"</code></pre>

These XML files will be copied to all nodes.

###8. <a name="format_namenode"><font color="black">Format Namenode</font></a>

The Namenode will be formated during installation. Please noted here assumes you have no HDFS exists, meaning `DN_DATA_DIR=/var/data/hadoop/hdfs/dn` should be empty, Otherwise, execute `uninstall_hadoop.sh` first.  <a href="#uninstall"><font color="red">Check how to use uninstall at the end this article</font></a>.

>If there is HDFS filesystem exists, we suppose to have the prompt asking for command (Y/N) about if we want to re-format, but according to my test, pdsh can't redirect input to remote node, so that we don't know when should we input and even if we input (like ues *yes* command to periodically send yes to stdin), the remote node still can't receive it. As a result, the installation progress will hang there. That's where this assumption comes from.

One issue here is sometimes the JAVA_HOME can not be resolved correctly in `hadoop-env.sh`, so, we have to explicitly set it.

<pre><code class="Bash">#in order to fix "JAVA_HOME not found issue"
sed -i "s|\${JAVA_HOME}|$JAVA_HOME|g" $HADOOP_HOME/etc/hadoop/hadoop-env.sh

pdcp -w ^all_hosts $HADOOP_HOME/etc/hadoop/hadoop-env.sh $HADOOP_HOME/etc/hadoop/
pdsh -w ^nn_host "$HADOOP_HOME/bin/hdfs namenode -format"</code></pre>


###9. Copy Startup Scripts to Nodes

You don't want to start up Hadoop every time you start your machines, do you? The install scripts will allow hadoop to start with the OS booting up by put scripts in `/etc/init.d/`. So that hadoop services will be started as daemons in your systems.

Note that, these scripts are modified to work under Ubuntu. Three lines below are added.

<pre><code>source /etc/profile.d/hadoop.sh
source /etc/profile.d/java.sh

source /lib/lsb/init-functions
#init-functions has the function to start daemon</code></pre>

the code below is commented out, since it works under CentOS
<pre><code class="Bash">source /etc/rc.d/init.d/functions
</code></pre>

in every startup script, changes are also made for Ubuntu.


###10. Start up Hadoop Services

Hadoop services will be treated as daemons, and services are going to be started just like you start a normal service. By doing this. We need to register each service in OS, which brings the reason why we need to instasll `sysv-rc-conf` in the beginning. For more details about `sysv-rc-conf`, see [this](http://manpages.ubuntu.com/manpages/dapper/man8/sysv-rc-conf.8.html).

<pre><code class="Bash">echo "Starting Hadoop $HADOOP_VERSION services on all hosts..."
pdsh -w ^nn_host "chmod 755 /etc/init.d/hadoop-namenode && sudo sysv-rc-conf hadoop-namenode on && sudo service hadoop-namenode start"
pdsh -w ^snn_host "chmod 755 /etc/init.d/hadoop-secondarynamenode && sudo sysv-rc-conf hadoop-secondarynamenode on && sudo service hadoop-secondarynamenode start"
pdsh -w ^dn_hosts "chmod 755 /etc/init.d/hadoop-datanode && sudo sysv-rc-conf hadoop-datanode on && sudo service hadoop-datanode pdsh -w ^rm_host "chmod 755 /etc/init.d/hadoop-resourcemanager && sudo sysv-rc-conf hadoop-resourcemanager on && sudo service hadoop-resourcemanager start"
pdsh -w ^nm_hosts "chmod 755 /etc/init.d/hadoop-nodemanager && sudo sysv-rc-conf hadoop-nodemanager on && sudo service hadoop-nodemanager start"</code></pre>

###11. Time for Smoke Test

Run a `pi` program in your new installed Yarn Cluster

<pre><code bash="Bash">hadoop jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-$HADOOP_VERSION.jar pi -Dmapreduce.clientfactory.class.name=org.apache.hadoop.mapred.YarnClientFactory -libjars $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-client-jobclient-$HADOOP_VERSION.jar 16 10000</code></pre>

`3.14` delivers the greeting from Yarn.


##&#9824;&nbsp;&nbsp;How To Run

This is the easy part. After you are clear about the work mentioned <a href="#section1">section1</a> and <a href="#section2">section2</a>. Simply do this in your terminal.

<pre><code class="Bash">git clone https://github.com/legatoo/hadoop-install-scripts
cd hadoop-install-scripts
source install-hadoop2.sh -f | tee log
</code></pre>

For <a name="uninstall"><font color="black">Uninstall</font></a><sup><a href="#format_namenode">&nbsp;back</a></sup>

<pre><code class="Bash">source uninstall-hadoop2.sh</code></pre>

<font color="Red">*Note*</font>: `uninstall-hadoop2.sh` will delete current files in your HDFS, <font color="red">be careful</font>. Also, sometimes `jps` will not show running hadoop service which makes new installation failure misleading, so, the uninstall script will also kill your `java` progress to give new install a fresh environment, <font color="red">be careful</font> and modify as your demands.


Thank you for reading.

@stevenyfy

<meta itemprop="url" content="http://legato.ninja/2014/11/12/Install-Yarn-on-Ubuntu-Cluster-via-Scripts/"></div>
