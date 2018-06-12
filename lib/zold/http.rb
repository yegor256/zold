# Copyright (c) 2018 Yegor Bugayenko
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

require 'rainbow'
require 'uri'
require 'net/http'
require_relative 'backtrace'
require_relative 'version'
require_relative 'score'

# HTTP page.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Http page
  class Http
    # HTTP header we add to each HTTP request, in order to inform
    # the other node about the score. If the score is big enough,
    # the remote node will add us to its list of remote nodes.
    SCORE_HEADER = 'X-Zold-Score'.freeze

    # HTTP header we add, in order to inform the node about our
    # version. This is done mostly in order to let the other node
    # reboot itself, if the version is higher.
    VERSION_HEADER = 'X-Zold-Version'.freeze

    def initialize(uri, score = Score::ZERO)
      raise 'URI can\'t be nil' if uri.nil?
      @uri = uri.is_a?(String) ? URI(uri) : uri
      raise 'Score can\'t be nil' if score.nil?
      @score = score
    end

    def get
      http = Net::HTTP.new(@uri.host, @uri.port)
      http.read_timeout = 5
      path = @uri.path
      path += '?' + @uri.query if @uri.query
      http.request_get(path, headers)
    rescue StandardError => e
      Error.new(e)
    end

    def put(body)
      http = Net::HTTP.new(@uri.host, @uri.port)
      http.read_timeout = 10
      path = @uri.path
      path += '?' + @uri.query if @uri.query
      http.request_put(
        path, body,
        headers.merge(
          'Content-Type': 'text/plain',
          'Content-Length': body.length.to_s
        )
      )
    rescue StandardError => e
      Error.new(e)
    end

    private

    # The error, if connection fails
    class Error
      def initialize(ex)
        @ex = ex
      end

      def body
        Backtrace.new(@ex).to_s
      end

      def code
        '599'
      end

      def message
        @ex.message
      end
    end

    def headers
      headers = {
        'User-Agent': "Zold #{VERSION}",
        'Connection': 'close',
        'Accept-Encoding': 'gzip'
      }
      headers[Http::VERSION_HEADER] = VERSION
      headers[Http::SCORE_HEADER] = @score.reduced(4).to_text if @score.valid? && !@score.expired? && @score.value > 3
      headers
    end
  end
end
