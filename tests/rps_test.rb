require 'minitest/autorun'
require_relative '../lib/rps.rb'
require_relative 'test_helper.rb'

include IoTestHelpers

class WeaponTest < Minitest::Test
  attr_reader :weapon1, :weapon2
  def setup
    @weapon1 = Weapon.new(:rock)
    @weapon2 = Weapon.new(:scissors)
  end

  def test_greater_than
    expected = true
    actual = weapon1 > weapon2
    assert_equal(expected, actual)
  end

  def test_to_s
    expected = 'rock'
    actual = weapon1.to_s
    assert_equal(expected, actual)
  end
end

class RPSGameTest < Minitest::Test
  def setup
    @game = RPSGame.new
    @weapon1 = Weapon.new(:rock)
    @weapon2 = Weapon.new(:scissors)
    @game.player1.weapon = @weapon1
    @game.player2.weapon = @weapon2
  end

  def test_score_increment
    @game.fight
    expected = 1
    actual = @game.player1.score
    assert_equal(expected, actual)
  end

  def test_play_final_score
    while @game.player1.score < 10 && @game.player2.score < 10
      @game.fight
    end
    @game.winner = @game.player1.score == 10 ? @game.player1 : @game.player2
    refute_equal(nil, @game.winner)
  end
end

class HumanTest < Minitest::Test
  def test_obtain_choice
    me = Human.new('Human')
    expected = :rock 
    actual = simulate_stdin('r') { me.obtain_choice }

    assert_instance_of(Weapon, actual)
    assert_equal(expected, actual.type)
  end
end

class ValidatorTest < Minitest::Test
  include Validator
  def test_prettier_print_2_items
    array = %w(y n)
    expected = 'y or n'
    actual = prettier_print(array)
    assert_equal(expected, actual)
  end
  
  def test_prettier_print_3_items
    array = %w(y n q)
    expected = 'y, n or q'
    actual = prettier_print(array)
    assert_equal(expected, actual)
  end

  def test_wrong_input
    assert_output(/Please enter/) do
      simulate_stdin('r', 'y') { input('Like oranges?', %w(y n)) }
    end
  end
end
