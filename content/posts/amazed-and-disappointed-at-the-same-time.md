---
title: "Amazed and Disappointed at the Same Time"
description: "The story is about a strange bug AI helped me to find and fix!"
date: 2026-10-11T18:51:37+02:00
tags: ["AI", "linux", "systemd"]
tldr: "AI helped and mislead me for troubleshooting a sophisticated bug"
---


# Strange Alert
I was ready to wrap up my day, but you can imagine what happened. An alert related to an important server fired! Here we go again ...


The server was part of a stateful cluster, and being absent could cause serious issues if continued enough. 

The alert message was simple. `Node-XX is Down`
> The picture below is AI-generated

![NodeDown Alert](/images/NodeDownAlert.jpeg)

Of course, I jumped in trying to troubleshoot. I tried to `ssh` (via a reverse proxy) into the server. Failed! Of
course, it would fail. What was I even thinking when I did that?

I decided to check the cluster status to understand the severity of the issue. Super surprisingly, the cluster was in a healthy state and the node was in the member list of the cluster.

WHAAAAAT? Are you kidding me? How is that possible?

# Time to investigate
I made a couple of other checks and made completely sure that the cluster is healthy. It was the moment of relief, and I had all the time in the world to investigate this interesting issue.

First, I suspected that the reverse `ssh` agent in the server was not running or something. But it didn't make sense!
Because metrics from `node-exporter` were not being scraped. The issue must be broader than `ssh`.
Then why does the application work and the cluster is healthy? Extremely confused!

Got access to the serial console of the server. Fortunately, I was able to interact with the server! The server was not actually down.

Let's check the status of the application. It was indeed running! The SSH reverse proxy agent was healthy also. Even
more confusing!

Let's check network connectivity and export availability. `ip -6 a` shows interfaces are up and working. `curl` to the exporter works both locally and remotely!

This was the point that I had no clue what was going on.

# AI the mighty, I need your help!

Desperately, I decided to get help from AI, but no coding agent because I could not provide access to the serial console
to an agent like `codex`.
Even copying the output of the console was not possible. I only could take screenshots! Might seem crazy, but why not!

I opened a ChatGPT session and explained the situation. I asked it to troubleshoot the issue, and I would be its tools.
It should give me one command at a time, and I would share the result with screenshots. (Yes! I had all the time in the
world!)

There were lots of commands to run, and it was time-consuming. Agents are truly a blessing! 

In the middle of the troubleshooting, based on the commands and their outputs, I understood the issue. Network interfaces were removed and added back constantly. That was why my previous manual checks (un)luckily worked!
I didn't know how to fix such an issue. Asked ChatGPT a couple of questions in separate sessions. Even used good old friend google searching for similar issues as well. But not a chance!

I was still providing screenshots to ChatGPT, but at some point it stopped asking me for more commands and did a lot of thinking and searching!

It responded with a link to a github [issue](https://github.com/systemd/systemd/issues/20357) in `systemd` repository.

The issue seems to be exactly our case. It was caused by a bug it `systemd` that caused ipv6 interfaces to be removed and added back repeatedly.
ChatGPT concluded the issue with an explanation of the bug and suggesting to upgrade `systemd` to a certain version.

# Happiness vanished soon!
I was thrilled that I could find the issue and the fix for it thanks to ChatGPT! Now it's time to upgrade `systemd`!

But wait! All other servers of the cluster use the same version of `systemd`. Why aren't they affected by the issue? I need to understand the exact root cause before performing any action!

I continued the conversation with ChatGPT in the same session. Asked why the issue was not affecting other servers of the cluster. This time the discussion didn't seem to go well. After a long time of back and forth, I couldn't find any convincing reason.

What a roller-coaster ride! I was amazed half an hour ago but disappointed now.

As a last resort, I asked a colleague that has the most experience with this cluster and servers. He started doing some checks very similar checks to suggested checks by ChatGPT in my session.
After some checks, he mentioned:
> \+ Only this server has 498 days of uptime. Maybe some integer overflow. I'll ask chatgpt about it 


# AI Investigates again!
My colleague's conversation with ChatGPT continued, and it found something really interesting. It seems the root cause of our issue.
It suggested that the issue was caused by an overflow in `IFA_CACHEINFO`. We didn't have any clue what that is. 

After some more investigation, we found out that there is
a [struct](https://github.com/torvalds/linux/blob/master/include/uapi/linux/if_addr.h#L64) in Linux kernel code called
`ifa_cacheinfo`. It uses a `__u32` for storing the creation time of the interface, and the unit is hundredths of a
second. With a small calculation, it's clear that it can hold up to 497.1 days!

```c
struct ifa_cacheinfo {
	__u32	ifa_prefered;
	__u32	ifa_valid;
	__u32	cstamp; /* created timestamp, hundredths of seconds */
	__u32	tstamp; /* updated timestamp, hundredths of seconds */
};
```

Bingo! Our server has 498 days of uptime. We might have actually found the root cause now!
And after a reboot the problem was gone! (We are truly restart engineers sometimes 😂)

But another small question! Why was the application, which was also using network, not affected?
Because the application was using `dpdk` for networking and was bypassing the Linux kernel in this case. Clear as sky 🫠

# Reflections

- First of all, agents like `claude code` and `codex` are a blessing! I was tired of being the pipe between the real
  world and the model, taking so many screenshots!😁 You might argue that even with computer use, these kinds of cases
  could be solved. But I don't have full trust to grant access to critical production workloads yet for some
  controversial reasons!
- AI can sometimes mislead us if we don't understand what's actually going on under the hood. In this particular case,
  upgrading `systemd` to a different version (not the one AI suggested) would have also solved the issue. But what if
  the issue was not solved yet by `systemd`? What if the newer version could cause newer known/unknown problems that
  didn't exist before?
- Experience and insight still matter! At least for now! AI can get stuck in some sort of local extremum sometimes.
- Some pieces of software like `systemd` (and sometimes `linux`) can also have unexpected behaviors and bugs! I mostly
  trust Linux and fundamental components of it blindly. Although it's rare, when troubleshooting, it's always good to
  keep that in mind.


