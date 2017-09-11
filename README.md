# Submission for Apple WWDC Scholarship 2017

## Explanation

This was the part of the game built using SpriteKit, UIKit, and AVFoundation over the course of two weeks for my submission to Apple's 2017 WWDC Scholarship competition. The game employed a randomized time-based mechanism for enemies and utilized the single-life mechanics reminiscent of Dark Souls. Although the game was a platformer, the game relied on several key algorithms for procedurally generating each level and tiling the level. In particular, Perlin Noise, mechanics borrowed from Conway's Game of Life, and Flood Fill were used. To prevent huge drops in FPS from impacting the physics engine, the delta time was hard-coded to be equivalent to 60 frames per second.

As part of the submission requirements, the game was developed in Swift Playground although a majority of the design, implementation, and testing was done through a normal iOS project.

## References

[Flood Fill](https://en.wikipedia.org/wiki/Flood_fill)

[Perlin Noise](https://en.wikipedia.org/wiki/Perlin_noise)

[Conway's Game of Life](https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life)

## License

MIT © William Zhang
