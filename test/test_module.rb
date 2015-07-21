require 'minitest_helper'

class TestModule < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::GrassGis::VERSION
  end

  def test_command_generation
    r = GrassGis::Module.new('r', configuration: { dry: true })
    cmd = r.resamp.stats '-n', input: "map1@mapset1", output: "map2"
    assert_equal "r.resamp.stats -n input=#{quoted_name('map1@mapset1')} output=#{quoted_name('map2')}", cmd.to_s
  end

  def test_command_with_multiple_argument
    r = GrassGis::Module.new('r', configuration: { dry: true })
    cmd = r.resamp.stats '-n', input: %w(map1 map2 map3), output: "map4"
    input =  %w(map1 map2 map3).map { |a| quoted_name(a) }.join(',')
    assert_equal "r.resamp.stats -n input=#{input} output=#{quoted_name('map4')}", cmd.to_s
  end

  def test_command_with_stdin
    if OS.windows?
      skip
      return
    end
    color_table = "0% black\n50% white\n100% black"
    r = GrassGis::Module.new('r', configuration: { dry: true })
    cmd = r.colors map: 'a_map', rules: color_table
    assert_equal "r.colors map=a_map rules=- << EOF\n#{color_table}\nEOF\n", cmd.to_s(with_input: true)
  end
end
