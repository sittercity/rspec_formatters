# -*- encoding : utf-8 -*-
# 
# Copyright (c) 2011, Diego Souza
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
#   * Redistributions of source code must retain the above copyright notice,
#     this list of conditions and the following disclaimer.
#   * Redistributions in binary form must reproduce the above copyright notice,
#     this list of conditions and the following disclaimer in the documentation
#     and/or other materials provided with the distribution.
#   * Neither the name of the <ORGANIZATION> nor the names of its contributors
#     may be used to endorse or promote products derived from this software
#     without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

require "stringio"
require File.expand_path(File.dirname(__FILE__) + "/../spec_helper.rb")

describe JUnitFormatter do

  before(:each) do
    @now = Time.now
    allow(Time).to receive(:now).and_return(@now)
  end

  it "should initialize the tests with failures and success" do
    expect(JUnitFormatter.new(StringIO.new).test_results).to eql({:failures=>[], :successes=>[], :skipped=>[]})
  end

  describe "example_passed" do

    it "should push the example obj into success list" do
      f = JUnitFormatter.new(StringIO.new)
      f.example_passed("foobar")
      expect(f.test_results[:successes]).to eql(["foobar"])
    end

  end

  describe "example_failed" do

    it "should push the example obj into failures list" do
      f = JUnitFormatter.new(StringIO.new)
      f.example_failed("foobar")
      expect(f.test_results[:failures]).to eql(["foobar"])
    end

  end

  describe "example_pending" do

    it "should push the example obj into the skipped list" do
      f = JUnitFormatter.new(StringIO.new)
      f.example_pending("foobar")
      expect(f.test_results[:skipped]).to eql(["foobar"])
    end

  end

  describe "read_failure" do

    it "should ignore if there is no exception" do
      example = double("example")
      expect(example).to receive(:metadata).exactly(2).times.and_return({:execution_result => { :exception_encountered => nil \
                                                                                          , :exception => nil \
                                                                                          }})
      f = JUnitFormatter.new(StringIO.new)
      expect(f.read_failure(example)).to eql("")
    end

    it "should attempt to read exception if exception encountered is nil" do
      strace = double("stacktrace")
      expect(strace).to receive(:message).and_return("foobar")
      expect(strace).to receive(:backtrace).and_return(["foo","bar"])

      example = double("example")
      expect(example).to receive(:metadata).exactly(3).times.and_return({:execution_result => { :exception_encountered => nil \
                                                                                          , :exception => strace \
                                                                                          }})

      f = JUnitFormatter.new(StringIO.new)
      expect(f.read_failure(example)).to eql("foobar\nfoo\nbar")
    end

    it "should read message and backtrace from the example" do
      strace = double("stacktrace")
      expect(strace).to receive(:message).and_return("foobar")
      expect(strace).to receive(:backtrace).and_return(["foo","bar"])

      example    = double("example")
      expect(example).to receive(:metadata).exactly(2).times.and_return({:execution_result => {:exception_encountered => strace}})

      f = JUnitFormatter.new(StringIO.new)
      expect(f.read_failure(example)).to eql("foobar\nfoo\nbar")
    end

  end

  describe "dump_summary" do
   
    it "should print the junit xml" do
      strace = double("stacktrace")
      expect(strace).to receive(:message).and_return("foobar")
      expect(strace).to receive(:backtrace).and_return(["foo","bar"])
   
      example0 = double("example-0")
      expect(example0).to receive(:metadata).and_return({ :full_description => "foobar-success" \
                                                    , :file_path        => "lib/foobar-s.rb" \
                                                    , :execution_result => { :run_time => 0.1 } \
                                                    })
   
      example1 = double("example-1")
      expect(example1).to receive(:metadata).exactly(3).times.and_return({ :full_description => "foobar-failure" \
                                                                     , :file_path        => "lib/foobar-f.rb" \
                                                                     , :execution_result => { :exception_encountered => strace \
                                                                                            , :run_time              => 0.1 \
                                                                                            }
                                                                     })

      example2 = double("example-2")
      expect(example2).to receive(:metadata).and_return({ :full_description => "foobar-pending" \
                                                   , :file_path        => "lib/foobar-s.rb" \
                                                   , :execution_result => { :run_time => 0.1 } \
                                                   })

   
      output = StringIO.new
      f = JUnitFormatter.new(output)
      f.example_passed(example0)
      f.example_failed(example1)
      f.example_pending(example2)      
      f.dump_summary("0.1", 3, 1, 1)

      expect(output.string).to eq(<<-EOF)
<?xml version="1.0" encoding="utf-8" ?>
<testsuite errors="0" failures="1" skipped="1" tests="3" time="0.1" timestamp="#{@now.iso8601}">
  <properties />
  <testcase classname="lib/foobar-s.rb" name="foobar-success" time="0.1" />
  <testcase classname="lib/foobar-f.rb" name="foobar-failure" time="0.1">
    <failure message="failure" type="failure">
<![CDATA[ foobar\nfoo\nbar ]]>
    </failure>
  </testcase>
  <testcase classname="lib/foobar-s.rb" name="foobar-pending" time="0.1">
    <skipped/>
  </testcase>
</testsuite>
      EOF
    end

    it "should escape characteres <,>,&,\" before building xml" do
      example0 = double("example-0")
      expect(example0).to receive(:metadata).and_return({ :full_description => "foobar-success >>> &\"& <<<" \
                                                    , :file_path        => "lib/>foobar-s.rb" \
                                                    , :execution_result => { :run_time => 0.1 } \
                                                    })

      output = StringIO.new
      f = JUnitFormatter.new(output)
      f.example_passed(example0)
      f.dump_summary("0.1", 2, 1, 0)

      expect(output.string).to eq(<<-EOF)
<?xml version="1.0" encoding="utf-8" ?>
<testsuite errors="0" failures="1" skipped="0" tests="2" time="0.1" timestamp="#{@now.iso8601}">
  <properties />
  <testcase classname="lib/&gt;foobar-s.rb" name="foobar-success &gt;&gt;&gt; &amp;&quot;&amp; &lt;&lt;&lt;" time="0.1" />
</testsuite>
      EOF
    end
   
  end

end
