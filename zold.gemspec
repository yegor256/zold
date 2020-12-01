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
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'English'

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require_relative 'lib/zold/version'

Gem::Specification.new do |s|
  s.specification_version = 2 if s.respond_to? :specification_version=
  s.required_rubygems_version = Gem::Requirement.new('>= 0') if s.respond_to? :required_rubygems_version=
  s.rubygems_version = '2.2'
  s.required_ruby_version = '>=2.5'
  s.name = 'zold'
  s.version = Zold::VERSION
  s.license = 'MIT'
  s.summary = 'A fast cryptocurrency for micro payments'
  s.description = 'In the last few years digital currencies have successfully demonstrated
their ability to become an alternative financial instrument in many
different markets. Most of the technologies available at the moment are
based on the principles of Blockchain architecture, including
dominating currencies like Bitcoin and Ethereum. Despite its
popularity, Blockchain is not the best possible solution for all scenarios.
One such example is for fast micro-payments.
Zold is an experimental alternative that enables distributed transactions between
anonymous users, making micro-payments financially feasible.
It borrows the proof-of-work principle from Bitcoin,
and suggests a different architecture for digital wallet maintenance.'
  s.authors = ['Yegor Bugayenko']
  s.email = 'yegor256@gmail.com'
  s.homepage = 'http://github.com/zold-io/zold'
  s.post_install_message = "Thanks for installing Zold #{Zold::VERSION}!
  Study our White Paper: https://papers.zold.io/wp.pdf
  Read our blog posts: https://blog.zold.io
  Try ZLD online wallet at: https://wts.zold.io
  Stay in touch with the community in Telegram: https://t.me/zold_io
  Follow us on Twitter: https://twitter.com/0crat
  If you have any issues, report to our GitHub repo: https://github.com/zold-io/zold"
  s.files = `git ls-files`.split($RS)
  s.executables = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files = s.files.grep(%r{^(test|features)/})
  s.rdoc_options = ['--charset=UTF-8']
  s.extra_rdoc_files = ['README.md', 'LICENSE.txt']
  s.add_runtime_dependency 'backtrace', '>=0.3'
  s.add_runtime_dependency 'concurrent-ruby', '1.1.5'
  s.add_runtime_dependency 'diffy', '3.3.0'
  s.add_runtime_dependency 'futex', '>=0.8.5'
  s.add_runtime_dependency 'get_process_mem', '~>0.2'
  s.add_runtime_dependency 'haml', '5.0.4'
  s.add_runtime_dependency 'json', '2.2.0'
  s.add_runtime_dependency 'memory_profiler', '0.9.13'
  s.add_runtime_dependency 'mimic', '0.4.4'
  s.add_runtime_dependency 'openssl', '2.1.2'
  s.add_runtime_dependency 'rainbow', '3.0.0'
  s.add_runtime_dependency 'semantic', '1.6.1'
  s.add_runtime_dependency 'sinatra', '2.0.5'
  s.add_runtime_dependency 'slop', '4.6.2'
  s.add_runtime_dependency 'sys-proctable', '1.2.1'
  s.add_runtime_dependency 'thin', '1.7.2'
  s.add_runtime_dependency 'threads', '>=0.3'
  s.add_runtime_dependency 'total', '>=0.3'
  s.add_runtime_dependency 'typhoeus', '1.3.1'
  s.add_runtime_dependency 'usagewatch_ext', '0.2.1'
  s.add_runtime_dependency 'zache', '>=0.12'
  s.add_runtime_dependency 'zold-score', '0.4.6'
  s.add_development_dependency 'codecov', '0.2.12'
  s.add_development_dependency 'cucumber', '3.1.2'
  s.add_development_dependency 'guard', '2.15.0'
  s.add_development_dependency 'guard-minitest', '2.4.6'
  s.add_development_dependency 'minitest', '5.11.3'
  s.add_development_dependency 'minitest-fail-fast', '0.1.0'
  s.add_development_dependency 'minitest-hooks', '1.5.0'
  s.add_development_dependency 'minitest-reporters', '1.3.6'
  s.add_development_dependency 'rake', '12.3.2'
  s.add_development_dependency 'random-port', '0.3.1'
  s.add_development_dependency 'rdoc', '6.1.1'
  s.add_development_dependency 'rspec-rails', '3.8.2'
  s.add_development_dependency 'rubocop', '0.69.0'
  s.add_development_dependency 'rubocop-rspec', '1.33.0'
  s.add_development_dependency 'webmock', '3.5.1'
  s.add_development_dependency 'xcop', '>=0.6'
end
