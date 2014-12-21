---
layout: post
title: 在DigitalOcean上搭建自己的邮件系统
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
<pre><code class="BASH">#　example from DNS and BIND edition 4
peets.mpk.ca.us. IN MX 10 realy.hp.com
</code></pre>

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

myhostname与之前配置的DNS相匹配即可。Virtual Aliases指明了发往virtual　alias　domains的邮件将被转发至virtual文件定义的邮箱中去，因此下一步编辑<span style="background-color: #084B8A"><font color="white">/etc/postfix/virtual</font></span>

<pre><code>#Format: mail@from.address  forward@to.address
#multiple mailboxs can be declared
me@example.com foo@gmail.com
</code></pre>

使用下面的命令使得Postfix识别virtual文件,
<pre><code class="Bash">sudo postmap /etc/postfix/virtual</code></pre>

接下来重启Postfix服务,

<pre><code class="Bash">sudo service postfix restart
sudo postfix reload</code></pre>

接下来就可以测试了，发一封邮件去virtual文件里定义的邮箱，然后去对应的Gmail查看。不出意外，那封邮件应该已经在那里了。
如果没有的话，可以检查<span style="background-color: #084B8A"><font color="white">/var/log/mail.log</font></span>和<span style="background-color: #084B8A"><font color="white">/var/log/mail.err</font></span>看出现了什么问题，很有可能是DNS还没有更新完成，稍加等候在尝试。我的DNS感觉很快就更新完成了，不知道是不是和在香港有关。

邮件转发完成后，进去邮件发送的部分。

##邮件的发送

这一部分会比之前的部分麻烦一点，我们需要把我们的服务器配置成为一个relay服务器，原因是我希望继续使用Gmail的管理界面，但是邮件的发送人又需要是我自己的邮箱，那么这封邮件就需要由Google先发送到我的邮件服务器，然后在进行转发。Gmail和我们的转发服务器之间的交流是受加密保护的，因此这里使用到了TLS。有关TLS是如何运作的，我推荐一下的几篇文章，看过之后会对这套系统有一个认识

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

1. 生成所需的秘钥（记住所输入的密码）
<pre><code class="Bash">cd
openssl genrsa -des3 -out example.com.key 2048</code></pre>

2. 生成SSH Key (private key)和Certificate Signing Request (csr)文件
<pre><code class="Bash">openssl req -new -key example.com.key -out example.com.csr</code></pre>
除了不要忘记这里输入的密码外，注意两点: [1]在<font color="red">Common Name</font>那里输入你的域名地址（与<span style="background-color: #084B8A"><font color="white">/etc/postfix/main.cf</font></span>中的myhostname同） [2]不用输入Challenge Password

3. 生成Self-signed的Certifacte
<pre><code class="Bash">openssl x509 -req -days 3650 -in example.csr -signkey example.com.key -out example.com.crt</code></pre>
> x509 -req: 指明使用的CSR管理系统是<a href="http://en.wikipedia.org/wiki/X.509">X.509</a>

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

配置成功后在可以把自己邮箱设置为默认发送邮箱，这样就完成了邮件发送部分的配置。


##防止被识别为垃圾邮件

完成这一部分的配置后，你会发现经由你发出的邮件头中出现了新的内容，如下：
<p><img src="{{site.baseurl}}public/img/image/DKIM_SRS.png"/></p>

同时在这个非常友好的<a href="http://www.mail-tester.com/">测试网站</a>中也能取得高分:
<p><img src="{{site.baseurl}}public/img/image/Mail_Security_Check.png"/></p>

还记得我们将服务器配置成了一台帮助Gmail进行转发的MTA吗？是的，整个互联网中充满了这样的转发服务器，他们代表着发送者进行邮件的转发，我们已经配置了SASL验证来避免我们的relay服务器被其他人使用，这是好的。但是我们的邮箱依然有可能被别人伪造来进行钓鱼攻击(<a href="https://support.google.com/mail/answer/8253?hl=en">phishing</a>)，因此我们需要采取必要的措施允许收件人验证邮件的确由我发出，这里使用到了<a href="http://en.wikipedia.org/wiki/DomainKeys_Identified_Mail">DKIM</a>

如果你还记得在配置公钥密钥时候的那几篇文章，理解DKIM就会方便很多。我们使用我们的秘钥加密邮件(header以及contents)，然后将加密后的值保存在一个DKIM-Signature结构中附加在Mail Header中，DKIM是独立于SMTP的，邮件最后会通过管理DKIM的软件所监听的端口进行签名，亦即插入DKIM-Signature记录，如果我们在Gmail中查看邮件的具体信息（下来菜单中使用show original），我们可以清楚的看到这条记录(下图倒数第二条)：

<pre><code class="Bash">Delivered-To: yifan.yang9@gmail.com
Received: by 10.140.97.199 with SMTP id m65csp161044qge;
        Sun, 14 Dec 2014 06:15:27 -0800 (PST)
X-Received: by 10.236.70.70 with SMTP id o46mr18757082yhd.191.1418566527120;
        Sun, 14 Dec 2014 06:15:27 -0800 (PST)
Return-Path: <me@legato.ninja>
Received: from legato.ninja (legato.ninja. [104.236.3.63])
        by mx.google.com with ESMTP id i66si2938819yhq.145.2014.12.14.06.15.26
        for <yifan.yang9@gmail.com>;
        Sun, 14 Dec 2014 06:15:26 -0800 (PST)
Received-SPF: pass (google.com: domain of me@legato.ninja designates 104.236.3.63 as permitted sender) client-ip=104.236.3.63;
Authentication-Results: mx.google.com;
       spf=pass (google.com: domain of me@legato.ninja designates 104.236.3.63 as permitted sender) smtp.mail=me@legato.ninja;
       dkim=pass header.i=@legato.ninja
Received: from mail-ig0-f176.google.com (mail-ig0-f176.google.com [209.85.213.176])
	by legato.ninja (Postfix) with ESMTPSA id F20BC144E39
	for <yifan.yang9@gmail.com>; Sun, 14 Dec 2014 09:14:55 -0500 (EST)
DKIM-Signature: v=1; a=rsa-sha256; c=relaxed/simple; d=legato.ninja; s=mail;
	t=1418566496; bh=qiS/yt1TWHlEjtVeGqJOO42mPKrn6L0OMAupfmIZoGw=;
	h=Date:Subject:From:To:From;
	b=ESgslZ7IFbRx36ssnZJxb5FAPFFxb9IjxGv5sgO4K+80hil3B/T+665Su8AaO6agM
	 A0aG2bf0BGw2mI/682SpMZ1lpwjaMLQS4M0bRhxXSqYRcoAkP6KhbK7TRaeQ6HsXbi
	 igix2Jh31PSU7rdhUGo7CXW1C+6RMumQM2vH7k9Q=
Received: by mail-ig0-f176.google.com with SMTP id l13so4021635iga.15
        for <yifan.yang9@gmail.com>; Sun, 14 Dec 2014 06:14:55 -0800 (PST)</code></pre>

其中<span style="background-color: #084B8A"><font color="white"> b</font></span>字段记录了加密的内容。收件人则会通过一个DNS请求来获得公钥进行解密，具体的步骤是通过<span style="background-color: #084B8A"><font color="white"> s</font></span>字段的selector以及<span style="background-color: #084B8A"><font color="white"> d</font></span>字段的domain来发起DNS（TXT）请求，而应答中会包含公钥。然后进行内容解密，查实，来确认这封邮件的确从认证域名发出。


具体的配置我建议参考这篇组织良好的<a href="http://seasonofcode.com/posts/setting-up-dkim-and-srs-in-postfix.html">文章</a>，但是需要注意的是该文章中的DNS TXT记录部分设置有误，使用FQDN时不能忘记最后的dot，可参考<a href="https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-dkim-with-postfix-on-debian-wheezy">这篇文章</a>对DNS的设置。

至此，邮件服务搭建完成．

<a href="http://seasonofcode.com/posts/custom-domain-e-mails-with-postfix-and-gmail-the-missing-tutorial.html">Reference#1: Season of Code by cji</a><br></br><a href="http://www.e-rave.nl/create-a-self-signed-ssl-key-for-postfix">Reference#2: Mark's BLog </a>

Cheers,
@stevenyfy
