require 'minitest_helper'

class TestContext < Minitest::Test
  def test_session_commands
    cmd = nil
    GrassGis.session dry: true do
      cmd = r.resamp.stats input: "map1", output: "map2"
    end
    assert_equal "r.resamp.stats input=#{quoted_name('map1')} output=#{quoted_name('map2')}", cmd.to_s
  end

  def test_session_locals
    value = nil
    GrassGis.session dry: true, locals: { x: 11 } do
      value = x
    end
    assert_equal 11, value
  end
end
