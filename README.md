# fractal-miner
A set of mods for Minetest for generating fractal worlds.

- [minetest forum topic](https://forum.minetest.net/viewtopic.php?f=9&t=17155)
- [imgur album](https://imgur.com/a/B408K)

## installation

Each folder is a separate Minetest mod.  Copy all of the folders to your Minetest mods folder, and activate one mod at a time.  Note that fractal_helpers is just a batch of helper functions which are used by the other mods for fractal generation.

## usage

1. Create a new world in Minetest.  Do not enter the world.
2. With the world selected, click the "Configure" button.
3. Enable the mod for the fractal object you want to generate.
4. Click the "Play" button.

## configuration

You can configure how a fractal generates by editing the init.lua script associated with it.  Every fractal generation script has a Parameters section.  You can edit these parameters to change the size of the fractal, the blocks used in the fractal, or other properties depending on the fractal.