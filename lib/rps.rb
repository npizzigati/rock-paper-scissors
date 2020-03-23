require 'io/console'

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
  MOVES = [Rock.new, Paper.new, Scissors.new,
             Lizard.new, Spock.new]
  attr_accessor :name, :move, :score

  def initialize(name)
    self.name = name
    self.score = 0
  end

  def to_s
    name
  end
end

class Human < Player
  include Validator
  def choose
    self.move = obtain_user_input
  end

  def obtain_user_input
    choice = input("Your choice: (r)ock, (p)aper, (s)cissors, (l)izard, (S)pock",
                   %w(r p s l S))
    MOVES[%w(r p s l S).index(choice)]
  end
end

class Computer < Player
  def choose
    @move = MOVES.sample
  end
end

# Orchestration engine
class RPSGame
  attr_accessor :player1, :player2, :match_winner

  def initialize
    # TODO: add names for human and computer
    # ask human and select randomly for computer
    @player1 = Human.new('Human')
    @player2 = Computer.new('Computer')
    @match_winner = nil
  end

  def play
    display_welcome
    while player1.score < 10 && player2.score < 10
      player1.choose
      player2.choose
      fight
      #TODO: play again? message
    end
    match_winner = player1.score == 10 ? player1 : player2
    puts "p1: #{player1.score}   p2: #{player2.score}"
    puts "winner: #{match_winner}"
    display_goodbye
  end

  def fight
    puts "#{player1.name} plays #{player1.move}"
    puts "#{player2.name} plays #{player2.move}"
    if player1.move == player2.move
      puts "Tie!"
      return
    elsif player1.move > player2.move
      winner, loser = [player1, player2]
    else
      winner, loser = [player2, player1]
    end
      puts display_gory_details(winner.move.to_s, loser.move.to_s)
      puts "#{winner.name} wins!"
      winner.score += 1
  end

  def display_gory_details(winner, loser)
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

  def display_welcome
    puts "Welcome to Rock Paper Scissors"
  end

  def display_goodbye
    puts "Thanks for playing!"
  end
end

if __FILE__ == $PROGRAM_NAME
  RPSGame.new.play
end
