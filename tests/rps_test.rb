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
    @view = CLIView.new
    @view.stub :retrieve_user_name, "test_user" do
      @view.stub :display_computer_name, "" do
        @game = RPSGame.new(@view)
        @game.player1.move = Rock.new
        @game.player2.move = Scissors.new
      end
    end
  end

  def test_score_increment
    @game.view.stub :input_char, "r" do
      @game.play_round
      expected = 1
      actual = @game.player1.score
      assert_equal(expected, actual)
    end
  end

  def test_retrieve_gore
    expected = /cuts|covers|crushes|poisons|smashes|decapitates|
                eats|disproves|vaporizes|crushes/x
    winner, loser = [@game.player1.move.to_s,
                    @game.player2.move.to_s]
    actual = @game.retrieve_gore(winner, loser)
    assert_match(expected, actual)
  end

  # def test_play_match_final_score
  #   @game.view.stub :input_char, "r" do
  #     while @game.player1.score < 10 && @game.player2.score < 10
  #       @game.play_round
  #     end
  #     winner = @game.player1.score == 10 ? @game.player1 : @game.player2
  #     refute_equal(nil, winner)
  #   end
  # end
end

class HumanTest < Minitest::Test
  def test_retrieve_user_input
    move_options = [Rock.new, Paper.new, Scissors.new,
             Lizard.new, Spock.new]
    view = CLIView.new
    expected = 'rock'
    actual = simulate_stdin('r') { view.retrieve_user_move(move_options) }
    assert_instance_of(Rock, actual)
    assert_equal(expected, actual.to_s)
  end
end

class ValidatorTest < Minitest::Test
  include Prettier
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
end
