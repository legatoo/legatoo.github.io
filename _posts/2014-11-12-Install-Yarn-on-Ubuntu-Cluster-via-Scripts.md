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
