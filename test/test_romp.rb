require 'helper'

class TestRomp < Test::Unit::TestCase
  should "romp" do
    r = Romp.new("localhost", 61613)
    r.with_connection(:login => "foo", :password => "password") do
      r.subscribe(:destination => "/queue/a")
      r.send("foo", :destination => "/queue/a")
      r.send("bar", :destination => "/queue/a")
      r.send("baz", :destination => "/queue/a")

      frame = r.receive(:message)
      assert_equal "foo", frame.body

      frame = r.receive(:message)
      assert_equal "bar", frame.body

      frame = r.receive(:message)
      assert_equal "baz", frame.body
    end
  end
end
