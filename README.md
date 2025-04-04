# MarketViewer: View a stock on your Kindle

Very simple stock viewer with a small graph

## Getting Started

To use this plugin, You'll need to do a few things:

Get [KoReader](https://github.com/koreader/koreader) installed on your e-reader. You can find instructions for doing this for a variety of devices [here](https://www.mobileread.com/forums/forumdisplay.php?f=276).

If you want to do this on a Kindle, you are going to have to jailbreak it. I recommend following [this guide](https://www.mobileread.com/forums/showthread.php?t=320564) to jailbreak your Kindle.

Acquire an API key from an API account on Polygon. Once you have your API key, create a `poly_config.lua` file in the following structure or modify and rename the `poly_config.lua.sample` file:


```lua
local poly_config = {
    api_key = "YOUR_API_KEY",
}

return poly_config
```

## Installation

If you clone this project, you should be able to put the directory, `marketView.koplugin`, in the `koreader/plugins` directory and it should work. If you want to use the plugin without cloning the project, you can download the zip file from the releases page and extract the `marketView.koplugin` directory to the `koreader/plugins` directory. If for some reason you extract the files of this repository in another directory, rename it before moving it to the `koreader/plugins` directory.

## How To Use

To use MarketView, go to the plugins menu, More tools, then click MarketView and choose a ticker with the button at the bottom.

## Credits
Codebase is very similar to [https://github.com/drewbaumann/AskGPT/](https://github.com/drewbaumann/AskGPT/) and I recommend you checkout their project. Could not create the viewer without referencing their code so the code is very similar.

License: GPLv3