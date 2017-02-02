VEGETABLES 0.7.4
================

**Experimental video edge detection system.**

Uses averaging over a square of pixels and checks changes in brightness
over a series of squares to find an edge. Colour coded horizontal and
vertical edge points and bright/dark area detection. Plots lines or curves
along edges which can be colour-coded to area brightness and open or
closed.

Allows editing of detection parameters in real-time, as well as toggling
various render modes and drawing options. Has the ability to pause the
video feed and still adjust the algorithm, for both real-time and recorded
frames being replayed. comprehensive display of status information with
full help text screen available for interactive features.

![Vegetables](https://raw.githubusercontent.com/grkvlt/Vegetables/master/vegetables.png)

## TODO

- Fix `a` key functionality
- Missing out some dots in the detection list.
- Most obvious with `d` enabled and paused image, flip between `a` on and
  off modes to see the effect. Probably just not including the entire array
  when creating line segments?

---
_Copyright 2009-2017 by [Andrew Donald Kennedy](mailto:andrew.international@gmail.com)
and Licensed under the [Apache Software License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0)_
