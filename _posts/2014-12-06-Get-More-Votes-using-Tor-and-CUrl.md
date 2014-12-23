---
layout: post
title: Get More Votes using Tor and CUrl
---

>The method in this article is for helping my friend in an not important contest. Even though, I feel really bad, I highly recommand no body use it in important things to hurt fairness.

##Anonymous

Anonymous is mixed blessing for sure. In the world of Internet, people are much more easier to hide their identity. I can list too many reasons why anonymous is important, but at the mean time, I can't deny how many crimes were made under the mask of anonymous. However, this article is not for discussing anonymous. In this small article I will share how I use Tor and Pycurl to vote avoid the IP constraint which applied by most of election organization.

##Installation

###1. Tor and Privoxy Installation

><a href="https://www.torproject.org/about/overview.html.en">What is Tor?</a>

>Tor is a network of virtual tunnels that allows people and groups to improve their privacy and security on the Internet.

Tor has to be make sure running successfully in your machine to gain anonymous. Using the command line below to install Tor and Privoxy.

<!--more-->


<pre><code class="Bash">sudo apt-get install tor privoxy</code></pre>

Privoxy is used as a proxy for Tor's SOCKS5 connection. It needs to be configured for Tor.
<pre><code class="Bash"># vim /etc/privoxy/config  and uncomment the following line
forward-socks5   /               127.0.0.1:9050 .
</code></pre>

Now, both Tor and Privoxy are working on your machine, some tests can show you they are actually working.

First check they are listening on right port by doing:
<pre><code class="Bash">sudo netstat -antu --program | egrep -h '8118|9050'
tcp        0      0 127.0.0.1:8118          0.0.0.0:*               LISTEN      21309/privoxy
tcp        0      0 127.0.0.1:9050          0.0.0.0:*               LISTEN      22373/tor
</code></pre>

Test your IP does change after you trigger Tor on. Using the command below to test your current IP
<pre><code class="Bash">echo 'Current IP is: ';curl --proxy http://127.0.0.1:8118 --silent http://www.ipchicken.com/ 2>&1 | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"
</code></pre>
Following two commands will restart Tor and test the IP is changed. (by default, Tor will update to a new IP every 10 mins)
<pre><code class="Bash">sudo service tor restart
echo 'New IP is: ';curl --proxy http://127.0.0.1:8118 --silent http://www.ipchicken.com/ 2>&1 | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"
</code></pre>

###2. Pycurl Installation

Because the script is implemented in Python, a Curl python shell should be installed. Installation is simple.
<pre><code class="Bash">sudo apt-get install python-dev
sudo pip install pycurl
</code></pre>

Now, you have everything to run the script.

##Let's Vote
The contest my friend participates is on a very hot Chinese social platform: WeChat(I don't like it, it transfers more and more Chinese into ZOOMBIE). The vote page is on mobile, so the first step is finding out the process of a success vote.

<img class="freezeframe" src="{{site.baseurl}}public/img/gif/wechat_vote.gif"/>


I use chrome device mode(iphone 6) to track the vote progress. The gif above shows you how to get the `VOTE POST` at last, so that we could construct POST and send many many POSTs through Tor network.


Next Step is easy, just construct this POST, the code is below:

{% gist d2f5b811835281062618 %}

##Run

<pre><code class="Bash">python vote.py</code></pre>


Cheers,<br>
<a href="https://twitter.com/stevenyfy"><font color="green">@stevenyfy</font></a>
