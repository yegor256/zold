# frozen_string_literal: true

require 'zold/gem'
require 'webmock/minitest'
require 'minitest/autorun'

class TestGem < Zold::Test
  def test_last_version
    version = (1..3).map { rand(9).to_s } .join('.')
    stub_request(:get, 'https://rubygems.org/api/v1/versions/zold/latest.json').to_return(
      status: 200,
      body: "{\"version\": \"#{version}\"}"
    )
    assert_equal(version, Zold::Gem.new.last_version)
  end

  def test_last_version_live
    WebMock.allow_net_connect!
    assert(!Zold::Gem.new.last_version.nil?)
  end
end
