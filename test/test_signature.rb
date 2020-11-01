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
require_relative 'test__helper'
require 'zold/key'
require 'zold/id'
require 'zold/txn'
require 'zold/amount'
require 'zold/signature'

# Signature test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestSignature < Zold::Test
  def test_signs_and_validates
    pvt = Zold::Key.new(file: 'fixtures/id_rsa')
    pub = Zold::Key.new(file: 'fixtures/id_rsa.pub')
    txn = Zold::Txn.new(
      123, Time.now, Zold::Amount.new(zld: 14.95),
      'NOPREFIX', Zold::Id.new, 'hello, world!'
    )
    id = Zold::Id.new
    txn = txn.signed(pvt, id)
    assert_equal(684, txn.sign.length)
    assert(Zold::Signature.new.valid?(pub, id, txn))
  end
end
