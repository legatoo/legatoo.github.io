---
layout: post
title: Build Your Own Custom Domain Email Sever on DigitalOcean
---
一封从自己的域名发出的邮件，对于开发者来说，是一份最好的自我介绍。在两位博主的文章以及维基的帮助下，上周在DigitalOcean搭建了自己的邮件系统，中间学到不少东西，特此记录下来。

这篇文章中将会包含以下内容：

+ 发向me@yourdomain.com邮件将会转发到配置的Gmail邮箱
+ 使用Gmail作为邮件的图形化管理界面，Google Inbox也适用
+ 发出的邮件将会来自于me@yourdomain.com
+ （Optional）避免自己被识别为Spammer

那就开始吧。

##发送和接收邮件时都发生了什么？

邮件是我自己最喜欢使用的通讯方式，它给我了足够的时间去组织一个良好的回复，并且具有更好的检索功能，可以在需要的时候找到历史的备份，简直就是一个冥想盆。在正式搭建自己的邮件服务之前，对邮件的传输有一个大致的认识会帮助理解后面的许多配置环境。　

<p><img src="{{site.baseurl}}public/img/image/SMTP-transfer-model-640px.png"/></p>

上面的图片来自Wikipedia，描述了一封邮件传输过程中要经历的重要节点。MUA (Mail User Agent) 或许是到目前为止最为熟悉的部分。他可以是web-based的，像网页版的Gmail, 也可以是功能完整的桌面客户端，例如Outlook。当一封邮件编辑完成后，它会经由TCP587端口（大多数公司）被发往一个叫做MSA (Mail Submission Agent)的服务器, 由此邮件会被提交到下一站：MTA (Mail Transfer Agent)。 MSA和MTA通常是运行在不同参数配置下的相同的程序，例如我们下面即将配置的Postfix，他们可以是运行在同一台机器上，也可以时运行在不同的机器上。前者主要使用共享文件，后者则需要网络传输。好了，现在你的邮件应该已经到了MTA这一站，接下来即将由此进入I(i)nternet。MTA需要确定收件人的具体位置，这一过程通过DNS (Domain Name System)服务来完成，具体来说是一个叫做MX的DNS记录。

如下就是一条MX记录
<pre><code class="BASH">peets.mpk.ca.us. IN MX 10 realy.hp.com  #example from DNS and BIND edition 4</code></pre>

该条记录有两个功能，它指明了peets.mpk.ca.us.将使用realy.hp.com作为邮件交换器Mail Exchanger(MX) server，同时还为这个邮件交换器指明了优先级，即10。这个优先级的绝对大小并不重要，重要的是它与其他邮件交换器优先级的相对大小，这个关系将作为邮件路由算法的依据。

回到邮件的发送，现在通过DNS查询，在MTA邮件查明了将发往何处。然后MTA将会通过SMTP协议将邮件转发到该MX服务器。被MX接受的邮件下一步会被转发到MDA (Mail Delivery Agent)，通过它邮件将会被分发存往对应用户的邮箱里面。现在邮件的接收者就可以通过邮件管理工具去提取自己的邮件了，邮件提取使用到的协议主要有IMAP (Internet Message Access Protocol) 和 POP3 (Post Office Protocol)。

更多内容, 参考<a href="https://en.wikipedia.org/wiki/Simple_Mail_Transfer_Protocol">Wikipedia</a>

下面进入正式的配置。
<br></br>

##准备工作

为了搭建自己的邮件系统，后面的内容默认你已经具备了以下的条件

+ 一个自己的域名，可以在<a href="https://www.name.com/">这里</a>购买
+ 一台由自己控制的VPS，如果没有我个人推荐使用<a href="https://www.digitalocean.com/">DigitalOcean</a>当然你可以使用任何自己喜欢的公司，比如<a href="https://www.linode.com/">Linode</a>也是相当不错的。
+ 一个常用的Gmail账户 (或者其他的账户，但是本文使用Gmail配置)

有人说会有完全免费的解决方案，但是我依然推荐你购买一台自己的VPS，它不仅可以成为你的邮件服务器，同时还可以host你的博客，搭建私人proxy等等。


##DNS配置

首先配置DNS是因为DNS的传播需要花费一定的时间，在那之前别人是找不到你的邮件地址的。我将在DigitalOcean的网页Console中配置我的DNS，如果要使用这项功能，请确保你正在使用DigitalOcean的nameserver，这个配置需要在域名提供商那里完成。下图是我自己的DNS记录：

<p><img src="{{site.baseurl}}public/img/image/DNS_Record.png"/></p>

另外需要注意的是Droplet的名字和你的域名是一致的，这样才能获得一个正确的PTR记录。在DNS传播的同时，继续下面的配置。

##转发邮件到配置的邮箱

我们的邮件服务需要使用一款优秀的开源软件来实现，<a href="http://www.postfix.org/start.html">Postfix</a>。

<p><img src="{{site.baseurl}}public/img/image/Postfix_architecture-640px.png"/></p>

在我的机器Ubuntu14.04下使用下面的命令就可以完成安装，使用<span style="background-color: #084B8A"><font color="white">DEBIAN_FRONTEND=noninteractive</font></span>将会跳过交互安装的环节，因为Postfix的配置可以之后通过修改配置文件完成。

<pre><code class="Bash">sudo DEBIAN_FRONTEND=noninteractive　apt-get install postfix</code></pre>

安装完成后，修改配置文件<span style="background-color: #084B8A"><font color="white">／etc/postfix/main.cf</font></span>

<pre><code class="Bash"># Host and site name.
myhostname = example.com
mydomain = example.com
myorigin = example.com

#Virtual aliases
virtual_alias_domains = example.com
virtual_alias_maps = hash:/etc/postfix/virtual</code></pre>

myhostname与之前配置的DNS相匹配即可。Virtual Aliases指明了发往virtual_alias_domains的邮件将被转发至virtual文件定义的邮箱中去，因此下一步编辑<span style="background-color: #084B8A"><font color="white">/etc/postfix/virtual</font></span>

<pre><code>#Format:
#<mail_from_address>  <forward_to_address>
me@example.com foo@gmail.com
</code></pre>

使用下面的命令使得Postfix识别virtual文件,
<pre><code class="Bash">sudo postmap /etc/postfix/virtual</code></pre>

接下来重启Postfix服务,

<pre><code class="Bash">sudo service postfix restart
sudo postfix reload</code></pre>

接下来就可以测试了，发一封邮件去virtual文件里定义的邮箱，然后去对应的Gmail查看。不出意外，那封邮件应该已经在那里了。
如果没有的话，可以检查/var/log/mail.log和/var/log/mail.err看出现了什么问题，很有可能是DNS还没有更新完成，稍加等候在尝试。我的DNS感觉很快就更新完成了，不知道是不是和在香港有关。

邮件转发完成后，进去邮件发送的部分。

##邮件的发送

这一部分会比之前的部分麻烦一下，我们需要把我们的邮件配置成为一个relay服务器，原因是我希望继续使用Gmail的管理界面，但是邮件的发送人又需要是我自己的邮箱，那么这封邮件就需要由Google先发送到我的邮件服务器，然后在进行转发。Gmail和我们的转发服务器之间的交流是受加密保护的，因此这里使用到了TLS。有关TLS是如何运作的，我推荐一下的几篇文章，看过之后会对这套系统有一个认识

+ <a href="http://security.stackexchange.com/questions/20803/how-does-ssl-tls-work"> How does SSL/TLS Works?</a>
+ <a href="http://en.wikipedia.org/wiki/Transport_Layer_Security">Transport Layer Security</a>
+ <a href="http://en.wikipedia.org/wiki/Public-key_cryptography">Public-key cryptography</a>

###使用Cyrus SASL来完成认证

首先安装所需的库

<pre><code class="Bash">sudo apt-get install sasl2-bin libsasl2-modules</code></pre>

在第一篇博客中，作者指出，我们需要让Gmail通过一组用户名/密码来登陆我们的邮件转发服务器，而不是一个<a href="http://en.wikipedia.org/wiki/Open_mail_relay">Open Relay</a>，因此首先建立远程认证的用户

<pre><code class="Bash">sudo saslpasswd2 -c -u example.com smtp</code></pre>

上面的命令会建立一个名为smtp的用户，用户名可以随意选择。完成后，在<span style="background-color: #084B8A"><font color="white">/etc</font></span>下会出现一个保存用户名和密码的文件sasldb2

<pre><code class="Bash">~$ ls -l /etc/sasldb2
-r-------- 1 postfix root 12288 Dec 12 05:01 /etc/sasldb2
</code></pre>

可以通过下面的命令在验证用户是否创建成功：

<pre><code class="Bash">sudo sasldblistusers2</code></pre>

然后为这个文件设置合适的权限

<pre><code class="Bash">sudo chmod 400 /etc/sasldb2
sudo chown postfix /etc/sasldb2</code></pre>

修改配置文件<span style="background-color: #084B8A"><font color="white">/etc/postfix/sasl/smtpd.conf</font></span>

<pre><code class="Bash"># /etc/postfix/sasl/smtpd.conf
sasl_pwcheck_method: auxprop
auxprop_plugin: sasldb
mech_list: PLAIN LOGIN CRAM-MD5 DIGEST-MD5 NTLM
log_level: 7</code></pre>

###生成认证所需的公钥密钥

1. 生成所需的秘钥（记住所输入的秘钥）
<pre><code class="Bash">cd
openssl genrsa -des3 -out example.com.key 2048</code></pre>

2. 生成SSH Key(private key)和Certificate Signing Request(csr)文件
<pre><code class="Bash">openssl req -new -key example.com.key -out example.com.csr</code></pre>
除了不要忘记这里输入的密码外，注意两点: [1]在Common Name那里输入你的域名地址（与<span style="background-color: #084B8A"><font color="white">/etc/postfix/main.cf</font></span>中的myhostname同） [2]不用输入Challenge Password

3. 生成Self-signed的Certifacte
<pre><code class="Bash">openssl x509 -req -days 3650 -in example.csr -signkey example.com.key -out example.com.crt</code></pre>
> 相关参数解释：
> x509 -req: 指明使用的CSR管理系统是<a href="http://en.wikipedia.org/wiki/X.509">X.509</a>
> -days: 该认证文件的有效期，以日位单位
> -in: 传入刚才创建的CSR文件
> -signkey: 传入刚才生成的秘钥

4. 移除生成的秘钥上的密码
对于邮件系统这样的守护程序，在机器遇到意外重启后，我们希望在无人值守的情况下恢复工作，所以不可能每次都人为输入密码。
<pre><code class="Bash">openssl rsa -in example.com.key -out example.com.key.nopass
mv example.com.key.nopass example.com.key</code></pre>

5. 生成pem文件
<pre><code class="Bash">openssl req -new -x509 -extensions v3_ca -keyout cakey.pem -out cacert.pem -days 3650</code></pre>
与第二步类似，注意填写正确的Common Name

6. 设置合适的权限，并安装Certificate
<pre><code class="Bash">chmod 600 example.com.key
chmod 600 cakey.pem
mv example.com.key /etc/ssl/private/
mv example.com.crt /etc/ssl/certs/
mv cakey.pem /etc/ssl/private/
mv cacert.pem /etc/ssl/certs/</code></pre>


完成认证相关的步骤，修改Postfix配置文件
<pre><code class="Bash">postconf -e 'smtpd_use_tls = yes'
postconf -e 'smtpd_tls_auth_only = no'
postconf -e 'smtpd_tls_key_file = /etc/ssl/private/example.com.key'
postconf -e 'smtpd_tls_cert_file = /etc/ssl/certs/example.com.crt'
postconf -e 'smtpd_tls_CAfile = /etc/ssl/certs/cacert.pem'
postconf -e 'tls_random_source = dev:/dev/urandom'</code></pre>

配置Postfix使之支持Gmail邮件转发，编辑<span style="background-color: #084B8A"><font color="white">/etc/postfix/master.cf</font></span>,　打开如下内容，注意submission那一行的第三个选项，也就是chroot设置位<span style="background-color: #084B8A"><font color="white"> n </font></span>

<pre><code class="Bash">submission inet n       -       n       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=may
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_reject_unlisted_recipient=no
  -o smtpd_relay_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING
</code></pre>

完成后重启Postfix服务

<pre><code class="Bash">sudo service postfix restart
sudo postfix reload</code></pre>

这时可以发现在587端口已经有人在监听了：

<pre><code class="Bash">$ sudo netstat -antu --program | grep 587
tcp        0      0 0.0.0.0:587             0.0.0.0:*               LISTEN      1257/master
tcp6       0      0 :::587                  :::*                    LISTEN      1257/master
</code></pre>

<pre><code class="Bash">$ sudo ps aux | grep 1257
root      1257  0.0  0.1  25344  1700 ?        Ss   Dec14   0:02 /usr/lib/postfix/master
</code></pre>

###Gmail端的配置

在Gmail的Setting中找到Accounts and Import，其中有一项Add another email address you own，点开后进行认证

<p><img src="{{site.baseurl}}public/img/image/Gmail_verfication1.png"/></p>

<p><img src="{{site.baseurl}}public/img/image/Gmail_verfication2.png"/></p>

如果一切正确，你会收到一封验证邮件。否则的话，查看log文件查看问题。

<a href="http://seasonofcode.com/posts/custom-domain-e-mails-with-postfix-and-gmail-the-missing-tutorial.html">Reference#1</a>,
<a href="http://www.e-rave.nl/create-a-self-signed-ssl-key-for-postfix">Reference#2</a>

Cheers,
@stevenyfy
