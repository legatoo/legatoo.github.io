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
