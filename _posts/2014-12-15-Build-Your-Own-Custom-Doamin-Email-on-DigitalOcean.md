---
layout: post
title: Build Your Own Custom Domain Email Sever on DigitalOcean
---
Sending an email from your domain is just like a very cool self-introduction, especially for developers. With the help of two bloggers and some official documents, I finally setup my mail server in DigitalOcean. So, I decide to write it down as a record for myself, and as a guide for those who need.

What's in this article:
+ Emails sending to `me@yourdomain.com` will be forwarded to your Gmail inbox
+ Sending Email from your domain
+ Using Gmail as your mail manager
+ (Optional) Distinguish yourself from a spammer

Ok, Let's begin.

##What Happened When Sending/Receiving Mails?

Email is the most adorable way to communicate with others in my opinion. It offers you time to organize your response, and keep copies of all your communications, it's insanely fast and easy to use. So, some background knowledge and terminology are good to know before you actually build your mail server, but feel free to skip this part if you already know it.

<p><img src="{{site.baseurl}}public/img/image/SMTP-transfer-model-640px.png"/></p>

Above picture cited from Wikipedia give us a high level explanation of how mail is processing from a sender to a receiver.

MUA (Mail User Agent) is probably the most familiar part form most people. It can be web-based interface like Gmail, or desktop software like Microsoft Outlook. When a mail is composed and ready to go, it will be first send to a server called MSA (Mail Submission Agent), mostly this submission will use SMTP (Simple Mail Transfer Protocol) through TCP port 587. Then, MSA will deliver your mail to next hop, called MTA (Mail Transfer Agent). MSA and MTA are usually the same programming running with different startup parameters, and they can run either on the same machine or different machines. When your mail reaches MTA, a voyage in the Internet is about to begin. MTA has to locate the recipient, DNS (Domain Name System) is applied here to find the target, more precisely, a DNS record called MX record. It tells MTA the location of a Mail Exchanger(MX) server  for the domain where recipient lives. Then MTA will connect this MX server via SMTP. If the mail is accepted by this MX server, it will then be relayed to MDA (Mail Delivery Agent) where the mail will be stored in corresponding mailbox. Now, the receiver may use his/her MUA to fetch the mails, protocols widely used are IMAP (Internet Message Access Protocol) or POP3 (Post Office Protocol).

For more details, see <a href="https://en.wikipedia.org/wiki/Simple_Mail_Transfer_Protocol">Wikipedia</a>

What I expect is when mails coming to me, it will forward them to my Gmail inbox, and when I compose and send mails from Gmail, it will relay mail to the destination.

Now, let's set all things up.
<br></br>

##Prerequisite

In order to have your own customed domain email address, you have to have these first:

+ A domian name owned by you. You can by one from <a href="https://www.name.com/">here
+ A server controled by you, here I use <a href="https://www.digitalocean.com/">DigitalOcean</a>, you can choose whichever VPS provider you like, <a href="https://www.linode.com/">Linode</a> is also good.
+ A Gmail account (or other Mail service provider, but Gmail is used in this article)

I heard people say there are free options to do this, but I still prefer to rent a VPS, since it's not only can be used for mail service, but many possibilities, like your blog, your personal proxy, etc.

After all these are prepared, we first set up DNS records, since it takes time to propagation.  
<br></br>

##Forwarding Mails to Gmail

The software you need is <a href="http://www.postfix.org/start.html">Postfix</a>, a opensource software help people build their free, reliable and secure mail service. Below is the architecture of Postfix:

<p><img src="{{site.baseurl}}public/img/image/Postfix_architecture-640px.png"/></p>

In Ubuntu, use the command to install:

<pre><code class="Bash"></code><pre>
