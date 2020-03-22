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

class Weapon
  def to_s
    name = self.class.name
    name == 'Spock' ? name : name.downcase
  end
end

class Rock < Weapon
  def >(other)
    %w(scissors lizard).include? other.to_s
  end
end

class Scissors < Weapon
  def >(other)
    %w(paper lizard).include? other.to_s
  end
end

class Paper < Weapon
  def >(other)
    %w(rock Spock).include? other.to_s
  end
end

class Lizard < Weapon
  def >(other)
    %w(Spock paper).include? other.to_s
  end
end

class Spock < Weapon
  def >(other)
    %w(rock scissors).include? other.to_s
  end
end

class Player
  WEAPONS = [Rock.new, Paper.new, Scissors.new, Lizard.new, Spock.new] 
  attr_accessor :name, :weapon, :score

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
    self.weapon = obtain_user_input
  end

  def obtain_user_input
    choice = input("Your choice: (r)ock, (p)aper, (s)cissors, (l)izard, (S)pock",
                   %w(r p s l S))
    WEAPONS[%w(r p s l S).index(choice)]
  end
end

class Computer < Player
  def choose
    @weapon = WEAPONS.sample
  end
end

# Orchestration engine
class RPSGame
  attr_accessor :player1, :player2, :winner

  def initialize
    # TODO: add names for human and computer
    # ask human and select randomly for computer
    @player1 = Human.new('Human')
    @player2 = Computer.new('Computer')
    @winner = nil
  end

  def play
    display_welcome
    while player1.score < 10 && player2.score < 10
      player1.choose
      player2.choose
      fight
      #TODO: play again? message
    end
    winner = player1.score == 10 ? player1 : player2
    puts "p1: #{player1.score}   p2: #{player2.score}"
    puts "winner: #{winner}"
    display_goodbye
  end

  def fight
    puts "#{player1.name} plays #{player1.weapon}"
    puts "#{player2.name} plays #{player2.weapon}"
    if player1.weapon > player2.weapon
      puts "#{player1.name} wins!"
      player1.score += 1
    elsif player2.weapon > player1.weapon
      puts "#{player2.name} wins!"
      player2.score += 1
    else
      puts "Tie!"
    end
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
