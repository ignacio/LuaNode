require "lunit"

module(..., lunit.testcase, package.seeall)

common = dofile("common.lua")

function test()

local crypto = require "luanode.crypto"
local fs = require('luanode.fs')
local path = require('luanode.path')

-- Test Certificates
local caPem = fs.readFileSync(common.fixturesDir .. '/keys/ca1-cert.pem', 'ascii')
local certPem = fs.readFileSync(common.fixturesDir .. '/keys/agent1-cert.pem', 'ascii')
local keyPem = fs.readFileSync(common.fixturesDir .. '/keys/agent1-key.pem', 'ascii')

-- Test HMAC
local h1 = crypto.createHmac('sha1', 'Node')
               :update('some data')
               :update('to hmac')
               :final('hex')
assert_equal('19fd6e1ba73d9ed2224dd5094a71babe85d9a892', h1, 'test HMAC')

-- Test hashing
local a0 = crypto.createHash('sha1'):update('Test123'):final("hex")
local a1 = crypto.createHash('md5'):update('Test123'):final("binary")
local a3 = crypto.createHash('sha512'):update('Test123'):final("binary")

assert_equal('8308651804facb7b9af8ffc53a33a22d6a1c8ac2', a0, 'Test SHA1')
assert_equal('h\234\203\151\216o\fF!\250+\14\23\202\189\140', a1, 'Test MD5 as binary')
assert_equal('\193(4\241\003\031d\151!O\'\212C/&Qz\212\148\021l\184\141Q+\219\029\196\181}\178' ..
			'\214\146\163\223\162i\161\155\n\n*\015\215\214\162\168\133\227<\131\156\147' ..
			'\194\006\2180\161\1359(G\237\'', a3, 'Test SHA512 as assumed binary')

-- Test multiple updates to same hash
local h1 = crypto.createHash('sha1'):update('Test123'):final('hex')
local h2 = crypto.createHash('sha1'):update('Test'):update('123'):final('hex')
assert_equal(h1, h2, 'multipled updates')

-- Test hashing for binary files
local fn = path.join(common.fixturesDir, 'lua-96x96.png')
local sha1Hash = crypto.createHash('sha1')
sha1Hash:update( fs.readFileSync( path.join(common.fixturesDir, 'lua-96x96.png') ) )
assert_equal('062106d7a15ba9de92cea9199cdcdf5119bf97b4', sha1Hash:final('hex'), 'Test SHA1 of lua-96x96.png')

-- Test signing and verifying
local s1 = crypto.createSign('RSA-SHA1')
				:update('Test123')
				:sign(keyPem, 'base64')
local verified = crypto.createVerify('RSA-SHA1')
					:update('Test')
					:update('123')
					:verify(certPem, s1, 'base64')
assert_true(verified, 'sign and verify (base 64)')

local s2 = crypto.createSign('RSA-SHA256')
				:update('Test123')
				:sign(keyPem) -- binary
local verified = crypto.createVerify('RSA-SHA256')
					:update('Test')
					:update('123')
					:verify(certPem, s2) -- binary
assert_true(verified, 'sign and verify (binary)')

-- Test encryption and decryption
local plaintext = 'All work and no play makes Jack a dull boy.'
local cipher = crypto.createCipher('aes192', 'MySecretKey123')

-- encrypt plaintext to a ciphertext which will be in hex
local ciph = cipher:update(plaintext)
ciph = ciph .. cipher:final()

local decipher = crypto.createDecipher('aes192', 'MySecretKey123')
local txt = decipher:update(ciph)
txt = txt .. decipher:final()

assert_equal(plaintext, txt, 'encryption and decryption')

-- Test encyrption and decryption with explicit key and iv
local encryption_key = '0123456789abcd0123456789'
local iv = '12345678'

local cipher = crypto.createCipheriv('des-ede3-cbc', encryption_key, iv, "binary")
local ciph = cipher:update(plaintext)	-- TODO: add optional input encoding 
ciph = ciph .. cipher:final()

local decipher = crypto.createDecipheriv('des-ede3-cbc', encryption_key, iv, "binary")
local txt = decipher:update(ciph)
txt = txt .. decipher:final()

assert_equal(plaintext, txt, 'encryption and decryption with key and iv')


process:loop()
end
