require 'minitest/autorun'
require_relative '../lib/rps.rb'
require_relative 'test_helper.rb'

include IoTestHelpers

class MoveTest < Minitest::Test
  attr_reader :move1, :move2
  def setup
    @move1 = Rock.new
    @move2 = Scissors.new
  end

  def test_greater_than
    expected = true
    actual = move1 > move2
    assert_equal(expected, actual)
  end

  def test_to_s
    expected = 'rock'
    actual = move1.to_s
    assert_equal(expected, actual)
  end
end

class RPSGameTest < Minitest::Test
  def setup
    @game = RPSGame.new
    @move1 = Rock.new
    @move2 = Scissors.new
    @game.player1.move = @move1
    @game.player2.move = @move2
  end

  def test_score_increment
    @game.fight
    expected = 1
    actual = @game.player1.score
    assert_equal(expected, actual)
  end

  def test_display_gory_details
    expected = /cuts|covers|crushes|poisons|smashes|decapitates|
                eats|disproves|vaporizes|crushes/x
    winner, loser = [@game.player1.move.to_s,
                     @game.player2.move.to_s]
    actual = @game.display_gory_details(winner, loser)
    assert_match(expected, actual)
  end

  def test_play_final_score
    while @game.player1.score < 10 && @game.player2.score < 10
      @game.fight
    end
    @game.match_winner = @game.player1.score == 10 ? @game.player1 : @game.player2
    refute_equal(nil, @game.match_winner)
  end
end

class HumanTest < Minitest::Test
  def test_obtain_user_input
    me = Human.new('Human')
    expected = 'rock'
    actual = simulate_stdin('r') { me.obtain_user_input }
    assert_instance_of(Rock, actual)
    assert_equal(expected, actual.to_s)
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
