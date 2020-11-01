# frozen_string_literal: true

# Copyright (c) 2018-2020 Zerocracy, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'minitest/autorun'
require 'tmpdir'
require 'openssl'
require_relative 'test__helper'
require 'zold/key'

# Key test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestKey < Zold::Test
  def test_reads_public_rsa
    key = Zold::Key.new(file: 'fixtures/id_rsa.pub')
    assert(key.to_pub.start_with?('MIICI'))
    assert(key.to_pub.end_with?('EAAQ=='))
    assert(!key.to_pub.include?("\n"))
    assert(Zold::Key.new(text: key.to_pub).to_pub.start_with?('MIICI'))
  end

  def test_reads_private_rsa
    key = Zold::Key.new(file: 'fixtures/id_rsa')
    assert(key.to_pub.start_with?('MIIJJ'))
    assert(key.to_pub.end_with?('Sg=='))
  end

  def test_reads_public_root_rsa
    key = Zold::Key::ROOT
    assert(key.to_pub.start_with?('MIICIjANBgkqhkiG9'))
    assert(key.to_pub.end_with?('3Tp1UCAwEAAQ=='))
  end

  def test_signs_and_verifies
    pub = Zold::Key.new(file: 'fixtures/id_rsa.pub')
    pvt = Zold::Key.new(file: 'fixtures/id_rsa')
    text = 'How are you, my friend?'
    signature = pvt.sign(text)
    assert(pub.verify(signature, text))
  end

  def test_signs_and_verifies_with_random_key
    Dir.mktmpdir do |dir|
      key = OpenSSL::PKey::RSA.new(2048)
      file = File.join(dir, 'temp')
      IO.write(file, key.public_key.to_s)
      pub = Zold::Key.new(file: file)
      IO.write(file, key.to_s)
      pvt = Zold::Key.new(file: file)
      text = 'How are you doing, dude?'
      signature = pvt.sign(text)
      assert(pub.verify(signature, text))
    end
  end

  def test_read_public_keys
    Dir.new('fixtures/keys').select { |f| f =~ /\.pub$/ }.each do |f|
      path = "fixtures/keys/#{f}"
      pub = Zold::Key.new(file: path)
      assert(pub.to_pub.length > 100)
    end
  end

  def test_signs_with_real_keys
    Dir.new('fixtures/keys').select { |f| f =~ /[0-9]+$/ }.each do |f|
      pvt = Zold::Key.new(file: "fixtures/keys/#{f}")
      pub = Zold::Key.new(file: "fixtures/keys/#{f}.pub")
      text = 'How are you doing, my friend?'
      signature = pvt.sign(text)
      assert(pub.verify(signature, text))
    end
  end

  def test_parses_openssl_generated_keys
    rsa = OpenSSL::PKey::RSA.new(2048)
    Zold::Key.new(text: rsa.to_pem).to_s
    Zold::Key.new(text: rsa.public_key.to_pem).to_s
  end
end
