# Refactoring YaST Network - Kickstart Meeting

Since a long time, the YaST Team has been discussing about the possibility of
starting a sustained effort to refactor and rewrite several parts of the YaST
Network module. On 14th March 2019 a meeting was finally held to define the
goals of such effort and, to some extend, the strategy to follow.

Since the relationship between YaST and `wicked` was considered a central point
for the topic, both Marius and Rubén (developers of Wicked at that point in
time) attended the meeting.

## Status

Currently YaST manages configurations using traditional Linux commands and
files. That means it does not communicate directly with `wicked`. They work
together somehow only because both understand those "legacy" formats and
commands.

YaST does not communicate with Network Manager in any way.

Network Manager offers a DBUS interface. `wicked` also offers a DBUS interface,
but it's far from being as powerful as directly reading and writing some
`wicked` specific XML configuration files.

## Conclusions

Although we usually call this initiative "Network NG" as a reference to "Storage
NG", this is not intended as a full rewrite like it was done in the YaST storage
area. Quite the opposite, the goal is to change things in a way in which the new
code can be integrated into Tumbleweed often and can be included in subsequent
releases of Leap and SLE.

We want YaST to be able to better cooperate with `wicked`, but without coupling
both components. Quite the opposite, we want YaST to be able to interoperate
with a legacy system, with `wicked`, with Network Manager or with whatever other
system that could be adopted by (open)SUSE in the future.

We want to have an object oriented data model for YaST Network. For the reason
explained above, we will not adopt directly the `wicked` model, but we will
define our own model incrementally as we refactor the current pieces.

We will start refactoring the current code little by little based on a series
of use-cases. That new code will still interact with the system using the
legacy tools. Only when that code is in production we will revisit the
possibilities regarding closer collaboration between YaST and `wicked` (or
between YaST and any other possible backend).

Several candidate use-cases for these first rounds of refactoring were gathered
in a Trello board (see links below), together with other information like a list
of current problems. 

## Links

- Trello board to gather all the information about the initiative, specially to
  serve as general backlog for the use cases that will be used to drive the
  refactoring process. https://trello.com/b/M4DonGJJ/yast-network-refactoring

- Considerations about possible network configurations collected by the `wicked`
  developers, including information about how `wicked` supports those.
  https://gitlab.suse.de/wicked-maintainers/wicked/wikis/ip-and-routing-setup
