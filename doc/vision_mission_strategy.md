## Network-NG (Vision, Mision and Strategy)
  
It [has been decided](https://github.com/yast/yast-network/blob/master/doc/network-ng-kickstart.md#refactoring-yast-network---kickstart-meeting) that now was a perfect moment to start with the **YaST Network** refactoring. 
  
Some of the network areas are quite big and will need a large effort to be completely rewritten.  Thus, it is very important to define as a group effort a clear vision and develop a clear mision to make the refactor achievable as well to determine the strategy we will follow during the process. 

And that is basically what we have started to discuss and summarize in this document.

## Vision

**YaST Network** should be a useful **tool** that evolves to offer the **features** our users need to configure their networks with **whatever underlying technology** they use, without breaking in the process.

In other words, the current shape of y2-network shouldn't be an obstacle for own y2-network improvements and evolution.

## Mission

Create a properly object oriented **data model** / **API** for **YaST Network** , properly tested and enough generic to be used or adapted to work with any available network backend (wicked, Network Manager, systemd-networkd).

## Strategy

The module will be rewritten piece by piece to keep it working for most of the time, that is, merging to master as often as possible.
  - `Isolated` or `small` modules will be completely rewritten and dropped if possible, if not, only critical or more used methods will be maintained but trying to 

The `wicked` data model or any other will not be adopted directly, but we will define our own model incrementally as we refactor the current pieces.

We will do that refining the current code little by little based on a series of use-cases. That new data model will initially interact with the system using the legacy tools (not wicked or NM specific mechanisms).

### Steps already done

  - Routing module completely rewritten.
    - Policy routing (Multiple default routes are now permited)
  - DNS module almost rewritten.
  - Lan module (Interfaces configuration).
    - Started removing old code and adding objected oriented CWM widgets.
    - Started decoupling the UI and the data model.
    
### Recommended readings:

  - https://github.com/yast/yast-network/blob/master/doc/network-ng-kickstart.md#refactoring-yast-network---kickstart-meeting
