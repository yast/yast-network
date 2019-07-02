## Network-NG (Vision, Mision and Strategy)
  
It [has been decided](https://github.com/yast/yast-network/blob/master/doc/network-ng-kickstart.md#refactoring-yast-network---kickstart-meeting) that now is a perfect moment to start with the **YaST Network** refactoring. 
  
Some of the network areas are quite big and will need a large effort to be completely rewritten.  Thus, it is very important to set a common vision / mision and a clear stratey.

## Vision

**YaST Network** should be a useful **tool** that evolves to offer the **features** our users need to configure their networks with **whatever underlying technology** they use.

In other words, the current shape of y2-network shouldn't be an obstacle for own y2-network improvements and evolution.

## Mission

Create an object oriented **data model** / **API** for **YaST Network** , properly tested and generic enough to be used or adapted to work with any available network backend (wicked, Network Manager, systemd-networkd).

## Strategy

The module will be rewritten piece by piece to keep it working for most of the time, that is, merging to master as often as possible. `Isolated` or `small` modules will be completely rewritten and dropped if possible.

The `wicked` data model or any other will not be adopted directly, but we will define our own model incrementally as we refactor the current pieces.

We will refine the current code little by little based on a series of use-cases. That new data model will initially interact with the system using the legacy tools (not wicked or NM specific mechanisms).

### Recommended readings:

  - https://github.com/yast/yast-network/blob/master/doc/network-ng-kickstart.md#refactoring-yast-network---kickstart-meeting
