# LuaNode #

[![Build Status](https://travis-ci.org/ignacio/LuaNode.svg?branch=master)](https://travis-ci.org/ignacio/LuaNode)
[![Build status](https://ci.appveyor.com/api/projects/status/h314jv8m29cb2xkp?svg=true)](https://ci.appveyor.com/project/ignacio/luanode)
[![License](http://img.shields.io/badge/License-MIT-brightgreen.svg)](LICENSE)

Asynchronous I/O for Lua.

**LuaNode** allows to write performant net servers or clients, using an asynchronous model of computing (the [Reactor pattern][1]). 
You might have seen this model implemented in event processing frameworks like [Node.js][11], [EventMachine][2] or [Twisted][3].
In fact, **LuaNode** is heavily based on [Node.js][11], because I wanted to be able to do what *Node.js* does, but using [Lua][4] instead of JavaScript.

**LuaNode** is written using [Boost.Asio][5]. From its homepage:
> Boost.Asio is a cross-platform C++ library for network and low-level I/O programming that provides developers with a consistent asynchronous model using a modern C++ approach.

That allows **LuaNode** to be cross-platform. It is mainly developed on Windows, but it is being tested also on Linux and OSX.

## Hello, world #

The following is the *"hello world"* of HTTP servers.

```lua
local http = require('luanode.http')

http.createServer(function(self, request, response)
   response:writeHead(200, {["Content-Type"] = "text/plain"})
   response:finish("Hello World")
end):listen(8124)

console.log('Server running at http://127.0.0.1:8124/')

process:loop()
```

To run the server, put the above code in a file `test_server.lua` and execute it with **LuaNode** as follows:  

```bash
luanode test_server.lua
```

Then point your browser to `http://localhost:8124/`

You'll notice a striking resemblance with *Node.js* example server. In fact, I've aimed at keeping both, within reason, to be 
quite compatible. Code from *Node.js* can be easily rewritten from JavaScript into Lua, and with a few more tweaks, you can adapt code available today for *Node.js*.

## Building #

**LuaNode** can be compiled on Windows, Linux and OSX, using [CMake](http://www.cmake.org/). Although there are makefiles and projects for Visual Studio in the `build` folder, they are not really meant for general use. Currently, the recommended way to build is by using CMake 2.6 or above.

It is regularly built on:

- Ubuntu 12.04 (precise)
- Debian (squeeze, wheezy, jessie)
- Windows 7, 8 and Server 2012 R2

**LuaNode** depends on the following:

 - [Boost.Asio][5]
 - [OpenSSL][7]
 - [lunit][10]

### Ubuntu 12.04 Precise
 ```bash
 sudo apt-get install lua5.1 liblua5.1-0-dev liblua5.1-json libssl-dev libboost1.46-dev libboost-system1.46-dev luarocks cmake libboost-date-time1.48.0 libboost-date-time1.48-dev libboost-thread1.48.0 libboost-thread1.48-dev libboost-system1.48.0 libboost-system1.48-dev
 git clone git://github.com/ignacio/LuaNode.git
 cd LuaNode/build
 cmake ../
 make
 ```
 
### Debian installation #

If you already have Lua, OpenSSL and Boost installed, you can use [CMake](http://www.cmake.org/) to build LuaNode 
(thanks to Michal Kottman). Just do:

 - git clone git://github.com/ignacio/LuaNode.git
 - cd LuaNode/build
 - cmake ..
 - cmake --build .

 When building on ArchLinux, you need to change the install prefix, so the steps required are:

 - git clone git://github.com/ignacio/LuaNode.git
 - cd LuaNode/build
 - cmake -DCMAKE_INSTALL_PREFIX=/usr ..
 - cmake --build .


If you do not want to or cannot use CMake, the following has been tested on Ubuntu Desktop 10.10 / Debian testing.

 - Install Lua and libraries
   - sudo apt-get install lua5.1 liblua5.1-0-dev

 - Install OpenSSL
   - sudo apt-get install libssl-dev

 - Install Boost
   - sudo apt-get install libboost1.46-dev libboost-system1.46-dev
   
 - Install Boost (tested with 1.44 to 1.59)
   - Download [boost_1_44_0.tar.bz2](http://sourceforge.net/projects/boost/files/boost/1.44.0/boost_1_44_0.tar.bz2/download)
   - Unpack
   - ./bootstrap.sh
   - sudo ./bjam --build-type=complete --layout=versioned --with-system --with-thread threading=multi link=shared install
   - sudo ldconfig -v
   
 - Install LuaRocks
   - wget http://luarocks.org/releases/luarocks-2.2.2.tar.gz
   - tar xvf luarocks-2.2.2.tar.gz
   - cd luarocks-2.2.2
   - ./configure
   - make
   - sudo make install
   
 - Install LuaNode
   - cd ~
   - mkdir -p devel/sources
   - mkdir -p devel/bin
   - cd devel/sources
   - git clone git://github.com/ignacio/LuaNode.git
   - cd LuaNode/build/linux
   - export INCONCERT_DEVEL=~/devel
   - make

When compiling on ArchLinux, the last step is this:

   - make PREFIX=/usr LIB_DIR=/usr/lib
   
*Note: This installation procedure will be simplified in the future.*


### Mac OSX installation 
*Note: Installation was tested on OS X Lion 10.7.5, OS X Mountain Lion 10.8 and OSX Mavericks 10.9*

If you don't have boost or cmake installed, you can use [Homebrew](http://mxcl.github.com/homebrew/):

 - brew install boost cmake
 
Compile from sources with cmake:

 - git clone git://github.com/ignacio/LuaNode.git
 - cd LuaNode/build
 - cmake ../
 - make
 
## Status #
Currently, there's a lot of functionality missing. Doing a `grep TODO` should give an idea :D

## Documentation #
Sorry, I've written nothing yet, but you can get along following [Node.js 0.2.5 documentation][12].

The two most glaring difference between *Node.js* and **LuaNode** are:

- Callbacks first parameters is always who is emitting the event.
- Streams' *end* method is *finish* in **LuaNode**.
- You must start the event loop yourself (this surely will change in the future).

The unit tests provide lots of examples. They are available at the `test` folder.

## Acknowledgements #
I'd like to acknowledge the work of the following people or group:

 - Ryan Dahl, obviously, for his work on [Node.js][11] and [http-parser][14], which I use to parse http requests.
 - Renato Maia, for allowing me to take parts of [Loop][13].
 - Keith Howe, for [LuaCrypto][15]
 - Michal Kottman, for his additions to [LuaCrypto][16]. He also contributed a CMakeLists.txt to ease building.
 - Steve Donovan, for allowing me to take parts of [Penlight][17].
 - Joyent, for [Node.js][11] and [libuv][18]. Parts of libuv were adapted (terminal handling, etc). 
 - Diego Nehab, for [LuaSocket][8] (which we use parts of).

 
## License #
**LuaNode** is available under the MIT license.


[1]: http://en.wikipedia.org/wiki/Reactor_pattern
[2]: http://rubyeventmachine.com/
[3]: http://twistedmatrix.com/trac/
[4]: http://www.lua.org/
[5]: http://www.boost.org/doc/libs/release/doc/html/boost_asio.html
[6]: http://www.boost.org/
[7]: http://www.openssl.org/
[8]: http://w3.impa.br/~diego/software/luasocket/
[10]: https://rocks.moonscript.org/modules/luarocks/lunit
[11]: http://nodejs.org/
[12]: http://nodejs.org/docs/v0.2.5/api.html
[13]: http://loop.luaforge.net/
[14]: https://github.com/ry/http-parser
[15]: http://luacrypto.luaforge.net/
[16]: https://github.com/mkottman/luacrypto/
[17]: https://github.com/stevedonovan/Penlight
[18]: https://github.com/joyent/libuv
