require 'minitest_helper'

class TestModule < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::GrassGis::VERSION
  end

  def test_command_generation
    r = GrassGis::Module.new('r')
    cmd = r.resamp.stats '-n', input: "map1@mapset1", output: "map2"
    assert_equal "r.resamp.stats -n input=#{quoted_name('map1@mapset1')} output=#{quoted_name('map2')}", cmd.to_s
  end

  def test_command_with_multiple_argument
    r = GrassGis::Module.new('r')
    cmd = r.resamp.stats '-n', input: %w(map1 map2 map3), output: "map4"
    input =  quoted_name('map1,map2,map3')
    assert_equal "r.resamp.stats -n input=#{input} output=#{quoted_name('map4')}", cmd.to_s
  end

  def test_command_with_stdin
    if OS.windows?
      skip
      return
    end
    color_table = "0% black\n50% white\n100% black"
    r = GrassGis::Module.new('r')
    cmd = r.colors map: 'a_map', rules: color_table
    assert_equal "r.colors map=a_map rules=- << EOF\n#{color_table}\nEOF\n", cmd.to_s(with_input: true)
  end

  def test_command_with_indented_stdin
    if OS.windows?
      skip
      return
    end
    color_table = %{
      0% black
      50% white
      100% black
    }
    unindented = "0% black\n50% white\n100% black"
    r = GrassGis::Module.new('r')
    cmd = r.colors map: 'a_map', rules: color_table
    assert_equal "r.colors map=a_map rules=- << EOF\n#{unindented}\nEOF\n", cmd.to_s(with_input: true)
  end

  def test_nil_options_are_ignored
    r = GrassGis::Module.new('r')
    cmd = r.resamp.stats '-n', input: %w(map1 map2 map3), output: "map4", ignored: nil
    input =  quoted_name('map1,map2,map3')
    assert_equal "r.resamp.stats -n input=#{input} output=#{quoted_name('map4')}", cmd.to_s
  end
end
