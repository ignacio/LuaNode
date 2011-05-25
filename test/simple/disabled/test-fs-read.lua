module(..., lunit.testcase, package.seeall)

local common = dofile("common.lua")
local path = require "luanode.path"
local fs = require "luanode.fs"

function test()

local expected = 'xyz\n'
local readCalled = 0
local filepath = path.join(common.fixturesDir, 'x.txt')

fd, err = fs.openSync(filepath, 'r')

fs.read(fd, #expected, 0, function(fd, err, str, bytesRead)
	readCalled = readCalled + 1

	assert_true(not err)
	assert_equal(expected, str)
	assert_equal(bytesRead, #expected)
end)

--local r = fs.readSync(fd, #expected, 0)
--assert_equal(expected, r)
--assert_equal(#expected, #r)

process:addListener('exit', function()
	assert_equal(1, readCalled)
end)


process:loop()
end

--[[
var path = require('path'),
    fs = require('fs'),
    filepath = path.join(common.fixturesDir, 'x.txt'),
    fd = fs.openSync(filepath, 'r'),
    expected = 'xyz\n',
    readCalled = 0;

fs.read(fd, expected.length, 0, 'utf-8', function(err, str, bytesRead) {
  readCalled++;

  assert.ok(!err);
  assert.equal(str, expected);
  assert.equal(bytesRead, expected.length);
});

var r = fs.readSync(fd, expected.length, 0, 'utf-8');
assert.equal(r[0], expected);
assert.equal(r[1], expected.length);

process.addListener('exit', function() {
  assert.equal(readCalled, 1);
});
--]]