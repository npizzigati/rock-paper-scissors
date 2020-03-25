# If user doesn't have curses gem installed, fall back on CLI view
begin
  require 'curses'
  # start_game = lambda { RPSGame.new(CursesView.new).play }
  start_game = lambda { RPSGame.new(CLIView.new).play }
rescue
  start_game = lambda { RPSGame.new(CLIView.new).play }
end

module Validator
  def input(prompt, possible)
    puts prompt
    loop do
      entered = gets.chomp
      if possible.include? entered
        return entered
      else
        puts "Please enter #{prettier_print(possible)}"
      end
    end
  end

  def prettier_print(array)
    case array.size
    when 1
      array[0]
    when 2
      "#{array[0]} or #{array[1]}"
    when (3...)
      array[0..-2].join(', ') + " or " + array[-1]
    end
  end
end

class CLIView
  include Validator

  def retrieve_user_choice(moves)
    choice = input("Your choice: (r)ock, (p)aper, (s)cissors, (l)izard, (S)pock",
                   %w(r p s l S))
    moves[%w(r p s l S).index(choice)]
  end

  def display_outcome(outcome)
    puts outcome
  end

  def display_match_results(match_results)
    puts match_results
  end

  def play_again
    response = input("Play again (y/n)? ", %w(y n))
    response == 'y' ? true : false
  end

  def display_welcome
    puts "Welcome to Rock Paper Scissors"
  end

  def display_goodbye
    puts "Thanks for playing!"
  end
end

class Move
  def to_s
    name = self.class.name
    name == 'Spock' ? name : name.downcase
  end
end

class Rock < Move
  def >(other)
    %w(scissors lizard).include? other.to_s
  end
end

class Scissors < Move
  def >(other)
    %w(paper lizard).include? other.to_s
  end
end

class Paper < Move
  def >(other)
    %w(rock Spock).include? other.to_s
  end
end

class Lizard < Move
  def >(other)
    %w(Spock paper).include? other.to_s
  end
end

class Spock < Move
  def >(other)
    %w(rock scissors).include? other.to_s
  end
end

class Player
  attr_accessor :name, :move, :score, :move_history

  def initialize(name)
    self.name = name
    self.score = 0
    self.move_history = []
  end

  def to_s
    name
  end
end

# Orchestration engine
class RPSGame
  MOVES = [Rock.new, Paper.new, Scissors.new,
           Lizard.new, Spock.new]
  attr_accessor :player1, :player2, :match_winner, :view

  def initialize(view)
    # TODO: add names for human and computer
    # ask human and select randomly for computer
    @player1 = Player.new('Human')
    @player2 = Player.new('Computer')
    @match_winner = nil
    @view = view
  end

  def play
    view.display_welcome
    loop do
      while player1.score < 10 && player2.score < 10
        player1.move = view.retrieve_user_choice(MOVES)
        player2.move = MOVES.sample
        fight
      end
      match_winner = player1.score == 10 ? player1 : player2
      match_results = "p1: #{player1.score}  p2: #{player2.score}" +
                      "\n" + "Winner: #{match_winner}"
      view.display_match_results(match_results)
      break unless view.play_again
      reset_scores
    end

    view.display_goodbye
  end

  def fight
    puts "#{player1.name} plays #{player1.move}"
    puts "#{player2.name} plays #{player2.move}"
    if player1.move > player2.move
      winner, loser = [player1, player2]
    elsif player2.move > player1.move
      winner, loser = [player2, player1]
    else
      outcome = "Tie!"
    end
    if outcome != "Tie!"
      winner.score += 1
      gory_details = retrieve_gory_details(winner.move.to_s,
                                          loser.move.to_s)
      outcome = gory_details.capitalize + "\n" +
                winner.name.capitalize + " wins!"
    end
    view.display_outcome(outcome)
  end

  def reset_scores
    player1.score = 0
    player2.score = 0
  end

  def retrieve_gory_details(winner, loser)
    details = ["scissors cuts paper", "paper covers rock",
               "rock crushes lizard", "lizard poisons Spock",
               "Spock smashes scissors", "scissors decapitates lizard",
               "lizard eats paper", "paper disproves Spock",
               "Spock vaporizes rock", "rock crushes scissors"]
    details.filter do |e|
      words = e.split
      words[0] == winner \
      && words[2] == loser
    end[0]
  end
end

if __FILE__ == $PROGRAM_NAME
  start_game.call
end
